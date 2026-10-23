import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:exercise_tracking_app/data/backup/backup_json_codec.dart';
import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/settings/backup_view_model.dart';

import '../../fakes/fake_backup_file_service.dart';
import '../../fakes/fake_measurement_repository.dart';
import '../../fakes/fake_program_repository.dart';
import '../../fakes/fake_workout_repository.dart';

BackupProgram _upperLowerProgram() {
  return BackupProgram(
    name: 'Üst/Alt',
    isActive: true,
    days: [
      BackupProgramDay(
        name: 'Göğüs + Sırt',
        weekday: 4,
        exercises: const [
          BackupProgramExercise(
            exerciseName: 'Bench',
            muscleGroup: MuscleGroup.chest,
            sets: 3,
            reps: 10,
            weightKg: 40,
          ),
        ],
      ),
    ],
  );
}

BackupData _backupWith({
  List<BackupWorkout> workouts = const [],
  List<BackupExercise> exercises = const [],
}) {
  return BackupData(
    exportedAt: DateTime(2026, 3, 5),
    exercises: exercises,
    workouts: workouts,
  );
}

final BackupWorkout _benchWorkout = BackupWorkout(
  startedAt: DateTime(2026, 3, 4, 18),
  title: 'Göğüs',
  exercises: [
    BackupWorkoutExercise(
      exerciseName: 'Bench',
      muscleGroup: MuscleGroup.chest,
      sets: const [BackupSet(weightKg: 60, reps: 10)],
    ),
  ],
);

