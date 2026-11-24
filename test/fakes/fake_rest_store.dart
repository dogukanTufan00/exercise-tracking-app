import 'package:exercise_tracking_app/data/rest/rest_store.dart';
import 'package:exercise_tracking_app/domain/rest_timer.dart';

/// Testler için bellekte bir [RestStore].
class FakeRestStore implements RestStore {
  FakeRestStore({this.rest});

  /// Kayıtlı sayaç (testte doğrudan okunabilir ya da ayarlanabilir).
  RestState? rest;

  @override
  Future<RestState?> getRest() async => rest;

  @override
  Future<void> setRest(RestState? value) async {
    rest = value;
  }
}
