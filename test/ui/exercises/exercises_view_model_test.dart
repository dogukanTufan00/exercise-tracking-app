import 'dart:async';

import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/exercises/exercises_view_model.dart';
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

/// Aramanın her zaman hata fırlattığı repository.
class _FailingSearchRepository extends FakeWorkoutRepository {
  @override
  Future<List<Exercise>> searchExercises(String query) async {
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
  test('load tüm kataloğu A→Z getirir', () async {
    final repository = await _seededRepository();
    final viewModel = ExercisesViewModel(repository);

    await viewModel.load();

    expect(viewModel.query, '');
    expect(viewModel.isLoading, isFalse);
    expect(
      viewModel.exercises.map((e) => e.name).toList(),
      ['Bench Press', 'Plank', 'Şınav'],
    );
  });

  test('search "sinav" ile Şınav\'ı bulur', () async {
    final repository = await _seededRepository();
    final viewModel = ExercisesViewModel(repository);

    await viewModel.search('sinav');

    expect(viewModel.query, 'sinav');
    expect(viewModel.exercises.map((e) => e.name).toList(), ['Şınav']);
  });

  test('eski arama yanıtı, yeni aramanın sonuçlarını ezmez', () async {
    final gate = Completer<void>();
    final repository = _SlowFirstSearchRepository(gate);
    await repository.createExercise('Şınav', MuscleGroup.chest);
    await repository.createExercise('Plank', MuscleGroup.core);
    await repository.createExercise('Şınav 2', MuscleGroup.chest);
    final viewModel = ExercisesViewModel(repository);

    // İlk arama (tüm katalog) kapı açılana kadar bekler.
    final firstSearch = viewModel.search('');
    await viewModel.search('sin');

    expect(viewModel.query, 'sin');
    expect(viewModel.exercises.map((e) => e.name).toList(), ['Şınav', 'Şınav 2']);
    expect(viewModel.isLoading, isFalse);

    gate.complete();
    await firstSearch;

    // Geç gelen eski yanıt yok sayılmalı.
    expect(viewModel.query, 'sin');
    expect(viewModel.exercises.map((e) => e.name).toList(), ['Şınav', 'Şınav 2']);
    expect(viewModel.isLoading, isFalse);
  });

  test('repository hata fırlatınca errorMessage dolar', () async {
    final viewModel = ExercisesViewModel(_FailingSearchRepository());

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.exercises, isEmpty);
    expect(viewModel.errorMessage, 'Hareketler yüklenemedi.');

    viewModel.clearError();
    expect(viewModel.errorMessage, isNull);
  });

  test('dispose sonrası geç gelen yanıt hata fırlatmaz', () async {
    final gate = Completer<void>();
    final viewModel = ExercisesViewModel(_SlowFirstSearchRepository(gate));

    final pending = viewModel.load();
    viewModel.dispose();
    gate.complete();

    await expectLater(pending, completes);
  });
}
