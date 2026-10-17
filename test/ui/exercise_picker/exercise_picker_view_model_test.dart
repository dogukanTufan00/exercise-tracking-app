import 'dart:async';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/exercise_picker/exercise_picker_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_workout_repository.dart';

/// İlk aramanın sonucunu, bir kapı açılana kadar geciktiren repository.
class _SlowFirstSearchRepository extends FakeWorkoutRepository {
  _SlowFirstSearchRepository(this.gate);

  final Completer<void> gate;
  int _calls = 0;

  @override
  Future<List<Exercise>> searchExercises(String query) async {
    _calls++;
    final snapshot = await super.searchExercises(query);
    if (_calls == 1) await gate.future;
    return snapshot;
  }
}

/// Oluşturma her zaman hata veren repository.
class _FailingCreateRepository extends FakeWorkoutRepository {
  @override
  Future<Exercise> createExercise(String name, MuscleGroup muscleGroup) async {
    throw StateError('veritabanı hatası');
  }
}

Future<FakeWorkoutRepository> _seededRepository() async {
  final repository = FakeWorkoutRepository();
  await repository.createExercise('Şınav', MuscleGroup.chest);
  await repository.createExercise('Plank', MuscleGroup.core);
  await repository.createExercise('Bench Press', MuscleGroup.chest);
  return repository;
}

void main() {
  test('load tüm katalogu sıralı getirir', () async {
    final repository = await _seededRepository();
    final viewModel = ExercisePickerViewModel(repository);

    await viewModel.load();

    expect(viewModel.query, '');
    expect(viewModel.isLoading, isFalse);
    expect(
      viewModel.results.map((e) => e.name).toList(),
      ['Bench Press', 'Plank', 'Şınav'],
    );
  });

  test('search "sin" ile Şınav\'ı bulur', () async {
    final repository = await _seededRepository();
    final viewModel = ExercisePickerViewModel(repository);

    await viewModel.search('sin');

    expect(viewModel.query, 'sin');
    expect(viewModel.results.map((e) => e.name).toList(), ['Şınav']);
  });

  test('canCreate sorgu boşken false, mevcut ad varken false, yeni adda true',
      () async {
    final repository = await _seededRepository();
    final viewModel = ExercisePickerViewModel(repository);

    await viewModel.load();
    expect(viewModel.canCreate, isFalse);

    await viewModel.search('şınav');
    expect(viewModel.canCreate, isFalse);

    await viewModel.search('  SINAV ');
    expect(viewModel.canCreate, isFalse);

    await viewModel.search('Yeni Hareket');
    expect(viewModel.results, isEmpty);
    expect(viewModel.canCreate, isTrue);
  });

  test('createExercise grup seçilmeden null döner ve hareket oluşturmaz', () async {
    final repository = FakeWorkoutRepository();
    final viewModel = ExercisePickerViewModel(repository);

    await viewModel.search('  Yeni Hareket ');
    final created = await viewModel.createExercise();

    expect(created, isNull);
    expect(await repository.searchExercises(''), isEmpty);
  });

  test('createExercise grup seçilince hareketi oluşturur', () async {
    final repository = FakeWorkoutRepository();
    final viewModel = ExercisePickerViewModel(repository);

    await viewModel.search('  Yeni Hareket ');
    viewModel.selectGroup(MuscleGroup.legs);
    expect(viewModel.selectedGroup, MuscleGroup.legs);

    final created = await viewModel.createExercise();

    expect(created, isNotNull);
    expect(created!.name, 'Yeni Hareket');
    expect(created.muscleGroup, MuscleGroup.legs);
    expect(await repository.searchExercises('yeni'), [created]);
    expect(viewModel.errorMessage, isNull);
  });

  test('aynı ad için errorMessage dolar ve null döner', () async {
    final repository = await _seededRepository();
    final viewModel = ExercisePickerViewModel(repository);

    await viewModel.search('SINAV');
    viewModel.selectGroup(MuscleGroup.chest);
    final created = await viewModel.createExercise();

    expect(created, isNull);
    expect(viewModel.errorMessage, 'Bu hareket zaten katalogda var');

    viewModel.clearError();
    expect(viewModel.errorMessage, isNull);
  });

  test('beklenmeyen hata errorMessage olarak "Hareket eklenemedi" yazar', () async {
    final viewModel = ExercisePickerViewModel(_FailingCreateRepository());

    await viewModel.search('Yeni');
    viewModel.selectGroup(MuscleGroup.back);
    final created = await viewModel.createExercise();

    expect(created, isNull);
    expect(viewModel.errorMessage, 'Hareket eklenemedi');
  });

  test('eski arama yanıtı, yeni aramanın sonuçlarını ezmez', () async {
    final gate = Completer<void>();
    final repository = _SlowFirstSearchRepository(gate);
    await repository.createExercise('Şınav', MuscleGroup.chest);
    await repository.createExercise('Plank', MuscleGroup.core);
    await repository.createExercise('Şınav 2', MuscleGroup.chest);
    final viewModel = ExercisePickerViewModel(repository);

    // İlk arama (tüm katalog) kapı açılana kadar bekler.
    final firstSearch = viewModel.search('');
    await viewModel.search('sin');

    expect(viewModel.query, 'sin');
    expect(viewModel.results.map((e) => e.name).toList(), ['Şınav', 'Şınav 2']);
    expect(viewModel.isLoading, isFalse);

    gate.complete();
    await firstSearch;

    // Geç gelen eski yanıt yok sayılmalı.
    expect(viewModel.query, 'sin');
    expect(viewModel.results.map((e) => e.name).toList(), ['Şınav', 'Şınav 2']);
    expect(viewModel.isLoading, isFalse);
  });

  test('dispose sonrası geç gelen yanıt hata fırlatmaz', () async {
    final gate = Completer<void>();
    final viewModel = ExercisePickerViewModel(_SlowFirstSearchRepository(gate));

    final pending = viewModel.load();
    viewModel.dispose();
    gate.complete();

    await expectLater(pending, completes);
  });
}
