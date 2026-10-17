import 'package:exercise_tracking_app/data/utils/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeForSearch', () {
    test('Türkçe harfleri ve büyük/küçük farkını sadeleştirir', () {
      expect(normalizeForSearch('Şınav'), 'sinav');
      expect(normalizeForSearch('ŞINAV'), 'sinav');
      expect(normalizeForSearch('şınav'), 'sinav');
      expect(normalizeForSearch('sinav'), 'sinav');
    });

    test('noktalı büyük İ ve noktasız büyük I aynı sonucu verir', () {
      expect(normalizeForSearch('İncline Press'), 'incline press');
      expect(normalizeForSearch('INCLINE PRESS'), 'incline press');
    });

    test('ğ, ü, ö, ç harflerini sadeleştirir', () {
      expect(normalizeForSearch('Göğüs Çekişi Ölü'), 'gogus cekisi olu');
    });

    test('boşlukları kırpar ve aradaki çoklu boşlukları teke indirir', () {
      expect(normalizeForSearch('  Bench    Press  '), 'bench press');
    });

    test('özel karakterlere dokunmaz', () {
      expect(normalizeForSearch('Bent-over row (90%)'), 'bent-over row (90%)');
    });
  });
}
