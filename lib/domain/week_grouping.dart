import '../data/models/models.dart';

/// [date]'in haftasının Pazartesi günü, saat 00:00 (yerel).
///
/// Gün ekleyerek değil, gün sayısını çıkararak hesaplanır: yaz saati geçişlerinde kayma olmaz.
DateTime startOfWeek(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

/// Bir haftanın antrenmanları.
class WeekGroup {
  const WeekGroup({required this.weekStart, required this.workouts});

  /// Haftanın Pazartesi günü, saat 00:00.
  final DateTime weekStart;

  /// Girdi sırası korunur (en yeni üstte).
  final List<WorkoutSummary> workouts;

  /// Haftadaki tüm antrenmanların set sayısı toplamı.
  int get setCount {
    return workouts.fold(0, (total, summary) => total + summary.setCount);
  }
}

/// [workouts] en yeniden en eskiye sıralı gelir (repository böyle döndürür); gruplar da en yeni hafta önce.
///
/// Antrenmanı olmayan haftalar için grup oluşturulmaz.
List<WeekGroup> groupByWeek(List<WorkoutSummary> workouts) {
  final groups = <WeekGroup>[];
  final grouped = <List<WorkoutSummary>>[];

  for (final summary in workouts) {
    final weekStart = startOfWeek(summary.workout.startedAt);
    if (groups.isEmpty || groups.last.weekStart != weekStart) {
      groups.add(WeekGroup(weekStart: weekStart, workouts: const []));
      grouped.add([]);
    }
    grouped.last.add(summary);
  }

  return [
    for (var i = 0; i < groups.length; i++)
      WeekGroup(weekStart: groups[i].weekStart, workouts: grouped[i]),
  ];
}
