import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/program/program_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_workout_repository.dart';

/// Okuma ve oluşturma işlemlerinin hata fırlattığı repository.
class _FailingProgramRepository extends FakeProgramRepository {
  _FailingProgramRepository(super.workouts);

  @override
  Future<List<Program>> getPrograms() async => throw StateError('db');

  @override
  Future<Program> createProgram(String name) async => throw StateError('db');
}

List<String> _dayNames(ProgramViewModel viewModel) {
  return [for (final d in viewModel.detail!.days) d.day.name];
}

void main() {
  late FakeWorkoutRepository workouts;
  late FakeProgramRepository repository;
  late ProgramViewModel viewModel;

  setUp(() {
    workouts = FakeWorkoutRepository();
    repository = FakeProgramRepository(workouts);
    viewModel = ProgramViewModel(repository);
  });

  tearDown(() => viewModel.dispose());

  test('program yokken load sonrası detail null, hasPrograms false', () async {
    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.detail, isNull);
    expect(viewModel.hasPrograms, isFalse);
    expect(viewModel.errorMessage, isNull);
  });

  test('createProgram ilk programı etkin yapar ve detail döner', () async {
    await viewModel.createProgram('Üst/Alt');

    expect(viewModel.hasPrograms, isTrue);
    expect(viewModel.detail?.program.name, 'Üst/Alt');
    expect(viewModel.detail?.program.isActive, isTrue);
  });

  test('boş ad hata mesajı bırakır, detail değişmez', () async {
    await viewModel.createProgram('   ');

    expect(viewModel.detail, isNull);
    expect(viewModel.errorMessage, 'İşlem tamamlanamadı.');

    viewModel.clearError();
    expect(viewModel.errorMessage, isNull);
  });

  test('addDay günün id\'sini döndürür ve güne eklenir', () async {
    await viewModel.createProgram('Program');

    final dayId = await viewModel.addDay('Göğüs');

    expect(dayId, isNotNull);
    expect(viewModel.detail!.days.single.day.id, dayId);
    expect(viewModel.detail!.days.single.day.weekday, isNull);
  });

  test('addDay etkin program yokken null döner', () async {
    expect(await viewModel.addDay('Göğüs'), isNull);
  });

  test('moveDay günleri komşusuyla değiştirir; sınır dışı hiçbir şey yapmaz', () async {
    await viewModel.createProgram('Program');
    await viewModel.addDay('A');
    await viewModel.addDay('B');
    await viewModel.addDay('C');

    await viewModel.moveDay(0, 1);
    expect(_dayNames(viewModel), ['B', 'A', 'C']);

    await viewModel.moveDay(0, -1);
    expect(_dayNames(viewModel), ['B', 'A', 'C']);

    await viewModel.moveDay(2, 1);
    expect(_dayNames(viewModel), ['B', 'A', 'C']);

    await viewModel.moveDay(2, -1);
    expect(_dayNames(viewModel), ['B', 'C', 'A']);
  });

  test('renameActiveProgram adı değiştirir', () async {
    await viewModel.createProgram('Eski');

    await viewModel.renameActiveProgram('Yeni');

    expect(viewModel.detail?.program.name, 'Yeni');
  });

  test('deleteActiveProgram etkin programı siler', () async {
    await viewModel.createProgram('Program');

    await viewModel.deleteActiveProgram();

    expect(viewModel.detail, isNull);
    expect(viewModel.hasPrograms, isFalse);
  });

  test('etkin program silinince başka program varsa hasPrograms true kalır', () async {
    await viewModel.createProgram('A');
    final programId = viewModel.detail!.program.id;
    await viewModel.createProgram('B');

    await repository.deleteProgram(programId);
    await viewModel.refresh();

    expect(viewModel.detail, isNull);
    expect(viewModel.hasPrograms, isTrue);
  });

  test('refresh repository\'deki dışarıdan yapılan değişikliği görür', () async {
    await viewModel.load();
    expect(viewModel.detail, isNull);

    await repository.createProgram('Dışarıdan');
    await viewModel.refresh();

    expect(viewModel.detail?.program.name, 'Dışarıdan');
  });

  test('okuma hatası Türkçe mesaj bırakır', () async {
    final failing = ProgramViewModel(_FailingProgramRepository(workouts));
    addTearDown(failing.dispose);

    await failing.load();

    expect(failing.isLoading, isFalse);
    expect(failing.errorMessage, 'Program yüklenemedi.');
  });

  test('yazma hatası Türkçe mesaj bırakır', () async {
    final failing = ProgramViewModel(_FailingProgramRepository(workouts));
    addTearDown(failing.dispose);

    await failing.createProgram('Program');

    expect(failing.errorMessage, 'İşlem tamamlanamadı.');
  });
}
