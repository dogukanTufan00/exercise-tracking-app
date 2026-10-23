import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/repositories/program_repository_contract.dart';
import 'fake_program_repository.dart';
import 'fake_workout_repository.dart';

void main() {
  runProgramRepositoryContractTests('Fake', () async {
    final workouts = FakeWorkoutRepository();
    return (programs: FakeProgramRepository(workouts), workouts: workouts);
  });

  test('mergeExercises program gün hareketini hedefe taşır', () async {
    final workouts = FakeWorkoutRepository();
    final programs = FakeProgramRepository(workouts);

    final source = await workouts.createExercise('Bench', MuscleGroup.chest);
    final target = await workouts.createExercise('Bench Press', MuscleGroup.chest);
    final programId = (await programs.createProgram('Plan')).id;
    final dayId = (await programs.addDay(programId, 'Gün A')).id;
    await programs.addDayExercise(
      dayId,
      source.id,
      const ExerciseTarget(sets: 3, reps: 10, weightKg: 40),
    );

    await workouts.mergeExercises(sourceId: source.id, targetId: target.id);

    final detail = (await programs.getProgramDetail(programId))!;
    expect(detail.days.single.exercises.single.exercise.id, target.id);
    expect(detail.days.single.exercises.single.dayExercise.exerciseId, target.id);
    expect(detail.days.single.exercises.single.dayExercise.target.sets, 3);
  });
}
