import '../data/repositories/program_repository_contract.dart';
import 'fake_program_repository.dart';
import 'fake_workout_repository.dart';

void main() {
  runProgramRepositoryContractTests('Fake', () async {
    final workouts = FakeWorkoutRepository();
    return (programs: FakeProgramRepository(workouts), workouts: workouts);
  });
}
