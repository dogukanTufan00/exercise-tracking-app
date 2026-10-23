import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/workout_repository.dart';
import '../core/formatters.dart';

/// Bir hareket için bir sonraki setin ağırlık ve tekrar taslağı.
class SetDraft {
  const SetDraft({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;
}

/// Antrenman ekranının durumu ve iş mantığı.
///
/// Her değiştirici işlemden sonra detay repository'den yeniden yüklenir; taslaklar ise
/// yalnızca kullanıcı değiştirince değişir.
class WorkoutViewModel extends ChangeNotifier {
  WorkoutViewModel(this._repository, this._workoutId);

  final WorkoutRepository _repository;
  final int _workoutId;

  /// Taslak bulunamazsa kullanılan varsayılan değer.
  static const SetDraft _defaultDraft = SetDraft(weightKg: 20, reps: 10);

  /// Gecikmeli not kaydının süresi.
  static const Duration _noteDelay = Duration(milliseconds: 500);

  WorkoutDetail? _detail;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  /// Hareket kataloğu id'sine göre "geçen sefer" setleri.
  final Map<int, List<ExerciseSet>> _previousSets = {};

  /// Antrenmandaki hareket (workoutExercise) id'sine göre taslaklar.
  final Map<int, SetDraft> _drafts = {};

  /// Antrenmandaki hareket id'sine göre bekleyen notlar ve zamanlayıcıları.
  final Map<int, String> _pendingNotes = {};
  final Map<int, Timer> _noteTimers = {};

  /// Açık olan hareketlerin (workoutExercise) id'leri. Kartlar bağımsız açılıp kapanır.
  final Set<int> _expanded = {};

  /// İlk başarılı yüklemede "son hareket açık" kuralı uygulandı mı.
  bool _initialExpansionDone = false;

  // ----------------------------------------------------------------- Okuma

  /// Yüklenene kadar null; antrenman silinmişse de null.
  WorkoutDetail? get detail => _detail;

  bool get isLoading => _isLoading;

  /// Kullanıcıya gösterilecek Türkçe hata metni; yoksa null.
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// Antrenman adı; yoksa başlangıç tarihi. Detay yoksa boş metin.
  String get title {
    final current = _detail;
    if (current == null) return '';
    return current.workout.title ??
        formatWorkoutDate(current.workout.startedAt);
  }

  /// Hareket kartı açık mı (antrenmandaki hareket id'sine göre).
  bool isExpanded(int workoutExerciseId) => _expanded.contains(workoutExerciseId);

  /// Hareket kartını açar ya da kapatır.
  void toggleExpanded(int workoutExerciseId) {
    if (!_expanded.remove(workoutExerciseId)) {
      _expanded.add(workoutExerciseId);
    }
    _notify();
  }

  /// Hareketin bir önceki antrenmandaki setleri; yoksa boş liste.
  List<ExerciseSet> previousSetsFor(int exerciseId) {
    return _previousSets[exerciseId] ?? const <ExerciseSet>[];
  }

  /// Bir sonraki setin taslağı. Taslak henüz oluşmadıysa mevcut duruma göre hesaplanır.
  SetDraft draftFor(int workoutExerciseId) {
    final existing = _drafts[workoutExerciseId];
    if (existing != null) return existing;

    final entry = _entryFor(workoutExerciseId);
    return entry == null ? _defaultDraft : _initialDraftFor(entry);
  }

  // ----------------------------------------------------------- Yükleme

  /// Antrenman detayını ve her hareketin "geçen sefer" setlerini yükler.
  Future<void> load() async {
    _isLoading = true;
    _notify();
    try {
      await _reloadAll();
      if (!_initialExpansionDone) _expandLastOnFirstLoad();
    } catch (_) {
      _errorMessage = 'Antrenman yüklenemedi.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // ------------------------------------------------------ Antrenman düzeyi

  Future<void> updateTitle(String? title) async {
    await _run('Başlık kaydedilemedi.', () async {
      await _repository.updateWorkoutTitle(_workoutId, title);
      await _reload();
    });
  }

  Future<void> addExercise(Exercise exercise) async {
    await _run('Hareket eklenemedi.', () async {
      final added =
          await _repository.addExerciseToWorkout(_workoutId, exercise.id);
      // Yeni eklenen hareket otomatik açık gelir; diğerlerinin durumu değişmez.
      _expanded.add(added.id);
      _previousSets[exercise.id] = await _repository.getPreviousSets(
        exercise.id,
        beforeWorkoutId: _workoutId,
      );
      await _reload();
    });
  }

  Future<void> removeExercise(int workoutExerciseId) async {
    _cancelNote(workoutExerciseId);
    _drafts.remove(workoutExerciseId);
    _expanded.remove(workoutExerciseId);
    await _run('Hareket kaldırılamadı.', () async {
      await _repository.removeExerciseFromWorkout(workoutExerciseId);
      await _reload();
    });
  }

  /// Katalogdaki hareketi günceller ve antrenmanı yeniden yükler. Başarılıysa `true`.
  /// Hata mesajları detay ekranındakilerle aynı.
  Future<bool> updateExercise(int exerciseId, String name, MuscleGroup muscleGroup) async {
    try {
      await _repository.updateExercise(exerciseId, name: name, muscleGroup: muscleGroup);
    } on DuplicateExerciseException {
      _errorMessage = 'Bu adda bir hareket zaten var.';
      _notify();
      return false;
    } catch (_) {
      _errorMessage = 'Hareket güncellenemedi.';
      _notify();
      return false;
    }

    // Güncelleme kaydedildi; yeniden yükleme başarısızsa yalnızca ekran hatası gösterilir.
    await _run('Hareket güncellenemedi.', _reload);
    return true;
  }

  /// Hiç hareket yoksa antrenmanı siler. Ekran geri çıkarken çağrılır.
  Future<void> discardIfEmpty() async {
    await _run('Antrenman silinemedi.', () async {
      final fresh = await _repository.getWorkoutDetail(_workoutId);
      if (fresh != null && fresh.exercises.isEmpty) {
        await _repository.deleteWorkout(_workoutId);
      }
    });
  }

  // ------------------------------------------------------------ Taslaklar

  void setDraftWeight(int workoutExerciseId, double kg) {
    final current = draftFor(workoutExerciseId);
    _drafts[workoutExerciseId] =
        SetDraft(weightKg: kg, reps: current.reps);
    _notify();
  }

  void setDraftReps(int workoutExerciseId, int reps) {
    final current = draftFor(workoutExerciseId);
    _drafts[workoutExerciseId] =
        SetDraft(weightKg: current.weightKg, reps: reps);
    _notify();
  }

  // ----------------------------------------------------------------- Setler

  /// Taslak değerleriyle yeni set ekler. Taslak değişmez.
  Future<void> addSet(int workoutExerciseId) async {
    final draft = draftFor(workoutExerciseId);
    await _run('Set eklenemedi.', () async {
      await _repository.addSet(
        workoutExerciseId,
        weightKg: draft.weightKg,
        reps: draft.reps,
      );
      await _reload();
    });
  }

  /// Son setin değerleriyle yeni set ekler. Hareketin seti yoksa hiçbir şey yapmaz.
  Future<void> repeatLastSet(int workoutExerciseId) async {
    final entry = _entryFor(workoutExerciseId);
    if (entry == null || entry.sets.isEmpty) return;

    final last = entry.sets.last;
    await _run('Set eklenemedi.', () async {
      await _repository.addSet(
        workoutExerciseId,
        weightKg: last.weightKg,
        reps: last.reps,
      );
      await _reload();
    });
  }

  Future<void> updateSet(ExerciseSet set) async {
    await _run('Set güncellenemedi.', () async {
      await _repository.updateSet(set);
      await _reload();
    });
  }

  Future<void> deleteSet(int setId) async {
    await _run('Set silinemedi.', () async {
      await _repository.deleteSet(setId);
      await _reload();
    });
  }

  // ------------------------------------------------------------------ Notlar

  /// Notu 500 ms gecikmeyle kaydeder; art arda yazımlar tek kayda indirgenir.
  void updateNote(int workoutExerciseId, String note) {
    _pendingNotes[workoutExerciseId] = note;
    _noteTimers[workoutExerciseId]?.cancel();
    _noteTimers[workoutExerciseId] =
        Timer(_noteDelay, () => _saveNote(workoutExerciseId));
  }

  /// Bekleyen tüm notları hemen kaydeder.
  Future<void> flushNotes() async {
    for (final id in _pendingNotes.keys.toList()) {
      await _saveNote(id);
    }
  }

  Future<void> _saveNote(int workoutExerciseId) async {
    _noteTimers.remove(workoutExerciseId)?.cancel();
    final note = _pendingNotes.remove(workoutExerciseId);
    if (note == null) return;

    await _run('Not kaydedilemedi.', () async {
      await _repository.updateExerciseNote(workoutExerciseId, note);
    });
  }

  // ----------------------------------------------------------- Yardımcılar

  /// Ortak hata yakalama. Hata olursa [message] ile [errorMessage] ayarlanır.
  Future<void> _run(String message, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _errorMessage = message;
      _notify();
    }
  }

  /// Detayı ve tüm hareketlerin "geçen sefer" setlerini yükler, taslakları oluşturur.
  Future<void> _reloadAll() async {
    final fresh = await _repository.getWorkoutDetail(_workoutId);
    if (_disposed) return;

    _detail = fresh;
    if (fresh != null) {
      for (final entry in fresh.exercises) {
        final exerciseId = entry.exercise.id;
        _previousSets[exerciseId] = await _repository.getPreviousSets(
          exerciseId,
          beforeWorkoutId: _workoutId,
        );
      }
    }
    _ensureDrafts();
  }

  /// Detayı yeniler (geçen sefer listelerini değiştirmez).
  Future<void> _reload() async {
    final fresh = await _repository.getWorkoutDetail(_workoutId);
    _detail = fresh;
    _ensureDrafts();
    _notify();
  }

  /// Henüz taslağı olmayan her hareket için taslak oluşturur.
  void _ensureDrafts() {
    final current = _detail;
    if (current == null) return;
    for (final entry in current.exercises) {
      _drafts.putIfAbsent(
        entry.workoutExercise.id,
        () => _initialDraftFor(entry),
      );
    }
    _drafts.removeWhere(
      (id, _) => !current.exercises.any((e) => e.workoutExercise.id == id),
    );
  }

  /// Taslak kuralı: bu antrenmandaki son set; yoksa "geçen sefer"in ilk seti; yoksa 20 kg × 10.
  SetDraft _initialDraftFor(WorkoutExerciseDetail entry) {
    if (entry.sets.isNotEmpty) {
      final last = entry.sets.last;
      return SetDraft(weightKg: last.weightKg, reps: last.reps);
    }
    final previous = previousSetsFor(entry.exercise.id);
    if (previous.isNotEmpty) {
      final first = previous.first;
      return SetDraft(weightKg: first.weightKg, reps: first.reps);
    }
    return _defaultDraft;
  }

  WorkoutExerciseDetail? _entryFor(int workoutExerciseId) {
    final current = _detail;
    if (current == null) return null;
    for (final entry in current.exercises) {
      if (entry.workoutExercise.id == workoutExerciseId) return entry;
    }
    return null;
  }

  /// İlk yüklemede yalnızca en son (en büyük position) hareketi açar.
  void _expandLastOnFirstLoad() {
    _initialExpansionDone = true;
    final exercises = _detail?.exercises;
    if (exercises == null || exercises.isEmpty) return;

    final last = exercises.reduce(
      (a, b) => a.workoutExercise.position >= b.workoutExercise.position ? a : b,
    );
    _expanded.add(last.workoutExercise.id);
  }

  void _cancelNote(int workoutExerciseId) {
    _noteTimers.remove(workoutExerciseId)?.cancel();
    _pendingNotes.remove(workoutExerciseId);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _noteTimers.values) {
      timer.cancel();
    }
    _noteTimers.clear();
    super.dispose();
  }
}
