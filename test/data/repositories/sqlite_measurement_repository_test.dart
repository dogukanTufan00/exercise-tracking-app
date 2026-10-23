import 'package:exercise_tracking_app/data/repositories/sqlite_measurement_repository.dart';
import 'package:exercise_tracking_app/data/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'measurement_repository_contract.dart';

void main() {
  sqfliteFfiInit();
  late DatabaseService service;
  runMeasurementRepositoryContractTests(
    'SQLite',
    () async {
      service = DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      return SqliteMeasurementRepository(service);
    },
    disposeRepository: (_) => service.close(),
  );
}
