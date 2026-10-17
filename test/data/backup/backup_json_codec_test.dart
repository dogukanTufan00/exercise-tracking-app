import 'dart:convert';

import 'package:exercise_tracking_app/data/backup/backup_json_codec.dart';
import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

BackupData _sampleData() {
  return BackupData(
    exportedAt: DateTime(2026, 10, 18, 10),
    exercises: const [
      BackupExercise(name: 'Bench Press', muscleGroup: MuscleGroup.chest),
      BackupExercise(name: 'Şınav', muscleGroup: MuscleGroup.arms),
    ],
    workouts: [
      BackupWorkout(
        startedAt: DateTime(2026, 10, 17, 18, 30),
        title: 'Üst vücut',
        exercises: const [
          BackupWorkoutExercise(
            exerciseName: 'Bench Press',
            muscleGroup: MuscleGroup.chest,
            note: '2. sette formum bozuldu',
            sets: [
              BackupSet(weightKg: 60, reps: 10),
              BackupSet(weightKg: 62.5, reps: 8),
            ],
          ),
          BackupWorkoutExercise(
            exerciseName: 'Şınav',
            muscleGroup: MuscleGroup.arms,
            sets: [],
          ),
        ],
      ),
      BackupWorkout(
        startedAt: DateTime(2026, 10, 18, 7, 5),
        exercises: const [],
      ),
    ],
  );
}

Map<String, dynamic> _validMap() {
  // Tüm iç içe literaller açıkça dynamic: testler alanların tipini bozabilmeli.
  return <String, dynamic>{
    'format': 'exercise-tracking-app-backup',
    'format_version': 1,
    'exported_at': '2026-10-18T10:00:00.000',
    'exercises': <dynamic>[
      <String, dynamic>{'name': 'Bench Press', 'muscle_group': 'chest'},
    ],
    'workouts': <dynamic>[
      <String, dynamic>{
        'started_at': '2026-10-17T18:30:00.000',
        'title': 'Upper',
        'exercises': <dynamic>[
          <String, dynamic>{
            'exercise': 'Bench Press',
            'muscle_group': 'chest',
            'note': 'not',
            'sets': <dynamic>[
              <String, dynamic>{'weight_kg': 60.0, 'reps': 10},
              <String, dynamic>{'weight_kg': 62.5, 'reps': 8},
            ],
          },
        ],
      },
    ],
  };
}

String _encodeMap(Map<String, dynamic> map) => jsonEncode(map);

void _expectCorrupt(String source, String path) {
  expect(
    () => decodeBackupJson(source),
    throwsA(
      isA<BackupFormatException>().having(
        (e) => e.message,
        'message',
        'Yedek dosyası bozuk: $path',
      ),
    ),
  );
}

