/// Saat ile telefon arasındaki protokolün (sürüm 1) Dart modelleri (bkz. docs/ARCHITECTURE.md §15.4).
///
/// Kotlin karşılığı: `wear/app/src/main/java/com/dogukantufan00/exercise_tracking_app/data/WatchProtocol.kt`.
/// İki dosya birebir aynı JSON'u üretmeli ve okumalıdır; birini değiştiren ötekini de değiştirir.
library;

/// Protokol sürümü. Farklı sürümdeki olay ve anlık durumlar yok sayılır.
const int watchProtocolVersion = 1;

/// Anlık durumun yayınlandığı DataItem yolu.
const String watchSnapshotPath = '/workout/active';

/// Saatin olay gönderdiği mesaj yolu.
const String watchEventPath = '/event';

/// Telefona geri bildirilen işlenmiş olay id'lerinin en fazla sayısı.
const int maxAppliedEventIds = 50;

/// Bir set değeri (ağırlık + tekrar); taslak ve "geçen sefer" için.
class WatchSetValue {
  const WatchSetValue({required this.weightKg, required this.reps});

  factory WatchSetValue.fromJson(Map<String, Object?> json) => WatchSetValue(
        weightKg: (json['weightKg'] as num).toDouble(),
        reps: json['reps'] as int,
      );

  final double weightKg;
  final int reps;

  Map<String, Object?> toJson() => {'weightKg': weightKg, 'reps': reps};

  @override
  bool operator ==(Object other) =>
      other is WatchSetValue && other.weightKg == weightKg && other.reps == reps;

  @override
  int get hashCode => Object.hash(weightKg, reps);
}

/// Hareketin hedefi (programdan kopyalanmış).
class WatchTarget {
  const WatchTarget({required this.sets, required this.reps, this.weightKg});

  factory WatchTarget.fromJson(Map<String, Object?> json) => WatchTarget(
        sets: json['sets'] as int,
        reps: json['reps'] as int,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
      );

  final int sets;
  final int reps;
  final double? weightKg;

  Map<String, Object?> toJson() => {'sets': sets, 'reps': reps, 'weightKg': weightKg};

  @override
  bool operator ==(Object other) =>
      other is WatchTarget &&
      other.sets == sets &&
      other.reps == reps &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(sets, reps, weightKg);
}

/// Telefonda kayıtlı bir set.
class WatchSet {
  const WatchSet({
    required this.id,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
  });

  factory WatchSet.fromJson(Map<String, Object?> json) => WatchSet(
        id: json['id'] as int,
        setNumber: json['setNumber'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
        reps: json['reps'] as int,
      );

  final int id;
  final int setNumber;
  final double weightKg;
  final int reps;

  Map<String, Object?> toJson() =>
      {'id': id, 'setNumber': setNumber, 'weightKg': weightKg, 'reps': reps};

  @override
  bool operator ==(Object other) =>
      other is WatchSet &&
      other.id == id &&
      other.setNumber == setNumber &&
      other.weightKg == weightKg &&
      other.reps == reps;

  @override
  int get hashCode => Object.hash(id, setNumber, weightKg, reps);
}

/// Antrenmandaki bir hareket.
class WatchExercise {
  const WatchExercise({
    required this.workoutExerciseId,
    required this.name,
    required this.target,
    required this.sets,
    required this.draft,
    required this.previous,
  });

  factory WatchExercise.fromJson(Map<String, Object?> json) => WatchExercise(
        workoutExerciseId: json['workoutExerciseId'] as int,
        name: json['name'] as String,
        target: json['target'] == null
            ? null
            : WatchTarget.fromJson(json['target'] as Map<String, Object?>),
        sets: [
          for (final item in json['sets'] as List<Object?>)
            WatchSet.fromJson(item as Map<String, Object?>),
        ],
        draft: WatchSetValue.fromJson(json['draft'] as Map<String, Object?>),
        previous: [
          for (final item in json['previous'] as List<Object?>)
            WatchSetValue.fromJson(item as Map<String, Object?>),
        ],
      );

  final int workoutExerciseId;
  final String name;
  final WatchTarget? target;
  final List<WatchSet> sets;
  final WatchSetValue draft;
  final List<WatchSetValue> previous;

