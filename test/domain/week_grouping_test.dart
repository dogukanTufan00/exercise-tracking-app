import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/domain/week_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSummary _summary(int id, DateTime startedAt, {int setCount = 0}) {
  return WorkoutSummary(
    workout: Workout(id: id, startedAt: startedAt),
    exerciseCount: 1,
    setCount: setCount,
    muscleGroups: const [],
  );
}

void main() {
  group('startOfWeek', () {
    test('Pazartesi günü kendisini döndürür', () {
      expect(startOfWeek(DateTime(2026, 10, 12, 15)), DateTime(2026, 10, 12));
    });

    test('Pazar günü o haftanın Pazartesi\'sini döndürür', () {
      expect(startOfWeek(DateTime(2026, 10, 18, 20, 30)), DateTime(2026, 10, 12));
    });

    test('saat bilgisini sıfırlar', () {
      expect(startOfWeek(DateTime(2026, 10, 14, 23, 59)), DateTime(2026, 10, 12));
    });
  });

  group('groupByWeek', () {
    test('boş liste boş grup listesi döndürür', () {
      expect(groupByWeek(const []), isEmpty);
    });

    test('Pazar 23:59 ile Pazartesi 00:00 farklı haftalarda gruplanır', () {
      final sunday = _summary(1, DateTime(2026, 10, 18, 23, 59));
      final monday = _summary(2, DateTime(2026, 10, 19));

      final groups = groupByWeek([monday, sunday]);

      expect(groups, hasLength(2));
      expect(groups[0].weekStart, DateTime(2026, 10, 19));
      expect(groups[0].workouts.single, monday);
      expect(groups[1].weekStart, DateTime(2026, 10, 12));
      expect(groups[1].workouts.single, sunday);
    });

    test('yıl dönümü haftası (29 Aralık 2025 – 4 Ocak 2026) tek grupta toplanır', () {
      final monday = _summary(1, DateTime(2025, 12, 29, 9));
      final sunday = _summary(2, DateTime(2026, 1, 4, 18));

      final groups = groupByWeek([sunday, monday]);

      expect(groups, hasLength(1));
      expect(groups.single.weekStart, DateTime(2025, 12, 29));
      expect(groups.single.workouts, [sunday, monday]);
    });

    test('girdi sırası korunur ve gruplar en yeni hafta önce gelir', () {
      final a = _summary(1, DateTime(2026, 10, 20, 18));
      final b = _summary(2, DateTime(2026, 10, 19, 9));
      final c = _summary(3, DateTime(2026, 10, 6, 9));
      final d = _summary(4, DateTime(2026, 10, 5, 9));

      final groups = groupByWeek([a, b, c, d]);

      expect(groups.map((g) => g.weekStart), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 5),
      ]);
      expect(groups[0].workouts, [a, b]);
      expect(groups[1].workouts, [c, d]);
    });

    test('antrenmanı olmayan haftalar için grup oluşturulmaz', () {
      final first = _summary(1, DateTime(2026, 10, 1));
      final last = _summary(2, DateTime(2026, 10, 29));

      final groups = groupByWeek([last, first]);

      expect(groups, hasLength(2));
    });

    test('setCount grup içindeki setlerin toplamıdır', () {
      final groups = groupByWeek([
        _summary(3, DateTime(2026, 10, 19, 18), setCount: 2),
        _summary(1, DateTime(2026, 10, 14, 18), setCount: 4),
        _summary(2, DateTime(2026, 10, 13, 18), setCount: 5),
      ]);

      expect(groups[0].setCount, 2);
      expect(groups[1].setCount, 9);
    });

    test('boş bir grubun setCount değeri 0\'dır', () {
      final group = WeekGroup(weekStart: DateTime(2026, 10, 12), workouts: const []);

      expect(group.setCount, 0);
    });
  });
}
