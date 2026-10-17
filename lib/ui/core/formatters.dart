import 'package:intl/intl.dart';

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