void main() {
  late FakeWorkoutRepository repository;
  late FakeMeasurementRepository measurements;
  late FakeProgramRepository programs;
  late FakeBackupFileService files;
  late BackupViewModel viewModel;

  setUp(() {
    repository = FakeWorkoutRepository();
    measurements = FakeMeasurementRepository();
    programs = FakeProgramRepository(repository);
    files = FakeBackupFileService();
    viewModel = BackupViewModel(
      repository,
      measurements,
      programs,
      files,
      clock: () => DateTime(2026, 3, 5, 9, 30),
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('dışa aktarma', () {
    test('veri yokken hata mesajı verir ve dosya paylaşmaz', () async {
      await viewModel.exportCsv();
      expect(viewModel.errorMessage, 'Henüz kaydedilmiş veri yok.');
      expect(files.sharedFiles, isEmpty);

      viewModel.clearError();
      await viewModel.exportJson();
      expect(viewModel.errorMessage, 'Henüz kaydedilmiş veri yok.');
      expect(files.savedFiles, isEmpty);
    });

    test('CSV: tarihli dosya adı, text/csv ve BOM ile başlayan içerik', () async {
      await repository.importBackup(_backupWith(workouts: [_benchWorkout]));

      await viewModel.exportCsv();

      final shared = files.sharedFiles.single;
      expect(shared.fileName, 'antrenmanlar-2026-03-05.csv');
      expect(shared.mimeType, 'text/csv');
      expect(shared.content, startsWith('﻿'));
      expect(shared.content, contains('Bench'));
      expect(viewModel.message, isNull);
      expect(viewModel.errorMessage, isNull);
    });

    test('JSON: "Farklı kaydet" ile kaydeder; tarihli ad, application/json, geri okunabilir içerik', () async {
      await repository.importBackup(_backupWith(workouts: [_benchWorkout]));

      await viewModel.exportJson();

      expect(files.sharedFiles, isEmpty);
      final saved = files.savedFiles.single;
      expect(saved.fileName, 'antrenman-yedegi-2026-03-05.json');
      expect(saved.mimeType, 'application/json');
      final decoded = decodeBackupJson(saved.content);
      expect(decoded.workouts.single.title, 'Göğüs');
      expect(decoded.exercises.single.name, 'Bench');
      expect(viewModel.message, 'Yedek kaydedildi');
      expect(viewModel.isBusy, isFalse);
    });

    test('JSON: kullanıcı kaydetmekten vazgeçerse mesaj göstermez', () async {
      await repository.importBackup(_backupWith(workouts: [_benchWorkout]));
      files.cancelSave = true;

      await viewModel.exportJson();

      expect(files.savedFiles, isEmpty);
      expect(viewModel.message, isNull);
      expect(viewModel.errorMessage, isNull);
    });
  });

  group('içe aktarma', () {
    test('yeni hareketler sayılarak başarı mesajı gösterir', () async {
      files.pickResult = encodeBackupJson(_backupWith(workouts: [_benchWorkout]));

      await viewModel.importJson();

      expect(
        viewModel.message,
        '1 antrenman eklendi, 0 antrenman atlandı, 1 yeni hareket',
      );
      expect(viewModel.errorMessage, isNull);
      expect((await repository.getWorkoutSummaries()).length, 1);
    });

    test('hareket zaten varsa yeni hareket kısmı mesajda yer almaz', () async {
      await repository.createExercise('Bench', MuscleGroup.chest);
      files.pickResult = encodeBackupJson(_backupWith(workouts: [_benchWorkout]));

      await viewModel.importJson();

      expect(viewModel.message, '1 antrenman eklendi, 0 antrenman atlandı');
    });

    test('aynı başlangıç zamanlı antrenman atlanır ve sayılır', () async {
      await repository.importBackup(_backupWith(workouts: [_benchWorkout]));
      files.pickResult = encodeBackupJson(_backupWith(workouts: [_benchWorkout]));

      await viewModel.importJson();

      expect(viewModel.message, '0 antrenman eklendi, 1 antrenman atlandı');
    });

    test('vazgeçilirse hiçbir şey olmaz', () async {
      files.pickResult = null;

      await viewModel.importJson();

      expect(viewModel.message, isNull);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isBusy, isFalse);
      expect(await repository.getWorkoutSummaries(), isEmpty);
    });

    test('bozuk dosyada biçim hatası mesajı gösterir', () async {
      files.pickResult = '{bozuk';

      await viewModel.importJson();

      expect(
        viewModel.errorMessage,
        'Dosya okunamadı: geçerli bir yedek dosyası değil.',
      );
      expect(viewModel.message, isNull);
    });

    test('geçersiz değerde ArgumentError mesajı verir ve veri değişmez', () async {
      await repository.createWorkout(title: 'Mevcut');
      files.pickResult = encodeBackupJson(
        _backupWith(
          workouts: [
            BackupWorkout(
              startedAt: DateTime(2026, 3, 4, 18),
              exercises: [
                BackupWorkoutExercise(
                  exerciseName: 'Bench',
                  muscleGroup: MuscleGroup.chest,
                  sets: const [BackupSet(weightKg: -1, reps: 10)],
                ),
              ],
            ),
          ],
        ),
      );

      await viewModel.importJson();

      expect(
        viewModel.errorMessage,
        'Yedek dosyasında geçersiz değerler var; hiçbir şey değiştirilmedi.',
      );
      final data = await repository.exportBackup();
      expect(data.workouts.length, 1);
      expect(data.workouts.single.title, 'Mevcut');
      expect(data.exercises, isEmpty);
    });
  });

  group('ölçümler', () {
    Future<void> addWaistMeasurement() async {
      final type = await measurements.createMeasurementType('Ön kol', 'cm');
      await measurements.addMeasurement(
        type.id,
        30,
        measuredAt: DateTime(2026, 3, 1, 8),
      );
    }

    test('JSON yedeğinde ölçüm türleri ve ölçümler bulunur', () async {
      await addWaistMeasurement();

      await viewModel.exportJson();

      final saved = files.savedFiles.single;
      final decoded = decodeBackupJson(saved.content);
      expect(decoded.measurementTypes.single.name, 'Ön kol');
      expect(decoded.measurementTypes.single.unit, 'cm');
      expect(decoded.measurements.single.typeName, 'Ön kol');
      expect(decoded.measurements.single.value, 30);
      expect(decoded.measurements.single.measuredAt, DateTime(2026, 3, 1, 8));
      expect(viewModel.message, 'Yedek kaydedildi');
    });

    test('yalnız ölçüm varken JSON yedeği alınır, CSV "veri yok" der', () async {
      await addWaistMeasurement();

      await viewModel.exportCsv();
      expect(viewModel.errorMessage, 'Henüz kaydedilmiş veri yok.');
      expect(files.sharedFiles, isEmpty);

      viewModel.clearError();
      await viewModel.exportJson();
      expect(viewModel.errorMessage, isNull);
      expect(files.savedFiles.single.fileName, 'antrenman-yedegi-2026-03-05.json');
    });

    test('geri yükleme ölçümleri ekler ve mesajda sayısını gösterir', () async {
      files.pickResult = encodeBackupJson(
        BackupData(
          exportedAt: DateTime(2026, 3, 5),
          exercises: const [],
          workouts: const [],
          measurementTypes: const [
            BackupMeasurementType(name: 'Ön kol', unit: 'cm'),
          ],
          measurements: [
            BackupMeasurement(
              typeName: 'Ön kol',
              unit: 'cm',
              measuredAt: DateTime(2026, 3, 1, 8),
              value: 30,
            ),
            BackupMeasurement(
              typeName: 'Bel',
              unit: 'cm',
              measuredAt: DateTime(2026, 3, 2, 8),
              value: 82.5,
            ),
          ],
        ),
      );

      await viewModel.importJson();

      expect(
        viewModel.message,
        '0 antrenman eklendi, 0 antrenman atlandı, 2 ölçüm',
      );
      expect(viewModel.errorMessage, isNull);
      final types = await measurements.getMeasurementTypes();
      final forearm = types.singleWhere((t) => t.name == 'Ön kol');
      expect((await measurements.getMeasurements(forearm.id)).length, 1);
      final waist = types.singleWhere((t) => t.name == 'Bel');
      expect((await measurements.getMeasurements(waist.id)).single.value, 82.5);
    });

    test('biçim 1 yedeği hâlâ geri yüklenir (ölçüm yok)', () async {
      files.pickResult = jsonEncode({
        'format': 'exercise-tracking-app-backup',
        'format_version': 1,
        'exported_at': '2026-03-05T00:00:00.000',
        'exercises': <dynamic>[],
        'workouts': <dynamic>[
          <String, dynamic>{
            'started_at': '2026-03-04T18:00:00.000',
            'title': 'Göğüs',
            'exercises': <dynamic>[],
          },
        ],
      });

      await viewModel.importJson();

      expect(viewModel.message, '1 antrenman eklendi, 0 antrenman atlandı');
      expect(viewModel.errorMessage, isNull);
      expect((await repository.getWorkoutSummaries()).length, 1);
    });
  });

  group('programlar', () {
    test('JSON yedeğinde programlar bulunur', () async {
      await programs.importPrograms([_upperLowerProgram()]);

      await viewModel.exportJson();

      final decoded = decodeBackupJson(files.savedFiles.single.content);
      expect(decoded.formatVersion, BackupData.currentFormatVersion);
      final program = decoded.programs.single;
      expect(program.name, 'Üst/Alt');
      expect(program.isActive, isTrue);
      expect(program.days.single.weekday, 4);
      expect(program.days.single.exercises.single.exerciseName, 'Bench');
      expect(program.days.single.exercises.single.weightKg, 40);
      expect(viewModel.message, 'Yedek kaydedildi');
    });

    test('yalnız (günü olmayan) program varken JSON yedeği alınır, CSV "veri yok" der', () async {
      // Günü olmayan program hareket oluşturmaz; yalnızca JSON'un "veri yok" kontrolünü test eder.
      await programs.importPrograms([
        const BackupProgram(name: 'Boş', isActive: true, days: []),
      ]);

      await viewModel.exportCsv();
      expect(viewModel.errorMessage, 'Henüz kaydedilmiş veri yok.');
      expect(files.sharedFiles, isEmpty);

      viewModel.clearError();
      await viewModel.exportJson();
      expect(viewModel.errorMessage, isNull);
      final decoded = decodeBackupJson(files.savedFiles.single.content);
      expect(decoded.programs.single.name, 'Boş');
    });

    test('geri yükleme program sayısını mesajda gösterir', () async {
      files.pickResult = encodeBackupJson(
        BackupData(
          exportedAt: DateTime(2026, 3, 5),
          exercises: const [],
          workouts: const [],
          programs: [_upperLowerProgram()],
        ),
      );

      await viewModel.importJson();

      expect(
        viewModel.message,
        '0 antrenman eklendi, 0 antrenman atlandı, 1 program',
      );
      expect(viewModel.errorMessage, isNull);
      final restored = await programs.getPrograms();
      expect(restored.single.name, 'Üst/Alt');
      expect(restored.single.isActive, isTrue);
    });

    test('aynı adlı program atlanır ve mesajda program sayılmaz', () async {
      await programs.importPrograms([_upperLowerProgram()]);
      files.pickResult = encodeBackupJson(
        BackupData(
          exportedAt: DateTime(2026, 3, 5),
          exercises: const [],
          workouts: const [],
          programs: [_upperLowerProgram()],
        ),
      );

      await viewModel.importJson();

      expect(viewModel.message, '0 antrenman eklendi, 0 antrenman atlandı');
      expect((await programs.getPrograms()).length, 1);
    });
  });

  test('işlem sürerken ikinci çağrı yok sayılır', () async {
    final gate = Completer<void>();
    files.gate = gate;
    await repository.importBackup(_backupWith(workouts: [_benchWorkout]));

    final first = viewModel.exportCsv();
    expect(viewModel.isBusy, isTrue);

    await viewModel.exportJson();
    gate.complete();
    await first;

    expect(files.sharedFiles.length, 1);
    expect(files.sharedFiles.single.mimeType, 'text/csv');
    expect(viewModel.isBusy, isFalse);
  });
}
