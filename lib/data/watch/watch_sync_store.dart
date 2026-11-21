import 'package:shared_preferences/shared_preferences.dart';

/// [WatchSyncService]'in kalıcı küçük durumu: etkin antrenman ve işlenmiş olay id'leri.
///
/// Gerçeği [PrefsWatchSyncStore]; testlerde `FakeWatchSyncStore` (bellekte).
abstract interface class WatchSyncStore {
  /// Etkin antrenmanın id'si; yoksa `null`.
  Future<int?> getActiveWorkoutId();

  /// `null` etkin antrenmanı temizler.
  Future<void> setActiveWorkoutId(int? workoutId);

  /// İşlenmiş olay id'leri, eskiden yeniye.
  Future<List<String>> getProcessedEventIds();

  /// İşlenmiş olay id'lerinin tamamını yazar (eskiden yeniye; kırpma çağıranın işidir).
  Future<void> setProcessedEventIds(List<String> eventIds);
}

/// [WatchSyncStore]'un `shared_preferences` uygulaması.
class PrefsWatchSyncStore implements WatchSyncStore {
  static const String _activeKey = 'watch_active_workout_id';
  static const String _processedKey = 'watch_processed_event_ids';

  @override
  Future<int?> getActiveWorkoutId() async {
    final prefs = await SharedPreferences.getInstance();
    // Saat olaylarını arka planda işleyen ekransız motor (§15.5) da yazar; önbellek değil disk okunur.
    await prefs.reload();
    return prefs.getInt(_activeKey);
  }

  @override
  Future<void> setActiveWorkoutId(int? workoutId) async {
    final prefs = await SharedPreferences.getInstance();
    if (workoutId == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setInt(_activeKey, workoutId);
    }
  }

  @override
  Future<List<String>> getProcessedEventIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getStringList(_processedKey) ?? const <String>[];
  }

  @override
  Future<void> setProcessedEventIds(List<String> eventIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_processedKey, eventIds);
  }
}
