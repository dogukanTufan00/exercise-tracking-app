import 'package:intl/intl.dart';

import '../../data/models/models.dart';

/// Ağırlığı Türkçe biçimde yazar: 60.0 → "60", 62.5 → "62,5", 62.25 → "62,25".
///
/// En çok 2 ondalık basamak gösterilir; gereksiz sıfırlar atılır.
String formatWeight(double kg) {
  final rounded = double.parse(kg.toStringAsFixed(2));
  if (rounded == 0) return '0';

  final trimmed = rounded
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed.replaceAll('.', ',');
}

/// Bir seti okunur metne çevirir: "60 kg × 10".
String formatSet(double weightKg, int reps) {
  return '${formatWeight(weightKg)} kg × $reps';
}

/// Antrenman tarihini Türkçe biçimde yazar: "17 Ekim 2026 · 18:30".
///
/// `intl` Türkçe biçim verilerini kullanır. Uygulama başlarken bir kez
/// `initializeDateFormatting('tr')` (package:intl/date_symbol_data_local.dart)
/// çağrılmış olmalıdır; aksi halde biçimlendirme hata verir.
String formatWorkoutDate(DateTime dateTime) {
  return DateFormat('d MMMM y · HH:mm', 'tr').format(dateTime);
}

/// Pazartesi [weekStart] ile başlayan haftanın Türkçe aralığı:
/// aynı ay → "13–19 Ekim"; ay değişiyor → "29 Eyl – 5 Eki"; yıl değişiyor → "29 Ara 2025 – 4 Oca 2026".
/// Hafta [now]'ın yılında değilse (ve yıl değişmiyorsa) yıl eklenir: "13–19 Ekim 2025".
String formatWeekRange(DateTime weekStart, {DateTime? now}) {
  final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
  final end = DateTime(start.year, start.month, start.day + 6);
  final currentYear = (now ?? DateTime.now()).year;

  if (start.year != end.year) {
    final from = DateFormat('d MMM y', 'tr').format(start);
    final to = DateFormat('d MMM y', 'tr').format(end);
    return '$from – $to';
  }

  final yearSuffix = start.year == currentYear ? '' : ' ${start.year}';

  if (start.month != end.month) {
    final from = DateFormat('d MMM', 'tr').format(start);
    final to = DateFormat('d MMM', 'tr').format(end);
    return '$from – $to$yearSuffix';
  }

  final month = DateFormat('MMMM', 'tr').format(start);
  return '${start.day}–${end.day} $month$yearSuffix';
}

/// Kullanıcı girdisini sayıya çevirir: "62,5", "62.5" ve " 10 " kabul edilir.
///
/// Girdi boşsa ya da sayıya çevrilemiyorsa `null` döner.
double? parseDecimal(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;

  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Haftanın günleri, Pazartesi (1) … Pazar (7). [formatWeekday] ve kısa hali [formatWeekdayShort] için.
const List<String> _weekdayNames = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

/// Program günü etiketi: 1 → "Pazartesi" … 7 → "Pazar"; `null` → "Esnek gün" (belirli bir güne bağlı değil).
String formatWeekday(int? weekday) {
  if (weekday == null) return 'Esnek gün';
  return _weekdayNames[weekday - 1];
}

/// Kısa gün adı (seçim düğmeleri için): 1 → "Pzt" … 7 → "Paz".
String formatWeekdayShort(int weekday) {
  const short = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  return short[weekday - 1];
}

/// Hedef metni: "3 × 10 · 40 kg"; ağırlık hedefi yoksa "3 × 10".
String formatTarget(ExerciseTarget target) {
  final base = '${target.sets} × ${target.reps}';
  final kg = target.weightKg;
  return kg == null ? base : '$base · ${formatWeight(kg)} kg';
}
