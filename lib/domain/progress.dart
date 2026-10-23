import '../data/models/models.dart';

// İlerleme grafiği ve kişisel rekorlar için hesaplamalar (bkz. docs/ARCHITECTURE.md §12).
// Saf Dart'tır: Flutter'a ve veritabanına bağlı değildir, kolayca test edilir.

/// Bir setin tahmini tek tekrar maksimumu (1RM), Epley formülüyle: `ağırlık × (1 + tekrar / 30)`.
///
/// Tek tekrarda ağırlığın kendisidir. Yaklaşık 12 tekrarın üstünde isabeti düşer.
double estimatedOneRepMax(double weightKg, int reps) {
  if (reps <= 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// Bir antrenmandaki setlerden çıkarılan değerler; grafikte bir nokta.
class SessionStats {
  const SessionStats({
    required this.workout,
    required this.bestEstimatedOneRepMax,
    required this.heaviestKg,
    required this.volumeKg,
    required this.maxReps,
  });

  factory SessionStats.fromSession(ExerciseSession session) {
    var best1rm = 0.0;
    var heaviest = 0.0;
    var volume = 0.0;
    var maxReps = 0;
    for (final set in session.sets) {
      final e1rm = estimatedOneRepMax(set.weightKg, set.reps);
      if (e1rm > best1rm) best1rm = e1rm;
      if (set.weightKg > heaviest) heaviest = set.weightKg;
      if (set.reps > maxReps) maxReps = set.reps;
      volume += set.weightKg * set.reps;
    }
    return SessionStats(
      workout: session.workout,
      bestEstimatedOneRepMax: best1rm,
      heaviestKg: heaviest,
      volumeKg: volume,
      maxReps: maxReps,
    );
  }

  final Workout workout;

  /// Antrenmandaki setlerin en yüksek tahmini 1RM'i (ana metrik).
  final double bestEstimatedOneRepMax;

  /// Antrenmandaki en ağır set.
  final double heaviestKg;

  /// Toplam hacim: tüm setlerin ağırlık × tekrar toplamı.
  final double volumeKg;

  /// Tek setteki en çok tekrar; ağırlıksız hareketlerde (barfiks gibi) grafik bunu gösterir.
  final int maxReps;
}

/// Bir rekorun değeri ve kırıldığı antrenman.
class PersonalRecord {
  const PersonalRecord({required this.value, required this.workout});

  final double value;
  final Workout workout;

  @override
  String toString() => 'PersonalRecord($value, workout ${workout.id})';
}

/// Bir hareketin kişisel rekorları. Ağırlıklı hareketlerde ilk üçü, ağırlıksızlarda
/// [mostReps] gösterilir. Değeri 0 olan rekor (ör. hep 0 kg ile yapılan
/// harekette en ağır ağırlık) anlamsız olduğu için null'dır.
class PersonalRecords {
  const PersonalRecords({
    this.heaviest,
    this.bestEstimatedOneRepMax,
    this.bestVolume,
    this.mostReps,
  });

  /// [history] en eskiden en yeniye sıralı olmalıdır ([WorkoutRepository.getExerciseHistory] gibi).
  /// Eşitlikte rekor, ona ilk ulaşılan antrenmanda kalır.
  factory PersonalRecords.fromHistory(List<ExerciseSession> history) {
    return PersonalRecords.fromStats([
      for (final session in history) SessionStats.fromSession(session),
    ]);
  }

  /// [PersonalRecords.fromHistory] ile aynı; istatistikler zaten hesaplandıysa tekrar hesaplamaz.
  factory PersonalRecords.fromStats(List<SessionStats> stats) {
    return PersonalRecords(
      heaviest: _best(stats, (s) => s.heaviestKg),
      bestEstimatedOneRepMax: _best(stats, (s) => s.bestEstimatedOneRepMax),
      bestVolume: _best(stats, (s) => s.volumeKg),
      mostReps: _best(stats, (s) => s.maxReps.toDouble()),
    );
  }

  static const empty = PersonalRecords();

  final PersonalRecord? heaviest;
  final PersonalRecord? bestEstimatedOneRepMax;
  final PersonalRecord? bestVolume;

  /// Tek setteki en çok tekrar; ağırlıksız hareketlerde gösterilen rekor.
  final PersonalRecord? mostReps;

  static PersonalRecord? _best(
    List<SessionStats> stats,
    double Function(SessionStats) valueOf,
  ) {
    PersonalRecord? best;
    for (final s in stats) {
      final value = valueOf(s);
      // Kesin büyüklük: eşit değer rekoru sonraki antrenmana taşımaz.
      if (value > (best?.value ?? 0)) {
        best = PersonalRecord(value: value, workout: s.workout);
      }
    }
    return best;
  }
}

/// [set], [previous] rekorlarını (bu antrenmandan **önceki** antrenmanlardan hesaplanmış) geçiyor mu?
///
/// - Önceki kayıt yoksa (`previous` boş) hiçbir set rekor değildir: ilk kez yapılan hareketin
///   her seti "rekor" sayılmasın.
/// - Ağırlıklı set: ağırlık `previous.heaviest`'ı **ya da** tahmini 1RM `previous.bestEstimatedOneRepMax`'i
///   kesin olarak (>) geçerse rekordur.
/// - Ağırlıksız set (0 kg), önceki geçmiş de ağırlıksızsa (`previous.heaviest == null`):
///   tekrar `previous.mostReps`'i kesin olarak geçerse rekordur.
bool isPersonalRecord(ExerciseSet set, PersonalRecords previous) {
  final isEmpty = previous.heaviest == null &&
      previous.bestEstimatedOneRepMax == null &&
      previous.bestVolume == null &&
      previous.mostReps == null;
  if (isEmpty) return false;

  if (set.weightKg > 0) {
    final heaviest = previous.heaviest?.value ?? 0;
    final best1rm = previous.bestEstimatedOneRepMax?.value ?? 0;
    final e1rm = estimatedOneRepMax(set.weightKg, set.reps);
    return set.weightKg > heaviest || e1rm > best1rm;
  }

  // Geçmişte ağırlıklı bir set varsa ağırlıksız set tekrar rekoru olamaz.
  if (previous.heaviest != null) return false;
  return set.reps > (previous.mostReps?.value ?? 0);
}
