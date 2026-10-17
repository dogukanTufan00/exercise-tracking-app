import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:exercise_tracking_app/main.dart';
import 'package:exercise_tracking_app/ui/core/theme/theme_controller.dart';
import 'package:exercise_tracking_app/ui/history/history_screen.dart';

import 'fakes/fake_settings_repository.dart';
import 'fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  testWidgets('uygulama açılışta Geçmiş ekranını gösterir', (tester) async {
    final settingsRepository = FakeSettingsRepository();
    final themeController = ThemeController(settingsRepository);
    await themeController.load();

    await tester.pumpWidget(
      ExerciseTrackerApp(
        workoutRepository: FakeWorkoutRepository(),
        settingsRepository: settingsRepository,
        themeController: themeController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}
