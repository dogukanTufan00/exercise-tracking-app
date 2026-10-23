import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/domain/progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var nextSetId = 1;

  /// [sets]: (ağırlık, tekrar) çiftleri.
  ExerciseSession session(int workoutId, List<(double, int)> sets) {
    return ExerciseSession(
      workout: Workout(id: workoutId, startedAt: DateTime(2026, 10, workoutId)),
      sets: [
        for (final (i, (kg, reps)) in sets.indexed)
          ExerciseSet(
            id: nextSetId++,
            workoutExerciseId: workoutId,
            setNumber: i + 1,
            weightKg: kg,
            reps: reps,
          ),
      ],
    );
  }

  group('estimatedOneRepMax', () {
    test('Epley formülünü uygular', () {
      expect(estimatedOneRepMax(100, 10), closeTo(133.33, 0.01));
      expect(estimatedOneRepMax(60, 5), 70);
    });

    test('tek tekrarda ağırlığın kendisidir', () {
      expect(estimatedOneRepMax(120, 1), 120);
    });

    test('0 kg ise 0 döner', () {
      expect(estimatedOneRepMax(0, 12), 0);
    });
  });

  group('SessionStats', () {
    test('en iyi 1RM, en ağır set, hacim ve en çok tekrarı hesaplar', () {
      // 60×10 → 80; 70×3 → 77. En iyi 1RM en ağır setten gelmeyebilir.
      final stats = SessionStats.fromSession(session(1, [(60, 10), (70, 3)]));

      expect(stats.bestEstimatedOneRepMax, 80);
      expect(stats.heaviestKg, 70);
      expect(stats.volumeKg, 600 + 210);
      expect(stats.maxReps, 10);
      expect(stats.workout.id, 1);
    });

    test('ağırlıksız harekette ağırlık metrikleri 0, tekrar dolu', () {
      final stats = SessionStats.fromSession(session(1, [(0, 8), (0, 12)]));

      expect(stats.bestEstimatedOneRepMax, 0);
      expect(stats.heaviestKg, 0);
      expect(stats.volumeKg, 0);
      expect(stats.maxReps, 12);
    });
  });

  group('PersonalRecords', () {
    test('her rekoru ve kırıldığı antrenmanı bulur', () {
      final records = PersonalRecords.fromHistory([
        session(1, [(60, 10), (60, 10), (60, 10)]), // hacim 1800, 1RM 80
        session(2, [(80, 1)]), // en ağır 80, 1RM 80 (eşit: rekor 1'de kalır)
        session(3, [(70, 8)]), // 1RM ≈ 88,7
      ]);

      expect(records.heaviest!.value, 80);
      expect(records.heaviest!.workout.id, 2);
      expect(records.bestEstimatedOneRepMax!.value, closeTo(88.67, 0.01));
      expect(records.bestEstimatedOneRepMax!.workout.id, 3);
      expect(records.bestVolume!.value, 1800);
      expect(records.bestVolume!.workout.id, 1);
      expect(records.mostReps!.value, 10);
      expect(records.mostReps!.workout.id, 1);
    });

    test('eşit değerde rekor ilk ulaşılan antrenmanda kalır', () {
      final records = PersonalRecords.fromHistory([
        session(1, [(100, 5)]),
        session(2, [(100, 5)]),
      ]);

      expect(records.heaviest!.workout.id, 1);
      expect(records.bestEstimatedOneRepMax!.workout.id, 1);
      expect(records.bestVolume!.workout.id, 1);
    });

    test('geçmiş boşsa hiç rekor yoktur', () {
      final records = PersonalRecords.fromHistory(const []);

      expect(records.heaviest, isNull);
      expect(records.bestEstimatedOneRepMax, isNull);
      expect(records.bestVolume, isNull);
      expect(records.mostReps, isNull);
    });

    test('hep 0 kg ile yapılan harekette yalnızca tekrar rekoru vardır', () {
      final records = PersonalRecords.fromHistory([
        session(1, [(0, 10)]),
        session(2, [(0, 12), (0, 8)]),
      ]);

      expect(records.heaviest, isNull);
      expect(records.bestEstimatedOneRepMax, isNull);
      expect(records.bestVolume, isNull);
      expect(records.mostReps!.value, 12);
      expect(records.mostReps!.workout.id, 2);
    });
  });

  group('isPersonalRecord', () {
    ExerciseSet makeSet(double kg, int reps) => ExerciseSet(
          id: nextSetId++,
          workoutExerciseId: 1,
          setNumber: 1,
          weightKg: kg,
          reps: reps,
        );

    test('geçmiş yoksa hiçbir set rekor değildir', () {
      expect(isPersonalRecord(makeSet(100, 5), PersonalRecords.empty), isFalse);
      expect(isPersonalRecord(makeSet(0, 12), PersonalRecords.empty), isFalse);
    });

    test('daha ağır set rekordur', () {
      final previous = PersonalRecords.fromHistory([session(1, [(60, 10)])]);

      expect(isPersonalRecord(makeSet(62.5, 5), previous), isTrue);
    });

    test('aynı ağırlık ama daha yüksek 1RM rekordur', () {
      final previous = PersonalRecords.fromHistory([session(1, [(60, 5)])]);

      expect(isPersonalRecord(makeSet(60, 8), previous), isTrue);
    });

    test('eşit set rekor değildir', () {
      final previous = PersonalRecords.fromHistory([session(1, [(60, 5)])]);

      expect(isPersonalRecord(makeSet(60, 5), previous), isFalse);
    });

    test('daha hafif ve düşük 1RM rekor değildir', () {
      final previous = PersonalRecords.fromHistory([session(1, [(60, 10)])]);

      expect(isPersonalRecord(makeSet(50, 10), previous), isFalse);
    });

    test('ağırlıksız geçmişte daha çok tekrar rekordur, eşit tekrar değildir', () {
      final previous = PersonalRecords.fromHistory([session(1, [(0, 10)])]);

      expect(isPersonalRecord(makeSet(0, 12), previous), isTrue);
      expect(isPersonalRecord(makeSet(0, 10), previous), isFalse);
    });

    test('ağırlıklı geçmişi olan harekette 0 kg set rekor değildir', () {
      final previous = PersonalRecords.fromHistory([session(1, [(60, 10)])]);

      expect(isPersonalRecord(makeSet(0, 20), previous), isFalse);
    });
  });
}
