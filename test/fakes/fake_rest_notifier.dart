import 'package:exercise_tracking_app/data/rest/rest_notifier.dart';

/// Testler için kayıt tutan bir [RestNotifier]: çağrıları sırayla saklar.
class FakeRestNotifier implements RestNotifier {
  /// Gösterilen geri sayımlar, sırayla.
  final List<({DateTime endsAt, int totalSeconds, String title})> countdowns = [];

  /// `cancel` çağrı sayısı.
  int cancelCount = 0;

  /// `notifyFinished` çağrılarındaki `vibrate` değerleri, sırayla.
  final List<bool> finishedVibrate = [];

  /// `requestPermission` çağrı sayısı.
  int permissionRequests = 0;

  /// `requestPermission` ne döndürsün.
  bool permissionGranted = true;

  @override
  Future<void> showCountdown({
    required DateTime endsAt,
    required int totalSeconds,
    required String title,
  }) async {
    countdowns.add((endsAt: endsAt, totalSeconds: totalSeconds, title: title));
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> notifyFinished({required bool vibrate}) async {
    finishedVibrate.add(vibrate);
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }
}
