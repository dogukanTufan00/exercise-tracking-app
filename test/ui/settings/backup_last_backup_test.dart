import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/settings/backup_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_backup_file_service.dart';
import '../../fakes/fake_measurement_repository.dart';
import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_settings_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository repository;
  late FakeSettingsRepository settings;
  late FakeBackupFileService files;
  final now = DateTime(2026, 11, 20, 10, 0);

  setUp(() async {
    repository = FakeWorkoutRepository();
    settings = FakeSettingsRepository();
    files = FakeBackupFileService();
    // Yedeğin boş olmaması için bir hareket ekle.
    await repository.createExercise('Bench', MuscleGroup.chest);
  });

  BackupViewModel createViewModel() => BackupViewModel(
        repository,
        FakeMeasurementRepository(),
        FakeProgramRepository(repository),
        files,
        clock: () => now,
        settings: settings,
      );

  test('başarılı JSON yedeği son yedek zamanını kaydeder', () async {
    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);

    await viewModel.exportJson();

    expect(files.savedFiles, hasLength(1));
    expect(await settings.getLastBackupAt(), now);
    expect(viewModel.message, 'Yedek kaydedildi');
  });

  test('iptal edilen yedek son yedek zamanını değiştirmez', () async {
    files.cancelSave = true;
    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);

    await viewModel.exportJson();

    expect(await settings.getLastBackupAt(), isNull);
  });

  test('CSV dışa aktarma son yedek zamanını değiştirmez', () async {
    final viewModel = createViewModel();
    addTearDown(viewModel.dispose);

    await viewModel.exportCsv();

    expect(await settings.getLastBackupAt(), isNull);
  });
}
