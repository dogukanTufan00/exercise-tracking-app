// ProgramRepository'nin her uygulamasının (SQLite, Fake) geçmesi gereken ortak testler.
// Bu dosya doğrudan çalışmaz (adı _test.dart ile bitmez); her uygulamanın kendi test dosyası
// [runProgramRepositoryContractTests]'i çağırır.
import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/program_repository.dart';
import 'package:exercise_tracking_app/data/repositories/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bir uygulamanın iki parçası: program repository'si ve aynı veriyi gören antrenman repository'si.
typedef ProgramContractRepos = ({ProgramRepository programs, WorkoutRepository workouts});

/// [create] her testten önce çağrılır ve **boş** bir çift döndürmelidir (ikisi aynı veriyi görür).
/// [disposeRepository] verilirse her testten sonra (ve dışa/içe aktarma testlerinde ikinci çift için)
/// çağrılır.
void runProgramRepositoryContractTests(
  String implementationName,
  Future<ProgramContractRepos> Function() create, {
  Future<void> Function(ProgramContractRepos repos)? disposeRepository,
}) {
  group('$implementationName ProgramRepository sözleşmesi', () {
    late ProgramContractRepos repos;
    late ProgramRepository repo;
    late WorkoutRepository workouts;

    setUp(() async {
      repos = await create();
      repo = repos.programs;
      workouts = repos.workouts;
    });

    tearDown(() async {
      await disposeRepository?.call(repos);
    });

    Future<Exercise> exercise(String name, [MuscleGroup group = MuscleGroup.chest]) {
      return workouts.createExercise(name, group);
    }

    ExerciseTarget target({int sets = 3, int reps = 10, double? weightKg = 40}) {
      return ExerciseTarget(sets: sets, reps: reps, weightKg: weightKg);
    }

    /// Dışa aktarılan programları karşılaştırılabilir düz bir yapıya çevirir (model eşitliği yok).
    List<Object?> summarize(List<BackupProgram> programs) {
      return [
        for (final p in programs)
          [
            p.name,
            p.isActive,
            [
              for (final d in p.days)
                [
                  d.name,
                  d.weekday,
                  [
                    for (final e in d.exercises)
                      [e.exerciseName, e.muscleGroup, e.sets, e.reps, e.weightKg],
                  ],
                ],
            ],
          ],
      ];
    }

    group('programlar', () {
      test('ilk oluşturulan program etkin olur, sonrakiler olmaz', () async {
        final first = await repo.createProgram('Üst/Alt');
        final second = await repo.createProgram('Full body');

        expect(first.isActive, isTrue);
        expect(second.isActive, isFalse);

        final programs = await repo.getPrograms();
        expect(programs.map((p) => p.name).toList(), ['Üst/Alt', 'Full body']);
        expect(programs.map((p) => p.isActive).toList(), [true, false]);
      });

      test('ad kırpılır; boş ad ArgumentError', () async {
        await expectLater(repo.createProgram('   '), throwsArgumentError);

        final program = await repo.createProgram('  Ağırlık  ');
        expect(program.name, 'Ağırlık');
      });

      test('yeniden adlandırma adı değiştirir, etkinliği korur', () async {
        final program = await repo.createProgram('Eski');
        await repo.renameProgram(program.id, '  Yeni  ');

        final detail = await repo.getProgramDetail(program.id);
        expect(detail!.program.name, 'Yeni');
        expect(detail.program.isActive, isTrue);

        await expectLater(repo.renameProgram(program.id, ' '), throwsArgumentError);
      });

      test('etkin yapmak diğerlerinin etkinliğini kaldırır (en fazla bir etkin)', () async {
        final a = await repo.createProgram('A');
        final b = await repo.createProgram('B');

        await repo.setActiveProgram(b.id);

        final programs = await repo.getPrograms();
        expect({for (final p in programs) p.id: p.isActive}, {a.id: false, b.id: true});
        expect((await repo.getActiveProgramDetail())!.program.id, b.id);
      });

      test('olmayan program etkin yapılırsa hiçbir şey değişmez', () async {
        final a = await repo.createProgram('A');

        await repo.setActiveProgram(9999);

        expect((await repo.getActiveProgramDetail())!.program.id, a.id);
      });

      test('etkin program yokken getActiveProgramDetail null döner', () async {
        expect(await repo.getActiveProgramDetail(), isNull);
        expect(await repo.getProgramDetail(1), isNull);
      });

      test('etkin program silinince etkin program kalmaz', () async {
        final a = await repo.createProgram('A');
        final b = await repo.createProgram('B');

        await repo.deleteProgram(a.id);

        expect(await repo.getActiveProgramDetail(), isNull);
        final programs = await repo.getPrograms();
        expect(programs.map((p) => p.id).toList(), [b.id]);
        expect(programs.single.isActive, isFalse);
      });

      test('silinen program günleri ve hareketleriyle gider; başlatılmış antrenman kalır', () async {
        final program = await repo.createProgram('Program');
        final day = await repo.addDay(program.id, 'Göğüs', weekday: 1);
        final bench = await exercise('Bench Press');
        await repo.addDayExercise(day.id, bench.id, target());
        final workout = await repo.startWorkoutFromDay(
          day.id,
          startedAt: DateTime(2026, 10, 19, 18),
        );

        await repo.deleteProgram(program.id);

        expect(await repo.getProgramDetail(program.id), isNull);
        final detail = await workouts.getWorkoutDetail(workout.id);
        expect(detail, isNotNull);
        expect(detail!.workout.title, 'Göğüs');
        expect(detail.workout.programDayId, isNull);
        expect(detail.exercises.single.exercise.name, 'Bench Press');
        expect(detail.exercises.single.workoutExercise.target, target());
      });
    });

    group('günler', () {
      test('gün eklenir ve sıra 0, 1, 2… olur; ayrıntıda sırasıyla gelir', () async {
        final program = await repo.createProgram('P');
        final a = await repo.addDay(program.id, 'A günü', weekday: 1);
        final b = await repo.addDay(program.id, 'B günü');

        expect(a.position, 0);
        expect(b.position, 1);
        expect(b.weekday, isNull);

        final detail = await repo.getProgramDetail(program.id);
        expect(detail!.days.map((d) => d.day.name).toList(), ['A günü', 'B günü']);
        expect(detail.days.map((d) => d.day.weekday).toList(), [1, null]);
      });

      test('geçersiz weekday, boş ad ve olmayan program ArgumentError', () async {
        final program = await repo.createProgram('P');

        await expectLater(repo.addDay(program.id, 'X', weekday: 0), throwsArgumentError);
        await expectLater(repo.addDay(program.id, 'X', weekday: 8), throwsArgumentError);
        await expectLater(repo.addDay(program.id, ' '), throwsArgumentError);
        await expectLater(repo.addDay(9999, 'X'), throwsArgumentError);
      });

      test('gün güncellenir: ad ve gün değişir, sıra değişmez', () async {
        final program = await repo.createProgram('P');
        await repo.addDay(program.id, 'A');
        final b = await repo.addDay(program.id, 'B', weekday: 2);

        await repo.updateDay(ProgramDay(
          id: b.id,
          programId: program.id,
          name: '  Bacak  ',
          position: 99,
          weekday: 5,
        ));
        var detail = await repo.getProgramDetail(program.id);
        expect(detail!.days[1].day.name, 'Bacak');
        expect(detail.days[1].day.weekday, 5);
        expect(detail.days[1].day.position, 1);

        await repo.updateDay(ProgramDay(
          id: b.id,
          programId: program.id,
          name: 'Bacak',
          position: 1,
          weekday: null,
        ));
        detail = await repo.getProgramDetail(program.id);
        expect(detail!.days[1].day.weekday, isNull);
      });

      test('gün güncellemede geçersiz weekday ArgumentError', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'A');

        await expectLater(
          repo.updateDay(ProgramDay(
            id: day.id,
            programId: program.id,
            name: 'A',
            position: 0,
            weekday: 9,
          )),
          throwsArgumentError,
        );
      });

      test('gün silinince kalanların sırası 0…n-1 olur', () async {
        final program = await repo.createProgram('P');
        final a = await repo.addDay(program.id, 'A');
        await repo.addDay(program.id, 'B');
        await repo.addDay(program.id, 'C');

        await repo.deleteDay(a.id);

        final detail = await repo.getProgramDetail(program.id);
        expect(detail!.days.map((d) => d.day.name).toList(), ['B', 'C']);
        expect(detail.days.map((d) => d.day.position).toList(), [0, 1]);
      });

      test('silinen gün id\'si tekrar kullanılmaz', () async {
        final program = await repo.createProgram('P');
        final a = await repo.addDay(program.id, 'A');
        await repo.deleteDay(a.id);

        final b = await repo.addDay(program.id, 'B');
        expect(b.id, isNot(a.id));
      });

      test('günün silinmesi bağlı antrenmanın gün bağlantısını kaldırır, antrenman kalır', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Sırt');
        final workout = await repo.startWorkoutFromDay(day.id);

        await repo.deleteDay(day.id);

        final detail = await workouts.getWorkoutDetail(workout.id);
        expect(detail!.workout.programDayId, isNull);
        expect(detail.workout.title, 'Sırt');
      });

      test('günler sıralanır; eksik, fazla, yinelenen ya da yabancı id ArgumentError', () async {
        final program = await repo.createProgram('P');
        final a = await repo.addDay(program.id, 'A');
        final b = await repo.addDay(program.id, 'B');
        final other = await repo.createProgram('Diğer');
        final foreign = await repo.addDay(other.id, 'Yabancı');

        await repo.reorderDays(program.id, [b.id, a.id]);
        var detail = await repo.getProgramDetail(program.id);
        expect(detail!.days.map((d) => d.day.name).toList(), ['B', 'A']);
        expect(detail.days.map((d) => d.day.position).toList(), [0, 1]);

        await expectLater(repo.reorderDays(program.id, [a.id]), throwsArgumentError);
        await expectLater(
          repo.reorderDays(program.id, [a.id, b.id, foreign.id]),
          throwsArgumentError,
        );
        await expectLater(repo.reorderDays(program.id, [a.id, a.id]), throwsArgumentError);
      });
    });

    group('gün hareketleri', () {
      test('hareket eklenir, sıra ve hedef doğru', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs');
        final bench = await exercise('Bench Press');
        final fly = await exercise('Dumbbell Fly');

        final first = await repo.addDayExercise(day.id, bench.id, target(weightKg: 60));
        final second = await repo.addDayExercise(day.id, fly.id, target(weightKg: null));

        expect(first.position, 0);
        expect(second.position, 1);
        expect(first.target, target(weightKg: 60));

        final detail = await repo.getProgramDetail(program.id);
        final entries = detail!.days.single.exercises;
        expect(entries.map((e) => e.exercise.name).toList(), ['Bench Press', 'Dumbbell Fly']);
        expect(entries[1].dayExercise.target.weightKg, isNull);
      });

      test('hedef güncellenir; geçersiz hedef ArgumentError', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs');
        final bench = await exercise('Bench Press');
        final entry = await repo.addDayExercise(day.id, bench.id, target());

        await repo.updateDayExerciseTarget(entry.id, target(sets: 5, reps: 5, weightKg: 80));
        final detail = await repo.getProgramDetail(program.id);
        expect(
          detail!.days.single.exercises.single.dayExercise.target,
          target(sets: 5, reps: 5, weightKg: 80),
        );

        await expectLater(
          repo.updateDayExerciseTarget(entry.id, target(sets: 0)),
          throwsArgumentError,
        );
        await expectLater(
          repo.updateDayExerciseTarget(entry.id, target(reps: 0)),
          throwsArgumentError,
        );
        await expectLater(
          repo.updateDayExerciseTarget(entry.id, target(weightKg: -1)),
          throwsArgumentError,
        );
      });

      test('geçersiz hedefle hareket eklenemez', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs');
        final bench = await exercise('Bench Press');

        await expectLater(
          repo.addDayExercise(day.id, bench.id, target(sets: 0)),
          throwsArgumentError,
        );
        await expectLater(
          repo.addDayExercise(day.id, bench.id, target(reps: -2)),
          throwsArgumentError,
        );
        await expectLater(
          repo.addDayExercise(day.id, bench.id, target(weightKg: -5)),
          throwsArgumentError,
        );
      });

      test('olmayan hareket ya da gün ile ekleme ArgumentError', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs');
        final bench = await exercise('Bench Press');

        await expectLater(
          repo.addDayExercise(day.id, 9999, target()),
          throwsArgumentError,
        );
        await expectLater(
          repo.addDayExercise(9999, bench.id, target()),
          throwsArgumentError,
        );
      });

      test('hareket çıkarılınca kalanların sırası yeniden düzenlenir', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs');
        final a = await exercise('A hareket');
        final b = await exercise('B hareket');
        final c = await exercise('C hareket');
        final entryA = await repo.addDayExercise(day.id, a.id, target());
        await repo.addDayExercise(day.id, b.id, target());
        await repo.addDayExercise(day.id, c.id, target());

        await repo.removeDayExercise(entryA.id);

        final detail = await repo.getProgramDetail(program.id);
        final entries = detail!.days.single.exercises;
        expect(entries.map((e) => e.exercise.name).toList(), ['B hareket', 'C hareket']);
        expect(entries.map((e) => e.dayExercise.position).toList(), [0, 1]);
      });

      test('hareketler sıralanır; eksik ya da yabancı id ArgumentError', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs');
        final otherDay = await repo.addDay(program.id, 'Sırt');
        final a = await exercise('A hareket');
        final b = await exercise('B hareket');
        final entryA = await repo.addDayExercise(day.id, a.id, target());
        final entryB = await repo.addDayExercise(day.id, b.id, target());
        final foreign = await repo.addDayExercise(otherDay.id, a.id, target());

        await repo.reorderDayExercises(day.id, [entryB.id, entryA.id]);
        final detail = await repo.getProgramDetail(program.id);
        expect(
          detail!.days.first.exercises.map((e) => e.exercise.name).toList(),
          ['B hareket', 'A hareket'],
        );

        await expectLater(
          repo.reorderDayExercises(day.id, [entryA.id]),
          throwsArgumentError,
        );
        await expectLater(
          repo.reorderDayExercises(day.id, [entryA.id, entryB.id, foreign.id]),
          throwsArgumentError,
        );
      });
    });

    group('antrenman başlatma', () {
      test('gün adı başlık olur, programDayId bağlanır, hareketler hedefiyle sırayla gelir, set yok',
          () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs + Sırt', weekday: 4);
        final bench = await exercise('Bench Press');
        final row = await exercise('Barbell Row', MuscleGroup.back);
        await repo.addDayExercise(day.id, row.id, target(sets: 4, reps: 8, weightKg: null));
        await repo.addDayExercise(day.id, bench.id, target(sets: 3, reps: 10, weightKg: 60));
        final startedAt = DateTime(2026, 10, 22, 18, 30);

        final workout = await repo.startWorkoutFromDay(day.id, startedAt: startedAt);

        expect(workout.title, 'Göğüs + Sırt');
        expect(workout.programDayId, day.id);
        expect(workout.startedAt, startedAt);

        final detail = await workouts.getWorkoutDetail(workout.id);
        expect(detail!.workout, workout);
        expect(detail.exercises.map((e) => e.exercise.name).toList(), [
          'Barbell Row',
          'Bench Press',
        ]);
        expect(detail.exercises.map((e) => e.workoutExercise.position).toList(), [0, 1]);
        expect(detail.exercises[0].workoutExercise.target, target(sets: 4, reps: 8, weightKg: null));
        expect(detail.exercises[1].workoutExercise.target, target(sets: 3, reps: 10, weightKg: 60));
        expect(detail.exercises.every((e) => e.sets.isEmpty), isTrue);
        expect(detail.exercises.every((e) => e.workoutExercise.note == null), isTrue);
      });

      test('program sonradan değişince antrenmanın hedefi değişmez', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Göğüs');
        final bench = await exercise('Bench Press');
        final entry = await repo.addDayExercise(day.id, bench.id, target(sets: 3, reps: 10));
        final workout = await repo.startWorkoutFromDay(day.id);

        await repo.updateDayExerciseTarget(entry.id, target(sets: 6, reps: 2, weightKg: 100));
        await repo.removeDayExercise(entry.id);

        final detail = await workouts.getWorkoutDetail(workout.id);
        expect(detail!.exercises.single.workoutExercise.target, target(sets: 3, reps: 10));
      });

      test('boş günden antrenman hareketsiz başlar', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Boş');

        final workout = await repo.startWorkoutFromDay(day.id);

        final detail = await workouts.getWorkoutDetail(workout.id);
        expect(detail!.exercises, isEmpty);
        expect(detail.workout.title, 'Boş');
      });

      test('startedAt verilmezse şu anki zaman kullanılır', () async {
        final program = await repo.createProgram('P');
        final day = await repo.addDay(program.id, 'Gün');

        final before = DateTime.now();
        final workout = await repo.startWorkoutFromDay(day.id);
        final after = DateTime.now();

        expect(workout.startedAt.isBefore(before), isFalse);
        expect(workout.startedAt.isAfter(after), isFalse);
      });

      test('olmayan gün ArgumentError', () async {
        await expectLater(repo.startWorkoutFromDay(9999), throwsArgumentError);
      });
    });

    group('yedekleme', () {
      test('dışa aktarılan programlar başka bir veritabanına aynen içe aktarılır', () async {
        final program = await repo.createProgram('Üst/Alt');
        final upper = await repo.addDay(program.id, 'Üst', weekday: 1);
        final lower = await repo.addDay(program.id, 'Alt');
        final bench = await exercise('Bench Press');
        final squat = await exercise('Squat', MuscleGroup.legs);
        await repo.addDayExercise(upper.id, bench.id, target(weightKg: 60));
        await repo.addDayExercise(lower.id, squat.id, target(sets: 4, reps: 6, weightKg: null));
        await repo.createProgram('Yedek');

        final exported = await repo.exportPrograms();
        final otherRepos = await create();
        addTearDown(() => disposeRepository?.call(otherRepos));

        final added = await otherRepos.programs.importPrograms(exported);

        expect(added, 2);
        expect(summarize(await otherRepos.programs.exportPrograms()), summarize(exported));
        expect(summarize(exported).first, [
          'Üst/Alt',
          true,
          [
            [
              'Üst',
              1,
              [
                ['Bench Press', MuscleGroup.chest, 3, 10, 60.0],
              ],
            ],
            [
              'Alt',
              null,
              [
                ['Squat', MuscleGroup.legs, 4, 6, null],
              ],
            ],
          ],
        ]);
      });

      test('aynı adlı program atlanır (normalleştirilmiş ad)', () async {
        await repo.createProgram('Üst/Alt');
        final incoming = [
          const BackupProgram(name: 'UST/ALT', isActive: false, days: []),
          const BackupProgram(name: 'Yeni', isActive: false, days: []),
        ];

        final added = await repo.importPrograms(incoming);

        expect(added, 1);
        final names = (await repo.getPrograms()).map((p) => p.name).toList();
        expect(names, ['Üst/Alt', 'Yeni']);
      });

      test('içe aktarmada eksik hareketler kataloğa eklenir', () async {
        final incoming = [
          const BackupProgram(
            name: 'P',
            isActive: false,
            days: [
              BackupProgramDay(name: 'Gün', exercises: [
                BackupProgramExercise(
                  exerciseName: 'Dips',
                  muscleGroup: MuscleGroup.arms,
                  sets: 3,
                  reps: 12,
                ),
              ]),
            ],
          ),
        ];

        await repo.importPrograms(incoming);

        final found = await workouts.searchExercises('dips');
        expect(found.map((e) => e.muscleGroup).toList(), [MuscleGroup.arms]);
      });

      test('etkin işaretli program, şu an etkin program yoksa etkin olur', () async {
        final added = await repo.importPrograms(const [
          BackupProgram(name: 'Yedekten', isActive: true, days: []),
        ]);

        expect(added, 1);
        expect((await repo.getActiveProgramDetail())!.program.name, 'Yedekten');
      });

      test('etkin program varken içe aktarılan etkin program etkin olmaz', () async {
        final current = await repo.createProgram('Mevcut');

        await repo.importPrograms(const [
          BackupProgram(name: 'Yedekten', isActive: true, days: []),
        ]);

        expect((await repo.getActiveProgramDetail())!.program.id, current.id);
        final programs = await repo.getPrograms();
        expect(programs.map((p) => p.isActive).toList(), [true, false]);
      });

      test('geçersiz değer içeren yedekte hiçbir şey yazılmaz', () async {
        final incoming = [
          const BackupProgram(name: 'Geçerli', isActive: false, days: [
            BackupProgramDay(name: 'Gün', exercises: [
              BackupProgramExercise(
                exerciseName: 'Yeni hareket',
                muscleGroup: MuscleGroup.core,
                sets: 3,
                reps: 10,
              ),
            ]),
          ]),
          const BackupProgram(name: 'Geçersiz', isActive: false, days: [
            BackupProgramDay(name: 'Gün', exercises: [
              BackupProgramExercise(
                exerciseName: 'Bozuk',
                muscleGroup: MuscleGroup.other,
                sets: 0,
                reps: 10,
              ),
            ]),
          ]),
        ];

        await expectLater(repo.importPrograms(incoming), throwsArgumentError);

        expect(await repo.getPrograms(), isEmpty);
        expect(await workouts.searchExercises(''), isEmpty);
      });

      test('geçersiz weekday içeren yedekte hiçbir şey yazılmaz', () async {
        await expectLater(
          repo.importPrograms(const [
            BackupProgram(name: 'P', isActive: false, days: [
              BackupProgramDay(name: 'Gün', weekday: 8, exercises: []),
            ]),
          ]),
          throwsArgumentError,
        );
        expect(await repo.getPrograms(), isEmpty);
      });
    });
  });
}
