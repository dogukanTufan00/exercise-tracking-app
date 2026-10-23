import '../data/repositories/measurement_repository_contract.dart';
import 'fake_measurement_repository.dart';

void main() {
  runMeasurementRepositoryContractTests('Fake', () async => FakeMeasurementRepository());
}
