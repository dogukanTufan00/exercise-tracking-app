import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/repositories/prefs_settings_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sqlite_workout_repository.dart';
import 'data/repositories/workout_repository.dart';
import 'data/services/database_service.dart';
import 'ui/core/theme/theme_controller.dart';
import 'ui/history/history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');

  final workoutRepository = SqliteWorkoutRepository(DatabaseService());
  final settingsRepository = PrefsSettingsRepository();
  final themeController = ThemeController(settingsRepository);
  await themeController.load();

  runApp(
    ExerciseTrackerApp(
      workoutRepository: workoutRepository,
      settingsRepository: settingsRepository,
      themeController: themeController,
    ),
  );
}

/// Uygulamanın kökü: repository'leri ve tema denetleyicisini sağlayıcılarla dağıtır.
class ExerciseTrackerApp extends StatelessWidget {
  const ExerciseTrackerApp({
    super.key,
    required this.workoutRepository,
    required this.settingsRepository,
    required this.themeController,
  });

  final WorkoutRepository workoutRepository;
  final SettingsRepository settingsRepository;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WorkoutRepository>.value(value: workoutRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
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
