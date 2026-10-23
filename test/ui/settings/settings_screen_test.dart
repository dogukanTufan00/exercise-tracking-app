import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:exercise_tracking_app/data/backup/backup_json_codec.dart';
import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/measurement_repository.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:exercise_tracking_app/data/services/backup_file_service.dart';
import 'package:exercise_tracking_app/ui/core/theme/theme_controller.dart';
import 'package:exercise_tracking_app/ui/settings/settings_screen.dart';

import '../../fakes/fake_backup_file_service.dart';
import '../../fakes/fake_measurement_repository.dart';
import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  Future<ThemeController> pumpSettings(
    WidgetTester tester, {
    AppThemeId initialTheme = AppThemeId.defaultTheme,
    FakeWorkoutRepository? repository,
    BackupFileService? files,
  }) async {
    // Veriler bölümünün ekranda görünmesi için sayfayı uzun tutuyoruz.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ThemeController(
      FakeSettingsRepository(initialTheme: initialTheme),
    );
    await controller.load();
    final workouts = repository ?? FakeWorkoutRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutRepository>.value(value: workouts),
          Provider<MeasurementRepository>.value(
            value: FakeMeasurementRepository(),
          ),
          Provider<ProgramRepository>.value(
            value: FakeProgramRepository(workouts),
          ),
          Provider<BackupFileService>.value(
            value: files ?? FakeBackupFileService(),
          ),
          ChangeNotifierProvider<ThemeController>.value(value: controller),
        ],
        child: Builder(
          builder: (context) {
            return MaterialApp(
              theme: context.watch<ThemeController>().theme,
              home: const SettingsScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('dört tema adı görünür', (tester) async {
    await pumpSettings(tester);

    for (final id in AppThemeId.values) {
      expect(find.text(id.label), findsOneWidget);
    }
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
  });

  testWidgets('seçili temada onay ikonu görünür', (tester) async {
    await pumpSettings(tester, initialTheme: AppThemeId.yellowNavy);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('başka temaya dokununca themeId değişir', (tester) async {
    final controller = await pumpSettings(tester);

    expect(controller.themeId, AppThemeId.defaultTheme);

    await tester.tap(find.text(AppThemeId.lightBlue.label));
    await tester.pumpAndSettle();

    expect(controller.themeId, AppThemeId.lightBlue);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('Veriler bölümü ve üç eylem satırı görünür', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Veriler'), findsOneWidget);
    expect(find.text('CSV olarak dışa aktar'), findsOneWidget);
    expect(find.text('Yedek al'), findsOneWidget);
    expect(find.text('Yedekten geri yükle'), findsOneWidget);
  });

  testWidgets('Yedek al JSON dosyasını kaydeder ve onay gösterir', (tester) async {
    final repository = FakeWorkoutRepository();
    await repository.importBackup(
      BackupData(
        exportedAt: DateTime(2026, 3, 5),
        exercises: const [],
        workouts: [
          BackupWorkout(
            startedAt: DateTime(2026, 3, 4, 18),
            exercises: const [],
          ),
        ],
      ),
    );
    final files = FakeBackupFileService();
    await pumpSettings(tester, repository: repository, files: files);

    await tester.tap(find.text('Yedek al'));
    await tester.pumpAndSettle();

    expect(files.sharedFiles, isEmpty);
    expect(files.savedFiles.length, 1);
    expect(files.savedFiles.single.mimeType, 'application/json');
    expect(files.savedFiles.single.fileName, endsWith('.json'));
    expect(decodeBackupJson(files.savedFiles.single.content).workouts.length, 1);
    expect(find.text('Yedek kaydedildi'), findsOneWidget);
  });

  testWidgets('veri yokken Yedek al hata SnackBar\'ı gösterir', (tester) async {
    final files = FakeBackupFileService();
    await pumpSettings(tester, files: files);

    await tester.tap(find.text('Yedek al'));
    await tester.pumpAndSettle();

    expect(files.savedFiles, isEmpty);
    expect(find.text('Henüz kaydedilmiş veri yok.'), findsOneWidget);
  });

  testWidgets('yedekten geri yükleme sonrası başarı SnackBar\'ı görünür',
      (tester) async {
    final files = FakeBackupFileService()
      ..pickResult = encodeBackupJson(
        BackupData(
          exportedAt: DateTime(2026, 3, 5),
          exercises: const [BackupExercise(name: 'Bench', muscleGroup: MuscleGroup.chest)],
          workouts: const [],
        ),
      );
    await pumpSettings(tester, files: files);

    await tester.tap(find.text('Yedekten geri yükle'));
    await tester.pumpAndSettle();

    expect(find.text('0 antrenman eklendi, 0 antrenman atlandı, 1 yeni hareket'),
        findsOneWidget);
  });
}
