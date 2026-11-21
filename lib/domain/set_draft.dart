import '../data/models/models.dart';

/// Bir hareket için bir sonraki setin ağırlık ve tekrar taslağı.
class SetDraft {
  const SetDraft({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;
}

/// Taslak bulunamazsa kullanılan varsayılan değer (20 kg × 10).
const SetDraft defaultSetDraft = SetDraft(weightKg: 20, reps: 10);

/// Bir hareketin bir sonraki seti için taslak kuralı (bkz. docs/ARCHITECTURE.md §15.4).
///
/// Kural: bu antrenmandaki son set; yoksa hedef (tekrar = hedef tekrar, ağırlık = hedef ağırlık;
/// hedefte ağırlık yoksa "geçen sefer"in ilk seti, o da yoksa 20 kg); yoksa "geçen sefer"in
/// ilk seti; yoksa [defaultSetDraft].
SetDraft initialSetDraft(WorkoutExerciseDetail entry, List<ExerciseSet> previousSets) {
  if (entry.sets.isNotEmpty) {
    final last = entry.sets.last;
    return SetDraft(weightKg: last.weightKg, reps: last.reps);
  }
  final target = entry.workoutExercise.target;
  if (target != null) {
    final weightKg = target.weightKg ??
        (previousSets.isNotEmpty ? previousSets.first.weightKg : defaultSetDraft.weightKg);
    return SetDraft(weightKg: weightKg, reps: target.reps);
  }
  if (previousSets.isNotEmpty) {
    final first = previousSets.first;
    return SetDraft(weightKg: first.weightKg, reps: first.reps);
  }
  return defaultSetDraft;
}