  Map<String, Object?> toJson() => {
        'workoutExerciseId': workoutExerciseId,
        'name': name,
        'target': target?.toJson(),
        'sets': [for (final set in sets) set.toJson()],
        'draft': draft.toJson(),
        'previous': [for (final value in previous) value.toJson()],
      };
}

/// Telefonun saate yayınladığı anlık durum.
class WatchSnapshot {
  const WatchSnapshot({
    this.protocol = watchProtocolVersion,
    required this.workoutId,
    required this.title,
    required this.startedAt,
    required this.appliedEventIds,
    required this.exercises,
  });

  factory WatchSnapshot.fromJson(Map<String, Object?> json) => WatchSnapshot(
        protocol: json['protocol'] as int,
        workoutId: json['workoutId'] as int,
        title: json['title'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        appliedEventIds: [
          for (final id in json['appliedEventIds'] as List<Object?>) id as String,
        ],
        exercises: [
          for (final item in json['exercises'] as List<Object?>)
            WatchExercise.fromJson(item as Map<String, Object?>),
        ],
      );

  final int protocol;
  final int workoutId;

  /// Antrenman başlığı; yoksa telefonun gösterdiği tarih metni.
  final String title;
  final DateTime startedAt;

  /// Telefonun işlediği son en fazla [maxAppliedEventIds] olayın id'si.
  final List<String> appliedEventIds;

  /// `position` sırasıyla.
  final List<WatchExercise> exercises;

  Map<String, Object?> toJson() => {
        'protocol': protocol,
        'workoutId': workoutId,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
        'appliedEventIds': appliedEventIds,
        'exercises': [for (final exercise in exercises) exercise.toJson()],
      };
}

/// Saatten gelen olay. JSON'daki `type` alanı alt sınıfı belirler.
sealed class WatchEvent {
  const WatchEvent({
    this.protocol = watchProtocolVersion,
    required this.eventId,
    required this.workoutId,
    required this.createdAt,
  });

  /// JSON'dan okur. Bilinmeyen `type` ya da eksik/hatalı alan varsa [FormatException] fırlatır.
  factory WatchEvent.fromJson(Map<String, Object?> json) {
    try {
      final protocol = json['protocol'] as int;
      final eventId = json['eventId'] as String;
      final workoutId = json['workoutId'] as int;
      final createdAt = DateTime.parse(json['createdAt'] as String);
      switch (json['type']) {
        case AddSetEvent.type:
          return AddSetEvent(
            protocol: protocol,
            eventId: eventId,
            workoutId: workoutId,
            createdAt: createdAt,
            workoutExerciseId: json['workoutExerciseId'] as int,
            weightKg: (json['weightKg'] as num).toDouble(),
            reps: json['reps'] as int,
          );
        case DeleteSetEvent.type:
          return DeleteSetEvent(
            protocol: protocol,
            eventId: eventId,
            workoutId: workoutId,
            createdAt: createdAt,
            setId: json['setId'] as int,
          );
        default:
          throw FormatException('Bilinmeyen olay türü: ${json['type']}');
      }
    } on TypeError catch (error) {
      throw FormatException('Geçersiz olay: $error');
    }
  }

  final int protocol;
  final String eventId;
  final int workoutId;
  final DateTime createdAt;

  Map<String, Object?> toJson();

  Map<String, Object?> _baseJson(String type) => {
        'protocol': protocol,
        'eventId': eventId,
        'type': type,
        'workoutId': workoutId,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Saatte "Set tamam" denildi.
final class AddSetEvent extends WatchEvent {
  const AddSetEvent({
    super.protocol,
    required super.eventId,
    required super.workoutId,
    required super.createdAt,
    required this.workoutExerciseId,
    required this.weightKg,
    required this.reps,
  });

  static const String type = 'addSet';

  final int workoutExerciseId;
  final double weightKg;
  final int reps;

  @override
  Map<String, Object?> toJson() => {
        ..._baseJson(type),
        'workoutExerciseId': workoutExerciseId,
        'weightKg': weightKg,
        'reps': reps,
      };
}

/// Saatte telefonun onayladığı bir set silindi.
final class DeleteSetEvent extends WatchEvent {
  const DeleteSetEvent({
    super.protocol,
    required super.eventId,
    required super.workoutId,
    required super.createdAt,
    required this.setId,
  });

  static const String type = 'deleteSet';

  final int setId;

  @override
  Map<String, Object?> toJson() => {..._baseJson(type), 'setId': setId};
}
