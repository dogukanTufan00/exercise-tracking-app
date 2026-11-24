import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/settings_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/history/history_screen.dart';
import 'package:exercise_tracking_app/ui/history/history_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  final now = DateTime(2026, 11, 20, 12, 0, 0);
  late FakeWorkoutRepository repository;
  late FakeProgramRepository programs;
  late FakeSettingsRepository settings;

  setUp(() {
    repository = FakeWorkoutRepository();
    programs = FakeProgramRepository(repository);
    settings = FakeSettingsRepository();
  });

  Future<HistoryViewModel> loadViewModel() async {
    final viewModel = HistoryViewModel(
      repository,
      programs,
      settings: settings,
      clock: () => now,
    );
    addTearDown(viewModel.dispose);
    await viewModel.load();
    return viewModel;
  }

  Future<void> addWorkout() async {
    await repository.createWorkout(startedAt: now.subtract(const Duration(days: 1)));
  }

  group('yedek hatırlatması koşulları', () {
    test('hiç yedek yoksa ve antrenman varsa "Henüz yedek almadın"', () async {
      await addWorkout();
      final viewModel = await loadViewModel();

      expect(viewModel.backupReminderTitle, 'Henüz yedek almadın');
    });

    test('antrenman yoksa hatırlatma gösterilmez', () async {
      final viewModel = await loadViewModel();

      expect(viewModel.backupReminderTitle, isNull);
    });

    test('son yedek 3 gün önceyse gösterilmez', () async {
      await addWorkout();
      await settings.setLastBackupAt(now.subtract(const Duration(days: 3)));

      final viewModel = await loadViewModel();

      expect(viewModel.backupReminderTitle, isNull);
    });

    test('son yedek 20 gün önceyse "Son yedeğin 20 gün önce"', () async {
      await addWorkout();
      await settings.setLastBackupAt(now.subtract(const Duration(days: 20)));

      final viewModel = await loadViewModel();

      expect(viewModel.backupReminderTitle, 'Son yedeğin 20 gün önce');
    });

    test('yakın zamanda kapatılmışsa gösterilmez', () async {
      await addWorkout();
      await settings.setBackupReminderDismissedAt(now.subtract(const Duration(days: 2)));

      final viewModel = await loadViewModel();

      expect(viewModel.backupReminderTitle, isNull);
    });

    test('7 günden önce kapatılmışsa yeniden gösterilir', () async {
      await addWorkout();
      await settings.setBackupReminderDismissedAt(now.subtract(const Duration(days: 8)));

      final viewModel = await loadViewModel();

      expect(viewModel.backupReminderTitle, 'Henüz yedek almadın');
    });

    test('kapat çağrısı kapatma zamanını saklar ve uyarıyı gizler', () async {
      await addWorkout();
      final viewModel = await loadViewModel();

      await viewModel.dismissBackupReminder();

      expect(viewModel.backupReminderTitle, isNull);
      expect(await settings.getBackupReminderDismissedAt(), now);
    });
  });

  testWidgets('geçmiş kartında bitmiş antrenmanın süresi yazılır', (tester) async {
    final workout = await repository.createWorkout(
      startedAt: now.subtract(const Duration(days: 1)),
    );
    await repository.setWorkoutFinishedAt(
      workout.id,
      workout.startedAt.add(const Duration(hours: 1, minutes: 12)),
    );
    await settings.setLastBackupAt(now);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: repository),
          Provider<ProgramRepository>.value(value: programs),
          Provider<SettingsRepository>.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 sa 12 dk'), findsOneWidget);
    expect(find.text('Henüz yedek almadın'), findsNothing);
  });

  testWidgets('hatırlatma kartı kapatılınca kaybolur', (tester) async {
    await addWorkout();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: repository),
          Provider<ProgramRepository>.value(value: programs),
          Provider<SettingsRepository>.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Henüz yedek almadın'), findsOneWidget);
    expect(find.text('Verilerin yalnızca bu telefonda.'), findsOneWidget);

    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();

    expect(find.text('Henüz yedek almadın'), findsNothing);
  });
}