void main() {
  group('encodeBackupJson / decodeBackupJson round trip', () {
    test('tüm alanlar aynı kalır', () {
      final original = _sampleData();

      final decoded = decodeBackupJson(encodeBackupJson(original));

      expect(decoded.formatVersion, BackupData.currentFormatVersion);
      expect(decoded.exportedAt, original.exportedAt);
      expect(decoded.exercises.length, 2);
      expect(decoded.exercises[0].name, 'Bench Press');
      expect(decoded.exercises[0].muscleGroup, MuscleGroup.chest);
      expect(decoded.exercises[1].name, 'Şınav');
      expect(decoded.exercises[1].muscleGroup, MuscleGroup.arms);

      expect(decoded.workouts.length, 2);
      final first = decoded.workouts[0];
      expect(first.startedAt, DateTime(2026, 10, 17, 18, 30));
      expect(first.title, 'Üst vücut');
      expect(first.exercises.length, 2);

      final bench = first.exercises[0];
      expect(bench.exerciseName, 'Bench Press');
      expect(bench.muscleGroup, MuscleGroup.chest);
      expect(bench.note, '2. sette formum bozuldu');
      expect(bench.sets.length, 2);
      expect(bench.sets[0].weightKg, 60.0);
      expect(bench.sets[0].reps, 10);
      expect(bench.sets[1].weightKg, 62.5);
      expect(bench.sets[1].reps, 8);

      final pushUps = first.exercises[1];
      expect(pushUps.exerciseName, 'Şınav');
      expect(pushUps.note, isNull);
      expect(pushUps.sets, isEmpty);

      final second = decoded.workouts[1];
      expect(second.startedAt, DateTime(2026, 10, 18, 7, 5));
      expect(second.title, isNull);
      expect(second.exercises, isEmpty);
    });

    test('UTC tarih ve null olmayan başlık/not korunur', () {
      final original = BackupData(
        exportedAt: DateTime.utc(2026, 1, 2, 3, 4, 5, 6),
        exercises: const [],
        workouts: [
          BackupWorkout(
            startedAt: DateTime.utc(2026, 1, 2, 3, 4),
            title: 'Bacak',
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Squat',
                muscleGroup: MuscleGroup.legs,
                note: 'satır1\nsatır2 "tırnak"',
                sets: [BackupSet(weightKg: 100, reps: 5)],
              ),
            ],
          ),
        ],
      );

      final decoded = decodeBackupJson(encodeBackupJson(original));

      expect(decoded.exportedAt, original.exportedAt);
      expect(decoded.exportedAt.isUtc, isTrue);
      expect(decoded.workouts.single.startedAt, original.workouts.single.startedAt);
      expect(decoded.workouts.single.title, 'Bacak');
      expect(
        decoded.workouts.single.exercises.single.note,
        'satır1\nsatır2 "tırnak"',
      );
    });

    test('çıktı girintili ve belirtilen alan adlarını içerir', () {
      final text = encodeBackupJson(_sampleData());
      final map = jsonDecode(text) as Map<String, dynamic>;

      expect(text, contains('\n  "format": "exercise-tracking-app-backup"'));
      expect(map['format'], 'exercise-tracking-app-backup');
      expect(map['format_version'], 1);
      expect(map['exported_at'], '2026-10-18T10:00:00.000');
      expect(map['exercises'], [
        {'name': 'Bench Press', 'muscle_group': 'chest'},
        {'name': 'Şınav', 'muscle_group': 'arms'},
      ]);
      final workout = (map['workouts'] as List).first as Map<String, dynamic>;
      expect(workout['started_at'], '2026-10-17T18:30:00.000');
      expect(workout['title'], 'Üst vücut');
      final exercise = (workout['exercises'] as List).first as Map<String, dynamic>;
      expect(exercise['exercise'], 'Bench Press');
      expect(exercise['muscle_group'], 'chest');
      expect(exercise['note'], '2. sette formum bozuldu');
      expect(exercise['sets'], [
        {'weight_kg': 60.0, 'reps': 10},
        {'weight_kg': 62.5, 'reps': 8},
      ]);
    });

    test('null başlık ve not null olarak yazılır', () {
      final map = jsonDecode(encodeBackupJson(_sampleData())) as Map<String, dynamic>;
      final workout = (map['workouts'] as List)[1] as Map<String, dynamic>;
      expect(workout.containsKey('title'), isTrue);
      expect(workout['title'], isNull);
    });
  });

  group('decodeBackupJson okuma kuralları', () {
    test('weight_kg tam sayı olarak yazılmışsa da okunur', () {
      final map = _validMap();
      ((((map['workouts'] as List).first as Map)['exercises'] as List).first
              as Map)['sets'] = [
        {'weight_kg': 60, 'reps': 10},
      ];

      final decoded = decodeBackupJson(_encodeMap(map));

      final set = decoded.workouts.single.exercises.single.sets.single;
      expect(set.weightKg, 60.0);
      expect(set.weightKg, isA<double>());
    });

    test('reps 10.0 biçiminde de okunur', () {
      final map = _validMap();
      ((((map['workouts'] as List).first as Map)['exercises'] as List).first
              as Map)['sets'] = [
        {'weight_kg': 60.0, 'reps': 10.0},
      ];

      final decoded = decodeBackupJson(_encodeMap(map));

      expect(decoded.workouts.single.exercises.single.sets.single.reps, 10);
    });

    test('bilinmeyen kas grubu other olur', () {
      final map = _validMap();
      ((map['exercises'] as List).first as Map)['muscle_group'] = 'tuhaf';
      final workoutExercise =
          (((map['workouts'] as List).first as Map)['exercises'] as List).first
              as Map;
      workoutExercise['muscle_group'] = 'yok_boyle_bir_grup';

      final decoded = decodeBackupJson(_encodeMap(map));

      expect(decoded.exercises.single.muscleGroup, MuscleGroup.other);
      expect(
        decoded.workouts.single.exercises.single.muscleGroup,
        MuscleGroup.other,
      );
    });

    test('format_version eski/eşit ise kabul edilir', () {
      final map = _validMap();
      map['format_version'] = 1;

      final decoded = decodeBackupJson(_encodeMap(map));

      expect(decoded.formatVersion, 1);
    });

    test('title ve note alanı hiç yoksa null olur', () {
      final map = _validMap();
      final workout = (map['workouts'] as List).first as Map<String, dynamic>;
      workout.remove('title');
      final exercise = (workout['exercises'] as List).first as Map<String, dynamic>;
      exercise.remove('note');

      final decoded = decodeBackupJson(_encodeMap(map));

      expect(decoded.workouts.single.title, isNull);
      expect(decoded.workouts.single.exercises.single.note, isNull);
    });

    test('boş listeler kabul edilir', () {
      final map = {
        'format': 'exercise-tracking-app-backup',
        'format_version': 1,
        'exported_at': '2026-10-18T10:00:00.000',
        'exercises': <Object>[],
        'workouts': <Object>[],
      };

      final decoded = decodeBackupJson(_encodeMap(map));

      expect(decoded.exercises, isEmpty);
      expect(decoded.workouts, isEmpty);
    });
  });

  group('decodeBackupJson hataları', () {
    test('JSON olmayan metin → okunamadı mesajı', () {
      expect(
        () => decodeBackupJson('bu bir json değil {'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'Dosya okunamadı: geçerli bir yedek dosyası değil.',
          ),
        ),
      );
    });

    test('boş metin → okunamadı mesajı', () {
      expect(
        () => decodeBackupJson(''),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'Dosya okunamadı: geçerli bir yedek dosyası değil.',
          ),
        ),
      );
    });

    test('format alanı yoksa yedek değil mesajı', () {
      final map = _validMap()..remove('format');

      expect(
        () => decodeBackupJson(_encodeMap(map)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'Bu dosya bu uygulamanın yedek dosyası değil.',
          ),
        ),
      );
    });

    test('format alanı farklıysa yedek değil mesajı', () {
      final map = _validMap()..['format'] = 'baska-uygulama';

      expect(
        () => decodeBackupJson(_encodeMap(map)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'Bu dosya bu uygulamanın yedek dosyası değil.',
          ),
        ),
      );
    });

    test('kök nesne değilse yedek değil mesajı', () {
      expect(
        () => decodeBackupJson('[1, 2, 3]'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'Bu dosya bu uygulamanın yedek dosyası değil.',
          ),
        ),
      );
    });

    test('format_version daha yeniyse güncelleme mesajı', () {
      final map = _validMap()..['format_version'] = 2;

      expect(
        () => decodeBackupJson(_encodeMap(map)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Uygulamayı güncelleyin.',
          ),
        ),
      );
    });

    test('format_version yoksa bozuk', () {
      final map = _validMap()..remove('format_version');
      _expectCorrupt(_encodeMap(map), 'format_version');
    });

    test('format_version metinse bozuk', () {
      final map = _validMap()..['format_version'] = '1';
      _expectCorrupt(_encodeMap(map), 'format_version');
    });

    test('exported_at okunamıyorsa bozuk', () {
      final map = _validMap()..['exported_at'] = 'dün akşam';
      _expectCorrupt(_encodeMap(map), 'exported_at');
    });

    test('exercises liste değilse bozuk', () {
      final map = _validMap()..['exercises'] = 'yok';
      _expectCorrupt(_encodeMap(map), 'exercises');
    });

    test('workouts yoksa bozuk', () {
      final map = _validMap()..remove('workouts');
      _expectCorrupt(_encodeMap(map), 'workouts');
    });

    test('katalog hareketinin adı yoksa bozuk', () {
      final map = _validMap();
      ((map['exercises'] as List).first as Map).remove('name');
      _expectCorrupt(_encodeMap(map), 'exercises[0].name');
    });

    test('kas grubu metin değilse bozuk', () {
      final map = _validMap();
      ((map['exercises'] as List).first as Map)['muscle_group'] = 3;
      _expectCorrupt(_encodeMap(map), 'exercises[0].muscle_group');
    });

    test('antrenman tarihi okunamıyorsa bozuk', () {
      final map = _validMap();
      ((map['workouts'] as List).first as Map)['started_at'] = 'geçersiz';
      _expectCorrupt(_encodeMap(map), 'workouts[0].started_at');
    });

    test('antrenman başlığı metin değilse bozuk', () {
      final map = _validMap();
      ((map['workouts'] as List).first as Map)['title'] = 42;
      _expectCorrupt(_encodeMap(map), 'workouts[0].title');
    });

    test('antrenman elemanı nesne değilse bozuk', () {
      final map = _validMap();
      (map['workouts'] as List)[0] = 'yanlış';
      _expectCorrupt(_encodeMap(map), 'workouts[0]');
    });

    test('hareket adı eksikse bozuk', () {
      final map = _validMap();
      final exercise = ((((map['workouts'] as List).first as Map)['exercises']
              as List)
          .first as Map);
      exercise.remove('exercise');
      _expectCorrupt(_encodeMap(map), 'workouts[0].exercises[0].exercise');
    });

    test('sets liste değilse bozuk', () {
      final map = _validMap();
      final exercise = ((((map['workouts'] as List).first as Map)['exercises']
              as List)
          .first as Map);
      exercise['sets'] = {'weight_kg': 60, 'reps': 10};
      _expectCorrupt(_encodeMap(map), 'workouts[0].exercises[0].sets');
    });

    test('reps metinse bozuk ve yol doğru gösterilir', () {
      final map = _validMap();
      final sets = (((((map['workouts'] as List).first as Map)['exercises']
                  as List)
              .first as Map)['sets'] as List);
      (sets[1] as Map)['reps'] = '8';
      _expectCorrupt(
        _encodeMap(map),
        'workouts[0].exercises[0].sets[1].reps',
      );
    });

    test('weight_kg eksikse bozuk', () {
      final map = _validMap();
      final sets = (((((map['workouts'] as List).first as Map)['exercises']
                  as List)
              .first as Map)['sets'] as List);
      (sets[0] as Map).remove('weight_kg');
      _expectCorrupt(
        _encodeMap(map),
        'workouts[0].exercises[0].sets[0].weight_kg',
      );
    });

    test('reps ondalıklı sayıysa bozuk', () {
      final map = _validMap();
      final sets = (((((map['workouts'] as List).first as Map)['exercises']
                  as List)
              .first as Map)['sets'] as List);
      (sets[0] as Map)['reps'] = 8.5;
      _expectCorrupt(
        _encodeMap(map),
        'workouts[0].exercises[0].sets[0].reps',
      );
    });

    test('değer kontrolü yapılmaz: reps 0 ve negatif ağırlık kabul edilir', () {
      final map = _validMap();
      final sets = (((((map['workouts'] as List).first as Map)['exercises']
                  as List)
              .first as Map)['sets'] as List);
      (sets[0] as Map)['reps'] = 0;
      (sets[1] as Map)['weight_kg'] = -5;

      final decoded = decodeBackupJson(_encodeMap(map));

      expect(decoded.workouts.single.exercises.single.sets[0].reps, 0);
      expect(decoded.workouts.single.exercises.single.sets[1].weightKg, -5.0);
    });
  });
}
