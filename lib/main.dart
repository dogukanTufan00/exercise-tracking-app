import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/repositories/measurement_repository.dart';
import 'data/repositories/prefs_settings_repository.dart';
import 'data/repositories/program_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sqlite_measurement_repository.dart';
import 'data/repositories/sqlite_program_repository.dart';
import 'data/repositories/sqlite_workout_repository.dart';
import 'data/repositories/workout_repository.dart';
import 'data/services/backup_file_service.dart';
import 'data/services/database_service.dart';
import 'data/watch/watch_sync_service.dart';
import 'data/watch/watch_sync_store.dart';
import 'data/watch/wear_channel.dart';
import 'ui/core/formatters.dart';
import 'ui/core/theme/theme_controller.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');

  // Tek veritabanı bağlantısı; antrenman, ölçüm ve program repository'leri aynı örneği kullanır.
  final databaseService = DatabaseService();
  final workoutRepository = SqliteWorkoutRepository(databaseService);
  final measurementRepository = SqliteMeasurementRepository(databaseService);
  final programRepository = SqliteProgramRepository(databaseService);
  final settingsRepository = PrefsSettingsRepository();
  final themeController = ThemeController(settingsRepository);
  await themeController.load();

  // Saat eşlemesi: saatten gelen olaylar burada işlenir (bkz. docs/ARCHITECTURE.md §15).
  final watchSyncService = WatchSyncService(
    repository: workoutRepository,
    channel: MethodChannelWearChannel(),
    store: PrefsWatchSyncStore(),
    fallbackTitle: formatWorkoutDate,
  );
  unawaited(watchSyncService.start());

  // Seçili tema saate yayınlanır: açılışta ve tema her değiştiğinde (bkz. docs/ARCHITECTURE.md §15.7).
  var publishedThemeId = themeController.themeId;
  unawaited(watchSyncService.publishTheme(publishedThemeId));
  themeController.addListener(() {
    final current = themeController.themeId;
    if (current == publishedThemeId) return;
    publishedThemeId = current;
    unawaited(watchSyncService.publishTheme(current));
  });

  runApp(
    ExerciseTrackerApp(
      workoutRepository: workoutRepository,
      measurementRepository: measurementRepository,
      programRepository: programRepository,
      settingsRepository: settingsRepository,
      themeController: themeController,
      backupFileService: DeviceBackupFileService(),
      watchSyncService: watchSyncService,
    ),
  );
}

/// Uygulamanın kökü: repository'leri, tema denetleyicisini ve yedek servisini sağlayıcılarla dağıtır.
class ExerciseTrackerApp extends StatelessWidget {
  const ExerciseTrackerApp({
    super.key,
    required this.workoutRepository,
    required this.measurementRepository,
    required this.programRepository,
    required this.settingsRepository,
    required this.themeController,
    required this.backupFileService,
    this.watchSyncService,
  });

  final WorkoutRepository workoutRepository;
  final MeasurementRepository measurementRepository;
  final ProgramRepository programRepository;
  final SettingsRepository settingsRepository;
  final ThemeController themeController;
  final BackupFileService backupFileService;

  /// Saat eşlemesi servisi; testlerde verilmez ve antrenman ekranı saatsiz çalışır.
  final WatchSyncService? watchSyncService;

  @override
  Widget build(BuildContext context) {
    final watchSync = watchSyncService;
    return MultiProvider(
      providers: [
        Provider<WorkoutRepository>.value(value: workoutRepository),
        Provider<MeasurementRepository>.value(value: measurementRepository),
        Provider<ProgramRepository>.value(value: programRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        Provider<BackupFileService>.value(value: backupFileService),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        if (watchSync != null)
          Provider<WatchSyncService>.value(value: watchSync),
      ],
      child: Consumer<ThemeController>(
        builder: (context, controller, _) {
          return MaterialApp(
            title: 'Exercise Tracker',
            debugShowCheckedModeBanner: false,
            theme: controller.theme,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
