import 'exercise.dart';

// Antrenman programları (#16). Bkz. docs/ARCHITECTURE.md §4 "Şema 3" ve §14.
//
// Karma model: program günleri isteğe bağlı olarak haftanın bir gününe bağlanır; antrenman başlatırken
// bugünün günü önerilir ama herhangi bir gün seçilebilir. Kaçırılan gün için hiçbir işaret tutulmaz.

/// Bir hareket için hedef: set sayısı × tekrar, isteğe bağlı ağırlık.
class ExerciseTarget {
  const ExerciseTarget({required this.sets, required this.reps, this.weightKg});

  /// 0'dan büyük.
  final int sets;

  /// 0'dan büyük.
  final int reps;

  /// Hedef ağırlık; `null` ise ağırlık hedefi yoktur (antrenmanda "geçen sefer" kullanılır).
  final double? weightKg;

  @override
  bool operator ==(Object other) {
    return other is ExerciseTarget &&
        other.sets == sets &&
        other.reps == reps &&
        other.weightKg == weightKg;
  }

  @override
  int get hashCode => Object.hash(sets, reps, weightKg);

  @override
  String toString() => 'ExerciseTarget($sets x $reps, $weightKg kg)';
}

/// Bir program (ör. "Üst/Alt 4 gün"). Aynı anda en fazla bir program etkindir.
class Program {
  const Program({required this.id, required this.name, required this.isActive});

  factory Program.fromMap(Map<String, Object?> map) {
    return Program(
      id: map['id'] as int,
      name: map['name'] as String,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  final int id;
  final String name;

  /// Antrenman başlatırken günleri önerilen program.
  final bool isActive;

  @override
  bool operator ==(Object other) {
    return other is Program && other.id == id && other.name == name && other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(id, name, isActive);

  @override
  String toString() => 'Program($id, $name, active: $isActive)';
}

/// Programın bir günü (ör. "Göğüs + Sırt", Perşembe).
class ProgramDay {
  const ProgramDay({
    required this.id,
    required this.programId,
    required this.name,
    required this.position,
    this.weekday,
  });

  factory ProgramDay.fromMap(Map<String, Object?> map) {
    return ProgramDay(
      id: map['id'] as int,
      programId: map['program_id'] as int,
      name: map['name'] as String,
      position: map['position'] as int,
      weekday: map['weekday'] as int?,
    );
  }

  final int id;
  final int programId;
  final String name;

  /// Program içindeki sıra; 0'dan başlar.
  final int position;

  /// Planlanan gün: [DateTime.monday] (1) … [DateTime.sunday] (7); `null` = belirli bir güne bağlı değil.
  final int? weekday;

  @override
  bool operator ==(Object other) {
    return other is ProgramDay &&
        other.id == id &&
        other.programId == programId &&
        other.name == name &&
        other.position == position &&
        other.weekday == weekday;
  }

  @override
  int get hashCode => Object.hash(id, programId, name, position, weekday);

  @override
  String toString() => 'ProgramDay($id, $name, weekday: $weekday)';
}

/// Program gününde bir hareket ve hedefi.
class ProgramDayExercise {
  const ProgramDayExercise({
    required this.id,
    required this.programDayId,
    required this.exerciseId,
    required this.position,
    required this.target,
  });

  factory ProgramDayExercise.fromMap(Map<String, Object?> map) {
    return ProgramDayExercise(
      id: map['id'] as int,
      programDayId: map['program_day_id'] as int,
      exerciseId: map['exercise_id'] as int,
      position: map['position'] as int,
      target: ExerciseTarget(
        sets: map['target_sets'] as int,
        reps: map['target_reps'] as int,
        weightKg: (map['target_weight_kg'] as num?)?.toDouble(),
      ),
    );
  }

  final int id;
  final int programDayId;
  final int exerciseId;

  /// Gün içindeki sıra; 0'dan başlar.
  final int position;
  final ExerciseTarget target;

  @override
  bool operator ==(Object other) {
    return other is ProgramDayExercise &&
        other.id == id &&
        other.programDayId == programDayId &&
        other.exerciseId == exerciseId &&
        other.position == position &&
        other.target == target;
  }

  @override
  int get hashCode => Object.hash(id, programDayId, exerciseId, position, target);
}

// ------------------------------------------------------------------ Okuma modelleri

/// Gündeki bir hareket, katalog bilgisiyle.
class ProgramDayExerciseDetail {
  const ProgramDayExerciseDetail({required this.dayExercise, required this.exercise});

  final ProgramDayExercise dayExercise;
  final Exercise exercise;
}

/// Bir gün ve hareketleri ([ProgramDayExercise.position] sırasıyla).
class ProgramDayDetail {
  const ProgramDayDetail({required this.day, required this.exercises});

  final ProgramDay day;
  final List<ProgramDayExerciseDetail> exercises;
}

/// Bir program ve günleri ([ProgramDay.position] sırasıyla).
class ProgramDetail {
  const ProgramDetail({required this.program, required this.days});

  final Program program;
  final List<ProgramDayDetail> days;
}
