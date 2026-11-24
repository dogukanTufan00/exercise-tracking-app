import 'dart:async';
import 'dart:convert';

import 'package:exercise_tracking_app/data/watch/wear_channel.dart';

/// Testler için bellekte bir [WearChannel]: yayınlanan anlık durumları, bekleyen olayları ve
/// onaylanan id'leri kaydeder.
class FakeWearChannel implements WearChannel {
  /// Yayınlanan anlık durum JSON'ları, yayın sırasıyla.
  final List<String> snapshots = [];

  /// `clearSnapshot` çağrı sayısı.
  int clearCount = 0;

  /// Henüz kuyruktan silinmemiş ham olay metinleri.
  final List<String> pendingEvents = [];

  /// Şimdiye kadar onaylanan tüm olay id'leri.
  final List<String> ackedIds = [];

  /// Yayınlanan tema adları (`AppThemeId.name`), yayın sırasıyla.
  final List<String> publishedThemes = [];

  /// Yayınlanan program JSON'ları, yayın sırasıyla.
  final List<String> programs = [];

  /// `clearProgram` çağrı sayısı.
  int clearProgramCount = 0;

  /// Yayınlanan `/events/applied` JSON'ları, yayın sırasıyla.
  final List<String> appliedPayloads = [];

  /// Yayınlanan dinlenme süreleri (`/settings/rest`), yayın sırasıyla.
  final List<int> publishedRestSeconds = [];

  final StreamController<void> _events = StreamController<void>.broadcast();

  /// Son yayınlanan anlık durumu çözümlenmiş JSON olarak döndürür; hiç yoksa `null`.
  Map<String, Object?>? get lastSnapshot =>
      snapshots.isEmpty ? null : jsonDecode(snapshots.last) as Map<String, Object?>;

  /// Kuyruğa olay ekler ve [eventsAvailable] dinleyicilerini uyandırır.
  void enqueue(String rawEvent) {
    pendingEvents.add(rawEvent);
    _events.add(null);
  }

  @override
  Future<void> publishSnapshot(String json) async {
    snapshots.add(json);
  }

  @override
  Future<void> clearSnapshot() async {
    clearCount++;
  }

  @override
  Future<void> publishRestSettings(int restSeconds) async {
    publishedRestSeconds.add(restSeconds);
  }

  @override
  Future<void> publishProgram(String json) async {
    programs.add(json);
  }

  @override
  Future<void> clearProgram() async {
    clearProgramCount++;
  }

  @override
  Future<void> publishApplied(String json) async {
    appliedPayloads.add(json);
  }

  @override
  Future<void> publishTheme(String themeId) async {
    publishedThemes.add(themeId);
  }

  @override
  Future<List<String>> drainEvents() async => List<String>.of(pendingEvents);

  @override
  Future<void> ackEvents(List<String> eventIds) async {
    ackedIds.addAll(eventIds);
    pendingEvents.removeWhere((raw) {
      final id = _eventIdOf(raw);
      return id != null && eventIds.contains(id);
    });
  }

  @override
  Stream<void> get eventsAvailable => _events.stream;

  /// Dinleyicileri kapatır (test sonunda çağrılır).
  Future<void> close() => _events.close();

  /// Ham metinden `eventId`'yi çıkarır (bozuk JSON'da da, Kotlin köprüsü gibi metin araması ile).
  static String? _eventIdOf(String raw) {
    return RegExp(r'"eventId"\s*:\s*"([^"]+)"').firstMatch(raw)?.group(1);
  }
}
