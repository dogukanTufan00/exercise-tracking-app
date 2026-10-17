import '../data/repositories/workout_repository_contract.dart';
import 'fake_workout_repository.dart';

void main() {
  runWorkoutRepositoryContractTests('Fake', () async => FakeWorkoutRepository());
}
