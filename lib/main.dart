import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/repositories/measurement_repository.dart';
import 'data/repositories/prefs_settings_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sqlite_measurement_repository.dart';
import 'data/repositories/sqlite_workout_repository.dart';
import 'data/repositories/workout_repository.dart';
import 'data/services/backup_file_service.dart';
import 'data/services/database_service.dart';
import 'ui/core/theme/theme_controller.dart';
import 'ui/history/history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');

  // Tek veritabanı bağlantısı; antrenman ve ölçüm repository'leri aynı örneği kullanır.
  final databaseService = DatabaseService();
  final workoutRepository = SqliteWorkoutRepository(databaseService);
  final measurementRepository = SqliteMeasurementRepository(databaseService);
  final settingsRepository = PrefsSettingsRepository();
  final themeController = ThemeController(settingsRepository);
  await themeController.load();

  runApp(
    ExerciseTrackerApp(
      workoutRepository: workoutRepository,
      measurementRepository: measurementRepository,
      settingsRepository: settingsRepository,
      themeController: themeController,
      backupFileService: DeviceBackupFileService(),
    ),
  );
}

/// Uygulamanın kökü: repository'leri, tema denetleyicisini ve yedek servisini sağlayıcılarla dağıtır.
class ExerciseTrackerApp extends StatelessWidget {
  const ExerciseTrackerApp({
    super.key,
    required this.workoutRepository,
    required this.measurementRepository,
    required this.settingsRepository,
    required this.themeController,
    required this.backupFileService,
  });

  final WorkoutRepository workoutRepository;
  final MeasurementRepository measurementRepository;
  final SettingsRepository settingsRepository;
  final ThemeController themeController;
  final BackupFileService backupFileService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WorkoutRepository>.value(value: workoutRepository),
        Provider<MeasurementRepository>.value(value: measurementRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        Provider<BackupFileService>.value(value: backupFileService),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, controller, _) {
          return MaterialApp(
            title: 'Exercise Tracker',
            debugShowCheckedModeBanner: false,
            theme: controller.theme,
            home: const HistoryScreen(),
          );
        },
      ),
    );
  }
}
