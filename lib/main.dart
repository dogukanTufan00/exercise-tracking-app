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
import 'data/rest/rest_controller.dart';
import 'data/rest/rest_notifier.dart';
import 'data/rest/rest_store.dart';
import 'data/services/database_service.dart';
import 'data/watch/watch_aware_program_repository.dart';
import 'data/watch/watch_aware_workout_repository.dart';
import 'data/watch/watch_sync_service.dart';
import 'data/watch/watch_sync_store.dart';
import 'data/watch/wear_background.dart';
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
  // Servis sarılmamış repository'leri kullanır; sağlayıcılara sarılmış olanlar verilir (§15.8).
  final restStore = PrefsRestStore();
  final watchSyncService = WatchSyncService(
    repository: workoutRepository,
    programRepository: programRepository,
    channel: MethodChannelWearChannel(),
    store: PrefsWatchSyncStore(),
    fallbackTitle: formatWorkoutDate,
    restStore: restStore,
    settings: settingsRepository,
  );
  unawaited(watchSyncService.start());

  // Telefondaki dinlenme sayacı (§16.2): saatle senkron, bildirim ve bitiş titreşimi.
  final restController = RestController(
    store: restStore,
    settings: settingsRepository,
    notifier: MethodChannelRestNotifier(),
    watchSync: watchSyncService,
  );
  unawaited(restController.load());

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
      workoutRepository: WatchAwareWorkoutRepository(workoutRepository, watchSyncService),
      measurementRepository: measurementRepository,
      programRepository: WatchAwareProgramRepository(programRepository, watchSyncService),
      settingsRepository: settingsRepository,
      themeController: themeController,
      backupFileService: DeviceBackupFileService(),
      watchSyncService: watchSyncService,
      restController: restController,
    ),
  );
}

/// Telefon uygulaması kapalıyken saat olaylarını işleyen ekransız giriş noktası (§15.5).
/// Android'deki `WearBackgroundRunner` bu adı çağırır; adı değişirse orası da değişmelidir.
@pragma('vm:entry-point')
Future<void> wearBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  final databaseService = DatabaseService();
  final service = WatchSyncService(
    repository: SqliteWorkoutRepository(databaseService),
    programRepository: SqliteProgramRepository(databaseService),
    channel: MethodChannelWearChannel(),
    store: PrefsWatchSyncStore(),
    fallbackTitle: formatWorkoutDate,
    restStore: PrefsRestStore(),
    settings: PrefsSettingsRepository(),
  );
  await runWearBackground(
    service: service,
    onDone: () async {
      await databaseService.close();
      await notifyWearBackgroundDone();
    },
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
    this.restController,
  });

  final WorkoutRepository workoutRepository;
  final MeasurementRepository measurementRepository;
  final ProgramRepository programRepository;
  final SettingsRepository settingsRepository;
  final ThemeController themeController;
  final BackupFileService backupFileService;

  /// Saat eşlemesi servisi; testlerde verilmez ve antrenman ekranı saatsiz çalışır.
  final WatchSyncService? watchSyncService;

  /// Telefondaki dinlenme sayacı (§16.2); testlerde verilmez.
  final RestController? restController;

  @override
  Widget build(BuildContext context) {
    final watchSync = watchSyncService;
    final rest = restController;
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
        if (rest != null)
          ChangeNotifierProvider<RestController>.value(value: rest),
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
