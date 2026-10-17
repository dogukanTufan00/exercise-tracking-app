import 'package:exercise_tracking_app/data/backup/backup_csv_exporter.dart';
import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const String _bom = '﻿';
const String _header =
    'date,time,workout_title,exercise,muscle_group,set_number,weight_kg,reps,note';

BackupData _dataWith(List<BackupWorkout> workouts) {
  return BackupData(
    exportedAt: DateTime(2026, 10, 18),
    exercises: const [],
    workouts: workouts,
  );
}

BackupWorkout _workout({
  DateTime? startedAt,
  String? title,
  List<BackupWorkoutExercise> exercises = const [],
}) {
  return BackupWorkout(
    startedAt: startedAt ?? DateTime(2026, 10, 17, 18, 30),
    title: title,
    exercises: exercises,
  );
}

/// Çıktıyı BOM'suz ve `\r\n` ayrılmış satırlara böler (son boş satır hariç).
List<String> _lines(String csv) {
  expect(csv.startsWith(_bom), isTrue);
  final body = csv.substring(_bom.length);
  expect(body.endsWith('\r\n'), isTrue);
  final parts = body.split('\r\n');
  return parts.sublist(0, parts.length - 1);
}

void main() {
  group('exportBackupCsv başlık ve biçim', () {
    test('BOM ile başlar ve başlık satırı doğrudur', () {
      final csv = exportBackupCsv(_dataWith(const []));

      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(_lines(csv), [_header]);
    });

    test('satır sonu \\r\\n kullanılır', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Squat',
                muscleGroup: MuscleGroup.legs,
                sets: [BackupSet(weightKg: 100, reps: 5)],
              ),
            ],
          ),
        ]),
      );

      expect(csv.contains('\r\n'), isTrue);
      expect(csv.replaceAll('\r\n', '').contains('\n'), isFalse);
    });

    test('boş veri yalnızca başlık satırı içerir', () {
      final csv = exportBackupCsv(_dataWith(const []));

      expect(csv, '$_bom$_header\r\n');
    });
  });

  group('satır üretimi', () {
    test('her set bir satır olur; tarih, saat, başlık, kas grubu doğru', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            startedAt: DateTime(2026, 10, 17, 18, 30),
            title: 'Üst vücut',
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Bench Press',
                muscleGroup: MuscleGroup.chest,
                note: 'iyi gitti',
                sets: [
                  BackupSet(weightKg: 60, reps: 10),
                  BackupSet(weightKg: 62.5, reps: 8),
                ],
              ),
            ],
          ),
        ]),
      );

      expect(_lines(csv), [
        _header,
        '2026-10-17,18:30,Üst vücut,Bench Press,Göğüs,1,60,10,iyi gitti',
        '2026-10-17,18:30,Üst vücut,Bench Press,Göğüs,2,62.5,8,iyi gitti',
      ]);
    });

    test('antrenman ve hareket sırası data içindeki sırayla korunur', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            startedAt: DateTime(2026, 10, 15, 9),
            title: 'A',
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Hareket1',
                muscleGroup: MuscleGroup.back,
                sets: [BackupSet(weightKg: 1, reps: 1)],
              ),
              BackupWorkoutExercise(
                exerciseName: 'Hareket2',
                muscleGroup: MuscleGroup.core,
                sets: [BackupSet(weightKg: 2, reps: 2)],
              ),
            ],
          ),
          _workout(
            startedAt: DateTime(2026, 10, 16, 9),
            title: 'B',
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Hareket3',
                muscleGroup: MuscleGroup.shoulders,
                sets: [BackupSet(weightKg: 3, reps: 3)],
              ),
            ],
          ),
        ]),
      );

      final lines = _lines(csv);
      expect(lines.length, 4);
      expect(lines[1], startsWith('2026-10-15,09:00,A,Hareket1,Sırt,1,1,1,'));
      expect(lines[2], startsWith('2026-10-15,09:00,A,Hareket2,Karın,1,2,2,'));
      expect(lines[3], startsWith('2026-10-16,09:00,B,Hareket3,Omuz,1,3,3,'));
    });

    test('satır sayısı = set sayısı', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'X',
                muscleGroup: MuscleGroup.arms,
                sets: [
                  BackupSet(weightKg: 1, reps: 1),
                  BackupSet(weightKg: 1, reps: 2),
                  BackupSet(weightKg: 1, reps: 3),
                ],
              ),
              BackupWorkoutExercise(
                exerciseName: 'Y',
                muscleGroup: MuscleGroup.legs,
                sets: [BackupSet(weightKg: 2, reps: 4)],
              ),
            ],
          ),
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Z',
                muscleGroup: MuscleGroup.chest,
                sets: [BackupSet(weightKg: 5, reps: 5)],
              ),
            ],
          ),
        ]),
      );

      // başlık + 3 + 1 + 1 set satırı
      expect(_lines(csv).length, 1 + 5);
    });

    test('setsiz hareket boş set alanlarıyla tek satır olur', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            title: 'Boş',
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Dips',
                muscleGroup: MuscleGroup.arms,
                note: 'bugün yok',
                sets: [],
              ),
            ],
          ),
        ]),
      );

      expect(_lines(csv), [
        _header,
        '2026-10-17,18:30,Boş,Dips,Kol,,,,bugün yok',
      ]);
    });

    test('hareketsiz antrenman boş hareket ve set alanlarıyla tek satır olur', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(startedAt: DateTime(2026, 3, 4, 6, 0), title: 'Yürüyüş'),
        ]),
      );

      expect(_lines(csv), [
        _header,
        '2026-03-04,06:00,Yürüyüş,,,,,,',
      ]);
    });

    test('başlık ve not null ise boş alan olarak yazılır', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Row',
                muscleGroup: MuscleGroup.back,
                sets: [BackupSet(weightKg: 40, reps: 12)],
              ),
            ],
          ),
        ]),
      );

      expect(_lines(csv)[1], '2026-10-17,18:30,,Row,Sırt,1,40,12,');
    });

    test('muscle_group Türkçe etiket olarak yazılır', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: [
              for (final group in MuscleGroup.values)
                BackupWorkoutExercise(
                  exerciseName: group.name,
                  muscleGroup: group,
                  sets: const [BackupSet(weightKg: 1, reps: 1)],
                ),
            ],
          ),
        ]),
      );

      final labels = _lines(csv).skip(1).map((line) => line.split(',')[4]);
      expect(labels, ['Göğüs', 'Sırt', 'Bacak', 'Omuz', 'Kol', 'Karın', 'Diğer']);
    });
  });

  group('sayı ve zaman biçimi', () {
    test('ağırlık tam sayıysa ondalıksız, değilse nokta ondalıklı', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'W',
                muscleGroup: MuscleGroup.legs,
                sets: [
                  BackupSet(weightKg: 60, reps: 1),
                  BackupSet(weightKg: 62.5, reps: 2),
                  BackupSet(weightKg: 0, reps: 3),
                  BackupSet(weightKg: 7.25, reps: 4),
                ],
              ),
            ],
          ),
        ]),
      );

      final lines = _lines(csv).skip(1).toList();
      expect(lines[0].split(',')[6], '60');
      expect(lines[1].split(',')[6], '62.5');
      expect(lines[2].split(',')[6], '0');
      expect(lines[3].split(',')[6], '7.25');
    });

    test('saat sıfır dolgulu yazılır', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(startedAt: DateTime(2026, 1, 5, 9, 5), title: 'T'),
        ]),
      );

      expect(_lines(csv)[1], startsWith('2026-01-05,09:05,T,'));
    });

    test('gece yarısı 00:00 ve 23:59 doğru biçimlenir', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(startedAt: DateTime(2026, 12, 31, 0, 0)),
          _workout(startedAt: DateTime(2026, 12, 31, 23, 59)),
        ]),
      );

      final lines = _lines(csv);
      expect(lines[1], startsWith('2026-12-31,00:00,'));
      expect(lines[2], startsWith('2026-12-31,23:59,'));
    });

    test('tarih tek haneli ay ve gün için sıfır dolgulu yazılır', () {
      final csv = exportBackupCsv(
        _dataWith([_workout(startedAt: DateTime(2026, 2, 3, 4, 5))]),
      );

      expect(_lines(csv)[1], startsWith('2026-02-03,04:05,'));
    });
  });

  group('RFC 4180 kaçışı', () {
    test('virgüllü alan tırnağa alınır', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            title: 'Üst, alt',
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Bench, Incline',
                muscleGroup: MuscleGroup.chest,
                note: 'a, b, c',
                sets: [BackupSet(weightKg: 10, reps: 10)],
              ),
            ],
          ),
        ]),
      );

      expect(
        _lines(csv)[1],
        '2026-10-17,18:30,"Üst, alt","Bench, Incline",Göğüs,1,10,10,"a, b, c"',
      );
    });

    test('çift tırnak içeren alan tırnağa alınır ve tırnaklar iki katına çıkar', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Say "Merhaba"',
                muscleGroup: MuscleGroup.other,
                note: 'söz: "ağır"',
                sets: [BackupSet(weightKg: 1, reps: 1)],
              ),
            ],
          ),
        ]),
      );

      expect(
        _lines(csv)[1],
        '2026-10-17,18:30,,"Say ""Merhaba""",Diğer,1,1,1,"söz: ""ağır"""',
      );
    });

    test('çok satırlı not tırnak içinde olduğu gibi yazılır', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Squat',
                muscleGroup: MuscleGroup.legs,
                note: 'birinci satır\nikinci satır',
                sets: [BackupSet(weightKg: 80, reps: 5)],
              ),
            ],
          ),
        ]),
      );

      expect(
        csv.substring(_bom.length),
        '$_header\r\n'
        '2026-10-17,18:30,,Squat,Bacak,1,80,5,"birinci satır\nikinci satır"\r\n',
      );
    });

    test('\\r içeren not da tırnağa alınır', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Squat',
                muscleGroup: MuscleGroup.legs,
                note: 'a\rb',
                sets: [BackupSet(weightKg: 80, reps: 5)],
              ),
            ],
          ),
        ]),
      );

      expect(
        csv.substring(_bom.length),
        '$_header\r\n'
        '2026-10-17,18:30,,Squat,Bacak,1,80,5,"a\rb"\r\n',
      );
    });
  });

  group('Türkçe karakterler', () {
    test('ğ ü ş ı ö ç İ Ğ Ş Ö Ç Ü korunur', () {
      final csv = exportBackupCsv(
        _dataWith([
          _workout(
            title: 'Gün ışığı İzmir ÇÖĞÜŞ',
            exercises: const [
              BackupWorkoutExercise(
                exerciseName: 'Şınav çeşidi',
                muscleGroup: MuscleGroup.chest,
                note: 'ağrı yok, güzel',
                sets: [BackupSet(weightKg: 0, reps: 20)],
              ),
            ],
          ),
        ]),
      );

      expect(
        _lines(csv)[1],
        '2026-10-17,18:30,Gün ışığı İzmir ÇÖĞÜŞ,Şınav çeşidi,Göğüs,1,0,20,"ağrı yok, güzel"',
      );
    });
  });
}
