import 'dart:convert';

import '../models/backup_data.dart';
import '../models/muscle_group.dart';

/// Yedek dosyasının `format` alanındaki kimlik.
const String backupFormatId = 'exercise-tracking-app-backup';

/// Yedek verisini JSON metnine çevirir (okunabilir, iki boşluk girintili).
///
/// Her zaman güncel biçim sürümüyle ([BackupData.currentFormatVersion]) yazar.
String encodeBackupJson(BackupData data) {
  final map = <String, Object?>{
    'format': backupFormatId,
    'format_version': BackupData.currentFormatVersion,
    'exported_at': data.exportedAt.toIso8601String(),
    'exercises': [
      for (final exercise in data.exercises)
        {
          'name': exercise.name,
          'muscle_group': exercise.muscleGroup.name,
        },
    ],
    'workouts': [
      for (final workout in data.workouts)
        {
          'started_at': workout.startedAt.toIso8601String(),
          'title': workout.title,
          'exercises': [
            for (final exercise in workout.exercises)
              {
                'exercise': exercise.exerciseName,
                'muscle_group': exercise.muscleGroup.name,
                'note': exercise.note,
                'sets': [
                  for (final set in exercise.sets)
                    {
                      'weight_kg': set.weightKg,
                      'reps': set.reps,
                    },
                ],
              },
          ],
        },
    ],
    'measurement_types': [
      for (final type in data.measurementTypes)
        {
          'name': type.name,
          'unit': type.unit,
        },
    ],
    'measurements': [
      for (final measurement in data.measurements)
        {
          'type': measurement.typeName,
          'unit': measurement.unit,
          'measured_at': measurement.measuredAt.toIso8601String(),
          'value': measurement.value,
        },
    ],
    'programs': [
      for (final program in data.programs)
        {
          'name': program.name,
          'is_active': program.isActive,
          'days': [
            for (final day in program.days)
              {
                'name': day.name,
                'weekday': day.weekday,
                'exercises': [
                  for (final entry in day.exercises)
                    {
                      'exercise': entry.exerciseName,
                      'muscle_group': entry.muscleGroup.name,
                      'sets': entry.sets,
                      'reps': entry.reps,
                      'weight_kg': entry.weightKg,
                    },
                ],
              },
          ],
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// JSON metnini yedek verisine çevirir.
///
/// Biçim veya sürüm uyuşmazlığında ve bozuk alanlarda [BackupFormatException] fırlatır.
/// Değer kontrolleri (ör. tekrar sayısının pozitif olması) burada yapılmaz.
BackupData decodeBackupJson(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const BackupFormatException(
      'Dosya okunamadı: geçerli bir yedek dosyası değil.',
    );
  }

  if (decoded is! Map<String, dynamic> || decoded['format'] != backupFormatId) {
    throw const BackupFormatException(
      'Bu dosya bu uygulamanın yedek dosyası değil.',
    );
  }

  final root = decoded;
  final version = _requireInt(root, 'format_version', '');
  if (version > BackupData.currentFormatVersion) {
    throw const BackupFormatException(
      'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Uygulamayı güncelleyin.',
    );
  }

  final exportedAt = _requireDate(root, 'exported_at', '');

  final exercises = <BackupExercise>[];
  final exerciseList = _requireList(root, 'exercises', '');
  for (var i = 0; i < exerciseList.length; i++) {
    final path = 'exercises[$i]';
    final item = _asMap(exerciseList[i], path);
    exercises.add(
      BackupExercise(
        name: _requireString(item, 'name', path),
        muscleGroup: _requireMuscleGroup(item, 'muscle_group', path),
      ),
    );
  }

  final workouts = <BackupWorkout>[];
  final workoutList = _requireList(root, 'workouts', '');
  for (var i = 0; i < workoutList.length; i++) {
    workouts.add(_decodeWorkout(workoutList[i], 'workouts[$i]'));
  }

  // Ölçümler biçim 2'de eklendi; biçim 1 dosyalarında bu anahtarlar hiç okunmaz.
  final measurementTypes = <BackupMeasurementType>[];
  final measurements = <BackupMeasurement>[];
  if (version >= 2) {
    final typeList = _optionalList(root, 'measurement_types', '');
    for (var i = 0; i < typeList.length; i++) {
      measurementTypes.add(_decodeMeasurementType(typeList[i], 'measurement_types[$i]'));
    }

    final measurementList = _optionalList(root, 'measurements', '');
    for (var i = 0; i < measurementList.length; i++) {
      measurements.add(_decodeMeasurement(measurementList[i], 'measurements[$i]'));
    }
  }

  // Programlar biçim 3'te eklendi; biçim 1 ve 2 dosyalarında liste boş kalır.
  final programs = <BackupProgram>[];
  if (version >= 3) {
    final programList = _optionalList(root, 'programs', '');
    for (var i = 0; i < programList.length; i++) {
      programs.add(_decodeProgram(programList[i], 'programs[$i]'));
    }
  }

  return BackupData(
    formatVersion: version,
    exportedAt: exportedAt,
    exercises: exercises,
    workouts: workouts,
    measurementTypes: measurementTypes,
    measurements: measurements,
    programs: programs,
  );
}

/// Yedek dosyası okunamadığında kullanıcıya gösterilecek hata.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

BackupWorkout _decodeWorkout(Object? value, String path) {
  final item = _asMap(value, path);
  final exerciseList = _requireList(item, 'exercises', path);
  final exercises = <BackupWorkoutExercise>[];
  for (var i = 0; i < exerciseList.length; i++) {
    exercises.add(_decodeWorkoutExercise(exerciseList[i], '$path.exercises[$i]'));
  }
  return BackupWorkout(
    startedAt: _requireDate(item, 'started_at', path),
    title: _optionalString(item, 'title', path),
    exercises: exercises,
  );
}

BackupWorkoutExercise _decodeWorkoutExercise(Object? value, String path) {
  final item = _asMap(value, path);
  final setList = _requireList(item, 'sets', path);
  final sets = <BackupSet>[];
  for (var i = 0; i < setList.length; i++) {
    final setPath = '$path.sets[$i]';
    final set = _asMap(setList[i], setPath);
    sets.add(
      BackupSet(
        weightKg: _requireNum(set, 'weight_kg', setPath).toDouble(),
        reps: _requireInt(set, 'reps', setPath),
      ),
    );
  }
  return BackupWorkoutExercise(
    exerciseName: _requireString(item, 'exercise', path),
    muscleGroup: _requireMuscleGroup(item, 'muscle_group', path),
    note: _optionalString(item, 'note', path),
    sets: sets,
  );
}

BackupMeasurementType _decodeMeasurementType(Object? value, String path) {
  final item = _asMap(value, path);
  return BackupMeasurementType(
    name: _requireString(item, 'name', path),
    unit: _requireString(item, 'unit', path),
  );
}

BackupMeasurement _decodeMeasurement(Object? value, String path) {
  final item = _asMap(value, path);
  return BackupMeasurement(
    typeName: _requireString(item, 'type', path),
    unit: _requireString(item, 'unit', path),
    measuredAt: _requireDate(item, 'measured_at', path),
    value: _requireNum(item, 'value', path).toDouble(),
  );
}

BackupProgram _decodeProgram(Object? value, String path) {
  final item = _asMap(value, path);
  final dayList = _requireList(item, 'days', path);
  final days = <BackupProgramDay>[];
  for (var i = 0; i < dayList.length; i++) {
    days.add(_decodeProgramDay(dayList[i], '$path.days[$i]'));
  }
  return BackupProgram(
    name: _requireString(item, 'name', path),
    isActive: _requireBool(item, 'is_active', path),
    days: days,
  );
}

BackupProgramDay _decodeProgramDay(Object? value, String path) {
  final item = _asMap(value, path);
  final exerciseList = _requireList(item, 'exercises', path);
  final exercises = <BackupProgramExercise>[];
  for (var i = 0; i < exerciseList.length; i++) {
    exercises.add(_decodeProgramExercise(exerciseList[i], '$path.exercises[$i]'));
  }
  final weekday = _optionalInt(item, 'weekday', path);
  if (weekday != null && (weekday < DateTime.monday || weekday > DateTime.sunday)) {
    _corrupt(_fieldPath(path, 'weekday'));
  }
  return BackupProgramDay(
    name: _requireString(item, 'name', path),
    weekday: weekday,
    exercises: exercises,
  );
}

BackupProgramExercise _decodeProgramExercise(Object? value, String path) {
  final item = _asMap(value, path);
  final weight = _optionalNum(item, 'weight_kg', path);
  return BackupProgramExercise(
    exerciseName: _requireString(item, 'exercise', path),
    muscleGroup: _requireMuscleGroup(item, 'muscle_group', path),
    sets: _requireInt(item, 'sets', path),
    reps: _requireInt(item, 'reps', path),
    weightKg: weight?.toDouble(),
  );
}

/// [path] boşsa alan adı tek başına, değilse `path.key` biçiminde döner.
String _fieldPath(String path, String key) => path.isEmpty ? key : '$path.$key';

Never _corrupt(String path) {
  throw BackupFormatException('Yedek dosyası bozuk: $path');
}

Map<String, dynamic> _asMap(Object? value, String path) {
  if (value is! Map<String, dynamic>) _corrupt(path);
  return value;
}

List<dynamic> _requireList(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  if (value is! List) _corrupt(_fieldPath(path, key));
  return value;
}

/// Anahtar yoksa boş liste; varsa [_requireList] kuralları uygulanır.
List<dynamic> _optionalList(Map<String, dynamic> map, String key, String path) {
  if (!map.containsKey(key)) return const [];
  return _requireList(map, key, path);
}

String _requireString(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  if (value is! String) _corrupt(_fieldPath(path, key));
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) _corrupt(_fieldPath(path, key));
  return value;
}

num _requireNum(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  if (value is! num) _corrupt(_fieldPath(path, key));
  return value;
}

/// Tam sayı bekler; JSON'da `10` ve `10.0` ikisi de kabul edilir.
int _requireInt(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  if (value is int) return value;
  if (value is double && value == value.truncateToDouble()) return value.toInt();
  _corrupt(_fieldPath(path, key));
}

/// Anahtar yoksa ya da `null` ise `null`; varsa [_requireNum] kuralları uygulanır.
num? _optionalNum(Map<String, dynamic> map, String key, String path) {
  if (map[key] == null) return null;
  return _requireNum(map, key, path);
}

/// Anahtar yoksa ya da `null` ise `null`; varsa [_requireInt] kuralları uygulanır.
int? _optionalInt(Map<String, dynamic> map, String key, String path) {
  if (map[key] == null) return null;
  return _requireInt(map, key, path);
}

bool _requireBool(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  if (value is! bool) _corrupt(_fieldPath(path, key));
  return value;
}

DateTime _requireDate(Map<String, dynamic> map, String key, String path) {
  final value = map[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) _corrupt(_fieldPath(path, key));
  return parsed;
}

MuscleGroup _requireMuscleGroup(
  Map<String, dynamic> map,
  String key,
  String path,
) {
  return MuscleGroup.fromName(_requireString(map, key, path));
}
