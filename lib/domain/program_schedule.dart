import '../data/models/models.dart';

// Programın günlük önerisi (karma model, bkz. docs/ARCHITECTURE.md §14). Saf Dart.

/// [today] için önerilen program günü: planlanan günü ([ProgramDay.weekday]) bugünün günü olan
/// ilk gün; yoksa `null`. Öneri yalnızca bir kolaylıktır: kullanıcı programın herhangi bir gününü
/// başlatabilir ve kaçırılan günler hiçbir yerde işaretlenmez.
ProgramDayDetail? suggestedDay(ProgramDetail program, DateTime today) {
  for (final day in program.days) {
    if (day.day.weekday == today.weekday) return day;
  }
  return null;
}
