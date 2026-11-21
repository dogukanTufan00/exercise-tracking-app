import 'package:exercise_tracking_app/data/watch/watch_sync_store.dart';

/// Testler için bellekte bir [WatchSyncStore].
class FakeWatchSyncStore implements WatchSyncStore {
  FakeWatchSyncStore({this.activeWorkoutId, List<String> processedEventIds = const []})
      : _processedEventIds = List<String>.of(processedEventIds);

  /// Etkin antrenman id'si (testte doğrudan okunabilir ya da ayarlanabilir).
  int? activeWorkoutId;
  List<String> _processedEventIds;

  @override
  Future<int?> getActiveWorkoutId() async => activeWorkoutId;

  @override
  Future<void> setActiveWorkoutId(int? workoutId) async {
    activeWorkoutId = workoutId;
  }

  @override
  Future<List<String>> getProcessedEventIds() async =>
      List<String>.of(_processedEventIds);

  @override
  Future<void> setProcessedEventIds(List<String> eventIds) async {
    _processedEventIds = List<String>.of(eventIds);
  }

  /// Testlerin durumu doğrulaması için mevcut işlenmiş id'ler (kopya).
  List<String> get processedEventIds => List<String>.of(_processedEventIds);
}
