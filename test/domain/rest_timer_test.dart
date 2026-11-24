import 'package:exercise_tracking_app/domain/rest_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 24, 18, 42);

  group('clampRestSeconds', () {
    test('15 sn ile 10 dk arasına sınırlar', () {
      expect(clampRestSeconds(0), restMinSeconds);
      expect(clampRestSeconds(5), 15);
      expect(clampRestSeconds(90), 90);
      expect(clampRestSeconds(9999), restMaxSeconds);
    });
  });

  group('startRest', () {
    test('bitiş = başlangıç + süre; süre sınırlanır', () {
      final state = startRest(restId: 'a', workoutId: 1, startedAt: start, seconds: 90);
      expect(state.endsAt, start.add(const Duration(seconds: 90)));
      expect(state.totalSeconds, 90);

      final tooShort = startRest(restId: 'b', workoutId: 1, startedAt: start, seconds: 3);
      expect(tooShort.totalSeconds, 15);
      expect(tooShort.endsAt, start.add(const Duration(seconds: 15)));
    });
  });

  group('adjustRest', () {
    test('süreyi ve toplamı birlikte kaydırır', () {
      final state = startRest(restId: 'a', workoutId: 1, startedAt: start, seconds: 60);
      final up = adjustRest(state, 15);
      expect(up.totalSeconds, 75);
      expect(up.endsAt, start.add(const Duration(seconds: 75)));
    });

    test('toplam en az 1 olur; sonuç bitmiş olabilir', () {
      final state = startRest(restId: 'a', workoutId: 1, startedAt: start, seconds: 15);
      final down = adjustRest(state, -60);
      expect(down.totalSeconds, 1);
      expect(down.endsAt, start.subtract(const Duration(seconds: 45)));
      expect(isRestFinished(down, start), isTrue);
    });
  });

  group('kalan süre', () {
    test('saniye yukarı yuvarlanır (90 sn ilk anda 90, 1.5 sn kala 2)', () {
      final state = startRest(restId: 'a', workoutId: 1, startedAt: start, seconds: 90);
      expect(restRemainingSeconds(state, start), 90);
      expect(restRemainingSeconds(state, start.add(const Duration(seconds: 88, milliseconds: 500))), 2);
      expect(restRemainingSeconds(state, start.add(const Duration(seconds: 90))), 0);
    });

    test('bitmişse sıfır ve bitmiş', () {
      final state = startRest(restId: 'a', workoutId: 1, startedAt: start, seconds: 30);
      final later = start.add(const Duration(minutes: 1));
      expect(restRemaining(state, later), Duration.zero);
      expect(isRestFinished(state, later), isTrue);
      expect(isRestFinished(state, start), isFalse);
    });
  });

  group('restRemainingFraction', () {
    test('kalan oran 1 ile 0 arasında azalır', () {
      final state = startRest(restId: 'a', workoutId: 1, startedAt: start, seconds: 90);
      expect(restRemainingFraction(state, start), 1.0);
      expect(restRemainingFraction(state, start.add(const Duration(seconds: 45))), closeTo(0.5, 1e-9));
      expect(restRemainingFraction(state, start.add(const Duration(minutes: 5))), 0.0);
    });
  });
}
