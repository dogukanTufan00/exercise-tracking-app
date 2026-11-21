import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/program_repository.dart';
import '../repositories/workout_repository.dart';
import 'watch_protocol.dart';
import 'watch_snapshot_builder.dart';
import 'watch_sync_store.dart';
import 'wear_channel.dart';

/// Telefon tarafında saat eşlemesinin tüm mantığı (bkz. docs/ARCHITECTURE.md §15.3–15.8).
///
/// - Etkin antrenmanın anlık durumunu saate yayınlar ([setActiveWorkout], [workoutChanged], [activeWorkoutChanged]).
/// - Etkin programı saate yayınlar ([programChanged]).
/// - Saatten gelen olayları işler ([processPendingEvents]): her olay tam bir kez uygulanır.
/// - Olaylarla değişen antrenmanları [workoutUpdates] ile duyurur (açık Antrenman ekranı yenilensin diye).
///
/// Hiçbir metot dışarıya hata fırlatmaz: saat tarafındaki sorunlar telefon uygulamasını bozmaz.
///
/// [repository] ve [programRepository] sarılmamış (saate haber vermeyen) örnekler olmalıdır; aksi halde
/// sarmalayıcılar ile bu servis birbirini tetikler.
class WatchSyncService {
  WatchSyncService({
    required this.repository,
    required this.programRepository,
    required this.channel,
    required this.store,
    required this.fallbackTitle,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final WorkoutRepository repository;

  /// Etkin programı saate yayınlamak ve saatten gün başlatmak için (§15.8). Sarılmamış (watch-aware olmayan) örnek.
  final ProgramRepository programRepository;
  final WearChannel channel;
  final WatchSyncStore store;

  /// Başlıksız antrenmanın saatte gösterilecek adı (main.dart `formatWorkoutDate` verir).
  final String Function(DateTime startedAt) fallbackTitle;
  final DateTime Function() clock;

  /// Etkin antrenman bu süreden eski başlamışsa temizlenir; saatten gelen başlatma olayı da bu süreden
  /// eskiyse yok sayılır.
  static const Duration activeWorkoutMaxAge = Duration(hours: 12);

  /// Saklanan işlenmiş olay id'lerinin en fazla sayısı.
  static const int maxProcessedEventIds = 200;

  /// `eventId` alanını ham metinden çıkarmak için (bozuk JSON'da da onaylayabilmek adına).
  static final RegExp _rawEventIdPattern = RegExp(r'"eventId"\s*:\s*"([^"]+)"');

  final StreamController<int> _updates = StreamController<int>.broadcast();
  StreamSubscription<void>? _eventsSubscription;

  /// Olay işleme zinciri: bir çağrı bitmeden ikincisi başlamaz.
  Future<void> _queue = Future<void>.value();

  /// Kanalı dinlemeye başlar, kuyruktaki olayları işler, etkin antrenmanı ve programı yeniden yayınlar
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
      await programChanged();
      await _publishApplied();
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

  /// Etkin antrenmanı (varsa) koşulsuz yeniden yayınlar; hangi antrenmanın değiştiği bilinmeyen değişikliklerden
  /// sonra repository sarmalayıcısı çağırır (§15.8 madde 2). Hata fırlatmaz.
  Future<void> activeWorkoutChanged() => _republish();

  /// Program verisi değişince çağrılır: etkin programı `/program/active`'e yeniden yayınlar ya da
  /// etkin program yoksa siler (§15.8). `start()` de bir kez çağırır. Hata fırlatmaz.
  Future<void> programChanged() async {
    try {
      final detail = await programRepository.getActiveProgramDetail();
      if (detail == null) {
        await channel.clearProgram();
        return;
      }

      final days = [...detail.days]
        ..sort((a, b) => a.day.position.compareTo(b.day.position));
      final program = WatchProgram(
        programId: detail.program.id,
        name: detail.program.name,
        days: [
          for (final day in days)
            WatchProgramDay(
              dayId: day.day.id,
              name: day.day.name,
              weekday: day.day.weekday,
              exercises: [
                for (final exercise in ([...day.exercises]
                  ..sort((a, b) => a.dayExercise.position.compareTo(b.dayExercise.position))))
                  exercise.exercise.name,
              ],
            ),
        ],
      );
      await channel.publishProgram(jsonEncode(program.toJson()));
    } catch (error) {
      debugPrint('Program saate yayınlanamadı: $error');
    }
  }

  /// Seçili temayı saate yayınlar (bkz. docs/ARCHITECTURE.md §15.7). Hata fırlatmaz.
  Future<void> publishTheme(AppThemeId themeId) async {
    try {
      await channel.publishTheme(themeId.name);
    } catch (error) {
      debugPrint('Tema saate yayınlanamadı: $error');
    }
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

  /// İşlenmiş olay id'lerinin son [maxAppliedEventIds] tanesini `/events/applied`'e yazar (§15.8).
  Future<void> _publishApplied() async {
    try {
      final processed = await store.getProcessedEventIds();
      await channel.publishApplied(jsonEncode({
        'protocol': watchProtocolVersion,
        'appliedEventIds': _lastAppliedIds(processed),
      }));
    } catch (error) {
      debugPrint('İşlenen olaylar saate yayınlanamadı: $error');
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
      var activeId = await store.getActiveWorkoutId();
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

        final changed = await _apply(event, activeId);
        if (changed != null) {
          changedWorkoutIds.add(changed);
          // Saatten başlatılan antrenman etkin olur; sonraki set olayları onu hedefler.
          if (event is StartWorkoutEvent) activeId = changed;
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
      if (newlyProcessed > 0) {
        await _republish();
        await _publishApplied();
      }
      for (final id in changedWorkoutIds) {
        if (!_updates.isClosed) _updates.add(id);
      }
    } catch (error) {
      debugPrint('Saat olayları işlenemedi: $error');
    }
  }

  /// Olayı uygular. Etkisi olduysa etkilenen antrenmanın id'sini döner; yok sayıldıysa ya da hata olduysa `null`.
  /// Her iki durumda da çağıran olayı işlenmiş sayar.
  Future<int?> _apply(WatchEvent event, int? activeId) async {
    try {
      if (event.protocol != watchProtocolVersion) return null;
      return switch (event) {
        StartWorkoutEvent() => await _applyStart(event),
        AddSetEvent() => await _applyAddSet(event, activeId),
        DeleteSetEvent() => await _applyDeleteSet(event, activeId),
      };
    } catch (error) {
      debugPrint('Saat olayı uygulanamadı: $error');
      return null;
    }
  }

  /// Saatten başlatma: gün varsa ondan, yoksa boş antrenman açılır ve etkin olur. Etkin antrenman
  /// olup olmadığına bakılmaz.
  Future<int?> _applyStart(StartWorkoutEvent event) async {
    if (clock().difference(event.createdAt) > activeWorkoutMaxAge) return null;

    final dayId = event.programDayId;
    Workout workout;
    if (dayId == null) {
      workout = await repository.createWorkout(startedAt: event.createdAt);
    } else {
      try {
        workout = await programRepository.startWorkoutFromDay(
          dayId,
          startedAt: event.createdAt,
        );
      } on ArgumentError {
        // Gün silinmiş: olay yok sayılır.
        return null;
      }
    }
    await store.setActiveWorkoutId(workout.id);
    return workout.id;
  }

  Future<int?> _applyAddSet(AddSetEvent event, int? activeId) async {
    if (event.workoutId != activeId) return null;
    if (event.weightKg < 0 || event.reps <= 0) return null;

    final detail = await repository.getWorkoutDetail(event.workoutId);
    if (detail == null) return null;
    final exists = detail.exercises
        .any((e) => e.workoutExercise.id == event.workoutExerciseId);
    if (!exists) return null;

    await repository.addSet(
      event.workoutExerciseId,
      weightKg: event.weightKg,
      reps: event.reps,
    );
    return event.workoutId;
  }

  Future<int?> _applyDeleteSet(DeleteSetEvent event, int? activeId) async {
    if (event.workoutId != activeId) return null;

    final detail = await repository.getWorkoutDetail(event.workoutId);
    if (detail == null) return null;
    final owns = detail.exercises
        .any((e) => e.sets.any((set) => set.id == event.setId));
    if (!owns) return null;

    await repository.deleteSet(event.setId);
    return event.workoutId;
  }

  String? _rawEventId(String text) => _rawEventIdPattern.firstMatch(text)?.group(1);
}
