import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../repositories/workout_repository.dart';
import 'watch_protocol.dart';
import 'watch_snapshot_builder.dart';
import 'watch_sync_store.dart';
import 'wear_channel.dart';

/// Telefon tarafında saat eşlemesinin tüm mantığı (bkz. docs/ARCHITECTURE.md §15.3–15.5).
///
/// - Etkin antrenmanın anlık durumunu saate yayınlar ([setActiveWorkout], [workoutChanged]).
/// - Saatten gelen olayları işler ([processPendingEvents]): her olay tam bir kez uygulanır.
/// - Olaylarla değişen antrenmanları [workoutUpdates] ile duyurur (açık Antrenman ekranı yenilensin diye).
///
/// Hiçbir metot dışarıya hata fırlatmaz: saat tarafındaki sorunlar telefon uygulamasını bozmaz.
class WatchSyncService {
  WatchSyncService({
    required this.repository,
    required this.channel,
    required this.store,
    required this.fallbackTitle,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final WorkoutRepository repository;
  final WearChannel channel;
  final WatchSyncStore store;

  /// Başlıksız antrenmanın saatte gösterilecek adı (main.dart `formatWorkoutDate` verir).
  final String Function(DateTime startedAt) fallbackTitle;
  final DateTime Function() clock;

  /// Etkin antrenman bu süreden eski başlamışsa temizlenir.
  static const Duration activeWorkoutMaxAge = Duration(hours: 12);

  /// Saklanan işlenmiş olay id'lerinin en fazla sayısı.
  static const int maxProcessedEventIds = 200;

  /// `eventId` alanını ham metinden çıkarmak için (bozuk JSON'da da onaylayabilmek adına).
  static final RegExp _rawEventIdPattern = RegExp(r'"eventId"\s*:\s*"([^"]+)"');

  final StreamController<int> _updates = StreamController<int>.broadcast();
  StreamSubscription<void>? _eventsSubscription;

  /// Olay işleme zinciri: bir çağrı bitmeden ikincisi başlamaz.
  Future<void> _queue = Future<void>.value();

  /// Kanalı dinlemeye başlar, kuyruktaki olayları işler ve etkin antrenmanı yeniden yayınlar
  /// (12 saat kuralı burada da uygulanır). Uygulama açılışında bir kez çağrılır.
  Future<void> start() async {
    try {
      await _eventsSubscription?.cancel();
      _eventsSubscription = channel.eventsAvailable.listen(
        (_) => unawaited(processPendingEvents()),
        onError: (Object error) => debugPrint('Saat olay akışı hatası: $error'),
      );
      await processPendingEvents();
      await _republish();
    } catch (error) {
      debugPrint('Saat eşlemesi başlatılamadı: $error');
    }
  }

  /// Antrenman ekranı açılınca çağrılır: [workoutId] etkin antrenman olur ve anlık durumu yayınlanır.
  Future<void> setActiveWorkout(int workoutId) async {
    try {
      await store.setActiveWorkoutId(workoutId);
      await _republish();
    } catch (error) {
      debugPrint('Etkin antrenman ayarlanamadı: $error');
    }
  }

  /// Telefonda bir antrenman değişince çağrılır; etkin antrenmansa anlık durum yeniden yayınlanır,
  /// değilse hiçbir şey yapılmaz.
  Future<void> workoutChanged(int workoutId) async {
    try {
      if (await store.getActiveWorkoutId() != workoutId) return;
      await _republish();
    } catch (error) {
      debugPrint('Saat yayını güncellenemedi: $error');
    }
  }

  /// Kanaldaki bekleyen olayları sırayla işler, onaylar ve gerekiyorsa anlık durumu yeniden yayınlar.
  /// Aynı anda iki kez çağrılırsa ikinci çağrı birincinin bitmesini bekler (olaylar iki kez uygulanmaz).
  Future<void> processPendingEvents() {
    final next = _queue.then((_) => _processBatch());
    _queue = next;
    return next;
  }

  /// Saatten gelen olaylarla değişen antrenmanların id'leri (yayın akışı).
  Stream<int> get workoutUpdates => _updates.stream;

  /// Dinleyicileri kapatır.
  Future<void> dispose() async {
    try {
      await _eventsSubscription?.cancel();
      _eventsSubscription = null;
      if (!_updates.isClosed) await _updates.close();
    } catch (error) {
      debugPrint('Saat servisi kapatılamadı: $error');
    }
  }

  // ------------------------------------------------------------ Yayınlama

  /// Etkin antrenmanı saate yayınlar. Etkin antrenman yoksa, silinmişse ya da 12 saatten eskiyse
  /// etkinliği temizler ve anlık durumu siler.
  Future<void> _republish() async {
    try {
      final workoutId = await store.getActiveWorkoutId();
      if (workoutId == null) {
        await channel.clearSnapshot();
        return;
      }

      final processed = await store.getProcessedEventIds();
      final snapshot = await buildWatchSnapshot(
        repository,
        workoutId,
        appliedEventIds: _lastAppliedIds(processed),
        fallbackTitle: fallbackTitle,
      );
      if (snapshot == null ||
          clock().difference(snapshot.startedAt) > activeWorkoutMaxAge) {
        await store.setActiveWorkoutId(null);
        await channel.clearSnapshot();
        return;
      }
      await channel.publishSnapshot(jsonEncode(snapshot.toJson()));
    } catch (error) {
      debugPrint('Anlık durum yayınlanamadı: $error');
    }
  }

  /// İşlenmiş id'lerin son [maxAppliedEventIds] tanesi (eskiden yeniye).
  List<String> _lastAppliedIds(List<String> processed) {
    if (processed.length <= maxAppliedEventIds) return processed;
    return processed.sublist(processed.length - maxAppliedEventIds);
  }

  // ------------------------------------------------------------ Olay işleme

  /// Kuyruğu bir kez boşaltır. Hiçbir hata dışarı çıkmaz.
  Future<void> _processBatch() async {
    try {
      final raw = await channel.drainEvents();
      if (raw.isEmpty) return;

      final processed = List<String>.of(await store.getProcessedEventIds());
      final processedIds = processed.toSet();
      final activeId = await store.getActiveWorkoutId();
      final ackIds = <String>[];
      final changedWorkoutIds = <int>{};
      var newlyProcessed = 0;

      for (final text in raw) {
        final WatchEvent event;
        try {
          event = WatchEvent.fromJson(jsonDecode(text) as Map<String, Object?>);
        } catch (error) {
          // Bozuk olay: ham metinde id varsa onaylanır ki kuyrukta takılı kalmasın.
          debugPrint('Bozuk saat olayı atlandı: $error');
          final id = _rawEventId(text);
          if (id != null) ackIds.add(id);
          continue;
        }

        final id = event.eventId;
        if (processedIds.contains(id)) {
          ackIds.add(id);
          continue;
        }

        if (await _apply(event, activeId)) {
          changedWorkoutIds.add(event.workoutId);
        }
        processed.add(id);
        processedIds.add(id);
        ackIds.add(id);
        newlyProcessed++;
      }

      if (newlyProcessed > 0) {
        final overflow = processed.length - maxProcessedEventIds;
        await store.setProcessedEventIds(
          overflow > 0 ? processed.sublist(overflow) : processed,
        );
      }
      if (ackIds.isNotEmpty) await channel.ackEvents(ackIds);
      if (newlyProcessed > 0) await _republish();
      for (final id in changedWorkoutIds) {
        if (!_updates.isClosed) _updates.add(id);
      }
    } catch (error) {
      debugPrint('Saat olayları işlenemedi: $error');
    }
  }

  /// Olayı uygular. Uygulandıysa `true`; yok sayılan (etkisiz) olaylarda ya da hatada `false`.
  /// Her iki durumda da olay işlenmiş sayılır (çağıran işaretler).
  Future<bool> _apply(WatchEvent event, int? activeId) async {
    try {
      if (event.protocol != watchProtocolVersion) return false;
      if (activeId == null || event.workoutId != activeId) return false;

      final detail = await repository.getWorkoutDetail(event.workoutId);
      if (detail == null) return false;

      if (event is AddSetEvent) {
        if (event.weightKg < 0 || event.reps <= 0) return false;
        final exists = detail.exercises
            .any((e) => e.workoutExercise.id == event.workoutExerciseId);
        if (!exists) return false;
        await repository.addSet(
          event.workoutExerciseId,
          weightKg: event.weightKg,
          reps: event.reps,
        );
        return true;
      }

      if (event is DeleteSetEvent) {
        final owns = detail.exercises
            .any((e) => e.sets.any((set) => set.id == event.setId));
        if (!owns) return false;
        await repository.deleteSet(event.setId);
        return true;
      }
      return false;
    } catch (error) {
      debugPrint('Saat olayı uygulanamadı: $error');
      return false;
    }
  }

  String? _rawEventId(String text) => _rawEventIdPattern.firstMatch(text)?.group(1);
}
