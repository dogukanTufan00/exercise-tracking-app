import 'dart:convert';

import 'package:exercise_tracking_app/data/watch/watch_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// docs/ARCHITECTURE.md §15.4'teki anlık durum örneği.
  const snapshotJson = '''
{
  "protocol": 1,
  "workoutId": 42,
  "title": "Push A",
  "startedAt": "2026-11-21T18:30:00.000",
  "appliedEventIds": ["5b0e-1", "5b0e-2"],
  "exercises": [
    {
      "workoutExerciseId": 101,
      "name": "Bench Press",
      "target": { "sets": 3, "reps": 10, "weightKg": 40.0 },
      "sets": [ { "id": 900, "setNumber": 1, "weightKg": 40.0, "reps": 10 } ],
      "draft": { "weightKg": 40.0, "reps": 10 },
      "previous": [ { "weightKg": 37.5, "reps": 10 } ]
    }
  ]
}
''';

  /// §15.4'teki iki olay örneği.
  const addSetJson = '''
{ "protocol": 1, "eventId": "uuid", "type": "addSet", "workoutId": 42,
  "workoutExerciseId": 101, "weightKg": 40.0, "reps": 10, "createdAt": "2026-11-21T18:41:05.000" }
''';

  const deleteSetJson = '''
{ "protocol": 1, "eventId": "uuid", "type": "deleteSet", "workoutId": 42, "setId": 900,
  "createdAt": "2026-11-21T18:42:00.000" }
''';

  test('anlık durum örneği okunur ve aynen yazılır', () {
    final original = jsonDecode(snapshotJson) as Map<String, Object?>;

    final snapshot = WatchSnapshot.fromJson(original);

    expect(snapshot.workoutId, 42);
    expect(snapshot.title, 'Push A');
    expect(snapshot.startedAt, DateTime(2026, 11, 21, 18, 30));
    expect(snapshot.exercises.single.target, const WatchTarget(sets: 3, reps: 10, weightKg: 40));
    expect(snapshot.toJson(), equals(original));
  });

  test('target null, boş setler ve boş geçen sefer listesi aynen yazılır', () {
    final original = <String, Object?>{
      'protocol': 1,
      'workoutId': 7,
      'title': 'Bacak',
      'startedAt': '2026-11-21T09:00:00.000',
      'appliedEventIds': <String>[],
      'exercises': [
        {
          'workoutExerciseId': 3,
          'name': 'Squat',
          'target': null,
          'sets': <Object?>[],
          'draft': {'weightKg': 20.0, 'reps': 10},
          'previous': <Object?>[],
        },
      ],
    };

    final snapshot = WatchSnapshot.fromJson(original);

    expect(snapshot.exercises.single.target, isNull);
    expect(snapshot.exercises.single.sets, isEmpty);
    expect(snapshot.exercises.single.previous, isEmpty);
    expect(snapshot.toJson(), equals(original));
  });

  test('addSet olayı okunur ve aynen yazılır', () {
    final original = jsonDecode(addSetJson) as Map<String, Object?>;

    final event = WatchEvent.fromJson(original);

    expect(event, isA<AddSetEvent>());
    final add = event as AddSetEvent;
    expect(add.eventId, 'uuid');
    expect(add.workoutExerciseId, 101);
    expect(add.weightKg, 40);
    expect(add.reps, 10);
    expect(event.toJson(), equals(original));
  });

  test('deleteSet olayı okunur ve aynen yazılır', () {
    final original = jsonDecode(deleteSetJson) as Map<String, Object?>;

    final event = WatchEvent.fromJson(original);

    expect(event, isA<DeleteSetEvent>());
    expect((event as DeleteSetEvent).setId, 900);
    expect(event.toJson(), equals(original));
  });

  test('bilinmeyen olay türü FormatException fırlatır', () {
    final json = jsonDecode(addSetJson) as Map<String, Object?>;
    json['type'] = 'fooBar';

    expect(() => WatchEvent.fromJson(json), throwsFormatException);
  });

  test('eksik alan FormatException fırlatır', () {
    final json = jsonDecode(addSetJson) as Map<String, Object?>;
    json.remove('weightKg');

    expect(() => WatchEvent.fromJson(json), throwsFormatException);
  });

  test('gün seçili startWorkout olayı workoutId olmadan okunur ve aynen yazılır', () {
    final original = <String, Object?>{
      'protocol': 1,
      'eventId': 'start-1',
      'type': 'startWorkout',
      'programDayId': 11,
      'createdAt': '2026-11-22T18:30:00.000',
    };

    final event = WatchEvent.fromJson(original);

    expect(event, isA<StartWorkoutEvent>());
    expect((event as StartWorkoutEvent).programDayId, 11);
    expect(event.toJson(), equals(original));
  });

  test('boş startWorkout olayında programDayId null kalır', () {
    final original = <String, Object?>{
      'protocol': 1,
      'eventId': 'start-2',
      'type': 'startWorkout',
      'programDayId': null,
      'createdAt': '2026-11-22T18:30:00.000',
    };

    final event = WatchEvent.fromJson(original) as StartWorkoutEvent;

    expect(event.programDayId, isNull);
    expect(event.toJson(), equals(original));
  });

  test('finishWorkout olayı okunur ve aynen yazılır', () {
    final original = <String, Object?>{
      'protocol': 1,
      'eventId': 'finish-1',
      'type': 'finishWorkout',
      'workoutId': 42,
      'createdAt': '2026-11-22T19:30:00.000',
    };

    final event = WatchEvent.fromJson(original) as FinishWorkoutEvent;

    expect(event.workoutId, 42);
    expect(event.toJson(), equals(original));
  });

  test('program JSON gidiş-dönüş aynen korunur', () {
    final original = <String, Object?>{
      'protocol': 1,
      'programId': 3,
      'name': 'PPL',
      'days': [
        {
          'dayId': 11,
          'name': 'Push A',
          'weekday': 1,
          'exercises': ['Bench Press', 'Incline DB Press'],
        },
        {
          'dayId': 12,
          'name': 'Serbest',
          'weekday': null,
          'exercises': <Object?>[],
        },
      ],
    };

    final program = WatchProgram.fromJson(original);

    expect(program.name, 'PPL');
    expect(program.days.first.exercises, ['Bench Press', 'Incline DB Press']);
    expect(program.days.last.weekday, isNull);
    expect(program.toJson(), equals(original));
  });
}
