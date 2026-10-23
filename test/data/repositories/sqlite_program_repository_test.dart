import 'package:exercise_tracking_app/data/repositories/sqlite_program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/sqlite_workout_repository.dart';
import 'package:exercise_tracking_app/data/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'program_repository_contract.dart';

void main() {
  sqfliteFfiInit();

  // Her çift (ve ikinci içe aktarma çifti) kendi bellek içi veritabanını kullanır; testten sonra kapanır.
  final services = <DatabaseService>[];

  Future<ProgramContractRepos> create() async {
    final service = DatabaseService(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    services.add(service);
    return (
      programs: SqliteProgramRepository(service),
      workouts: SqliteWorkoutRepository(service),
    );
  }

  runProgramRepositoryContractTests(
    'SQLite',
    create,
    disposeRepository: (_) async {
      for (final service in services) {
        await service.close();
      }
      services.clear();
    },
  );
}
