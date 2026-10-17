import '../models/backup_data.dart';

/// Yedek verisini Excel'de açılabilir CSV metnine çevirir.
///
/// UTF-8 BOM ile başlar; satırlar `\r\n` ile ayrılır. Her set bir satırdır.
/// Seti olmayan hareket ve hareketi olmayan antrenman da birer satır olarak yazılır.
String exportBackupCsv(BackupData data) {
  final buffer = StringBuffer('﻿');
  _writeRow(buffer, const [
    'date',
    'time',
    'workout_title',
    'exercise',
    'muscle_group',
    'set_number',
    'weight_kg',
    'reps',
    'note',
  ]);

  for (final workout in data.workouts) {
    final date = _formatDate(workout.startedAt);
    final time = _formatTime(workout.startedAt);
    final title = workout.title ?? '';

    if (workout.exercises.isEmpty) {
      _writeRow(buffer, [date, time, title, '', '', '', '', '', '']);
      continue;
    }

    for (final exercise in workout.exercises) {
      final note = exercise.note ?? '';
      final exerciseFields = [
        exercise.exerciseName,
        exercise.muscleGroup.label,
      ];

      if (exercise.sets.isEmpty) {
        _writeRow(buffer, [
          date,
          time,
          title,
          ...exerciseFields,
          '',
          '',
          '',
          note,
        ]);
        continue;
      }

      for (var i = 0; i < exercise.sets.length; i++) {
        final set = exercise.sets[i];
        _writeRow(buffer, [
          date,
          time,
          title,
          ...exerciseFields,
          '${i + 1}',
          _formatWeight(set.weightKg),
          '${set.reps}',
          note,
        ]);
      }
    }
  }

  return buffer.toString();
}

void _writeRow(StringBuffer buffer, List<String> fields) {
  buffer
    ..write(fields.map(_escapeField).join(','))
    ..write('\r\n');
}

/// RFC 4180: virgül, tırnak, satır sonu içeren alanlar tırnağa alınır.
String _escapeField(String field) {
  final needsQuotes = field.contains(',') ||
      field.contains('"') ||
      field.contains('\r') ||
      field.contains('\n');
  if (!needsQuotes) return field;
  return '"${field.replaceAll('"', '""')}"';
}

String _formatDate(DateTime dateTime) {
  return '${_pad(dateTime.year, 4)}-${_pad(dateTime.month, 2)}-${_pad(dateTime.day, 2)}';
}

String _formatTime(DateTime dateTime) {
  return '${_pad(dateTime.hour, 2)}:${_pad(dateTime.minute, 2)}';
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');

/// Tam sayıysa ondalıksız ("60"), değilse nokta ondalıklı ("62.5") yazar.
String _formatWeight(double weight) {
  if (weight == weight.truncateToDouble()) {
    return weight.toInt().toString();
  }
  return weight.toString();
}
