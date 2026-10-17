import 'package:exercise_tracking_app/ui/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  group('formatWeight', () {
    test('tam sayıyı ondalıksız yazar', () {
      expect(formatWeight(60), '60');
    });

    test('ondalık kısmı virgülle yazar', () {
      expect(formatWeight(62.5), '62,5');
    });

    test('iki basamağa kadar yazar', () {
      expect(formatWeight(62.25), '62,25');
    });

    test('sıfırı "0" olarak yazar', () {
      expect(formatWeight(0), '0');
    });
  });

  group('formatSet', () {
    test('ağırlık ve tekrarı birlikte yazar', () {
      expect(formatSet(60, 10), '60 kg × 10');
      expect(formatSet(62.5, 8), '62,5 kg × 8');
    });
  });

  group('formatWorkoutDate', () {
    test('tarih ve saati Türkçe ay adıyla yazar', () {
      expect(
        formatWorkoutDate(DateTime(2026, 10, 17, 18, 30)),
        '17 Ekim 2026 · 18:30',
      );
    });
  });

  group('parseDecimal', () {
    test('virgüllü sayıyı okur', () {
      expect(parseDecimal('62,5'), 62.5);
    });

    test('noktalı sayıyı okur', () {
      expect(parseDecimal('62.5'), 62.5);
    });

    test('boşlukları kırpar', () {
      expect(parseDecimal(' 10 '), 10);
    });

    test('geçersiz girdide null döner', () {
      expect(parseDecimal('abc'), isNull);
    });

    test('boş girdide null döner', () {
      expect(parseDecimal(''), isNull);
    });
  });
}
