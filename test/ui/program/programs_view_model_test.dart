import 'package:exercise_tracking_app/ui/program/programs_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_workout_repository.dart';

/// Etkinleştirmenin hata fırlattığı repository.
class _FailingActivateRepository extends FakeProgramRepository {
  _FailingActivateRepository(super.workouts);

  @override
  Future<void> setActiveProgram(int programId) async => throw StateError('db');
}

void main() {
  late FakeProgramRepository repository;
  late ProgramsViewModel viewModel;

  setUp(() {
    repository = FakeProgramRepository(FakeWorkoutRepository());
    viewModel = ProgramsViewModel(repository);
  });

  tearDown(() => viewModel.dispose());

  test('load tüm programları oluşturulma sırasıyla getirir', () async {
    await repository.createProgram('A');
    await repository.createProgram('B');

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect([for (final p in viewModel.programs) p.name], ['A', 'B']);
  });

  test('createProgram listeye ekler; ilk program etkin olur', () async {
    final ok = await viewModel.createProgram('A');

    expect(ok, isTrue);
    expect(viewModel.programs.single.name, 'A');
    expect(viewModel.programs.single.isActive, isTrue);
  });

  test('createProgram boş adla false döner ve hata bırakır', () async {
    final ok = await viewModel.createProgram(' ');

    expect(ok, isFalse);
    expect(viewModel.errorMessage, 'İşlem tamamlanamadı.');
  });

  test('setActiveProgram etkinliği diğerinden alır', () async {
    await viewModel.createProgram('A');
    await viewModel.createProgram('B');
    final bId = viewModel.programs[1].id;

    final ok = await viewModel.setActiveProgram(bId);

    expect(ok, isTrue);
    final active = [for (final p in viewModel.programs) if (p.isActive) p.name];
    expect(active, ['B']);
  });

  test('setActiveProgram hata verirse false döner ve hata bırakır', () async {
    final failing = ProgramsViewModel(
      _FailingActivateRepository(FakeWorkoutRepository()),
    );
    addTearDown(failing.dispose);
    await failing.createProgram('A');

    final ok = await failing.setActiveProgram(1);

    expect(ok, isFalse);
    expect(failing.errorMessage, 'İşlem tamamlanamadı.');
  });
}
