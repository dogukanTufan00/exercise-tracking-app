import 'package:exercise_tracking_app/ui/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDuration', () {
    test('dakika ve saat biçimleri', () {
      expect(formatDuration(const Duration(minutes: 45)), '45 dk');
      expect(formatDuration(const Duration(hours: 1)), '1 sa');
      expect(formatDuration(const Duration(hours: 1, minutes: 12)), '1 sa 12 dk');
    });

    test('1 dakikadan kısa süre "1 dk" olur', () {
      expect(formatDuration(const Duration(seconds: 20)), '1 dk');
      expect(formatDuration(Duration.zero), '1 dk');
    });

    test('dakikaya aşağı yuvarlar', () {
      expect(formatDuration(const Duration(minutes: 74, seconds: 59)), '1 sa 14 dk');
    });
  });

  group('formatElapsed', () {
    test('saat yoksa dakika:saniye', () {
      expect(formatElapsed(const Duration(minutes: 42, seconds: 13)), '42:13');
      expect(formatElapsed(const Duration(seconds: 5)), '0:05');
    });

    test('bir saati geçince saat:dakika:saniye', () {
      expect(formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 13)), '1:02:13');
    });
  });

  group('formatRestClock', () {
    test('dakika:saniye biçimi', () {
      expect(formatRestClock(90), '1:30');
      expect(formatRestClock(5), '0:05');
      expect(formatRestClock(600), '10:00');
    });
  });
}
