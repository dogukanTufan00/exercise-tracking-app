// MeasurementRepository'nin her uygulamasının (SQLite, Fake) geçmesi gereken ortak testler.
// Bu dosya doğrudan çalışmaz (adı _test.dart ile bitmez); her uygulamanın kendi test dosyası
// [runMeasurementRepositoryContractTests]'i çağırır.
import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/measurement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [createRepository] her testten önce çağrılır ve **boş** (yalnızca yerleşik türleri olan) bir
/// repository döndürmelidir. [disposeRepository] verilirse her testten sonra çağrılır.
void runMeasurementRepositoryContractTests(
  String implementationName,
  Future<MeasurementRepository> Function() createRepository, {
  Future<void> Function(MeasurementRepository repository)? disposeRepository,
}) {
  group('$implementationName MeasurementRepository sözleşmesi', () {
    late MeasurementRepository repo;

    setUp(() async {
      repo = await createRepository();
    });

    tearDown(() async {
      await disposeRepository?.call(repo);
    });

    Future<MeasurementType> customType([String name = 'Ön kol', String unit = 'cm']) {
      return repo.createMeasurementType(name, unit);
    }

    Future<MeasurementType> builtinType(String name) async {
      final types = await repo.getMeasurementTypes();
      return types.singleWhere((t) => t.name == name);
    }

    group('türler', () {
      test('yerleşik 10 tür doğru sırada ve yerleşik olarak gelir', () async {
        final types = await repo.getMeasurementTypes();

        expect(types.map((t) => t.name).toList(), [
          'Kilo',
          'Boy',
          'Sağ kol',
          'Sol kol',
          'Sağ bacak',
          'Sol bacak',
          'Bel',
          'Göğüs',
          'Kalça',
          'Boyun',
        ]);
        expect(types.map((t) => t.position).toList(), List.generate(10, (i) => i));
        expect(types.map((t) => t.builtinKey).toList(), [
          'weight',
          'height',
          'right_arm',
          'left_arm',
          'right_leg',
          'left_leg',
          'waist',
          'chest',
          'hips',
          'neck',
        ]);
        expect(types.every((t) => t.isBuiltin), isTrue);
        expect(types.first.unit, 'kg');
        expect(types[1].unit, 'cm');
      });

      test('createMeasurementType özel türü listenin sonuna ekler ve kırpar', () async {
        final type = await customType('  Ön kol  ', ' cm ');

        expect(type.name, 'Ön kol');
        expect(type.unit, 'cm');
        expect(type.position, 10);
        expect(type.isBuiltin, isFalse);

        final types = await repo.getMeasurementTypes();
        expect(types.last, type);
      });

      test('createMeasurementType boş ad ya da birimde ArgumentError fırlatır', () async {
        await expectLater(customType('   '), throwsArgumentError);
        await expectLater(customType('Ön kol', '  '), throwsArgumentError);
        expect(await repo.getMeasurementTypes(), hasLength(10));
      });

      test('aynı ad (büyük/küçük ve Türkçe harf farkı dahil) DuplicateMeasurementTypeException fırlatır',
          () async {
        await expectLater(
          repo.createMeasurementType('sağ KOL', 'cm'),
          throwsA(isA<DuplicateMeasurementTypeException>()),
        );
        await expectLater(
          repo.createMeasurementType('SAG KOL', 'cm'),
          throwsA(isA<DuplicateMeasurementTypeException>()),
        );
      });

      test('yerleşik tür silinemez (ArgumentError)', () async {
        final kilo = await builtinType('Kilo');
        await expectLater(repo.deleteMeasurementType(kilo.id), throwsArgumentError);
        expect(await repo.getMeasurementTypes(), hasLength(10));
      });

      test('özel türü silmek ölçümlerini de siler', () async {
        final type = await customType();
        await repo.addMeasurement(type.id, 30, measuredAt: DateTime(2026, 10, 1));
        await repo.addMeasurement(type.id, 31, measuredAt: DateTime(2026, 10, 8));

        await repo.deleteMeasurementType(type.id);

        final types = await repo.getMeasurementTypes();
        expect(types.any((t) => t.id == type.id), isFalse);
        expect(await repo.getMeasurements(type.id), isEmpty);
        // Silinen tür dışa aktarımda da yok; ölçümleri de kalmadı.
        final exported = await repo.exportMeasurements();
        expect(exported.types, isEmpty);
        expect(exported.measurements, isEmpty);
      });
    });

    group('ölçümler', () {
      test('ölçüm ekleme, güncelleme ve silme', () async {
        final kilo = await builtinType('Kilo');
        final added = await repo.addMeasurement(
          kilo.id,
          82.5,
          measuredAt: DateTime(2026, 10, 1, 7, 30),
        );
        expect(added.typeId, kilo.id);
        expect(added.value, 82.5);

        await repo.updateMeasurement(
          added.copyWith(measuredAt: DateTime(2026, 10, 2, 7, 0), value: 81.0),
        );
        final updated = (await repo.getMeasurements(kilo.id)).single;
        expect(updated.id, added.id);
        expect(updated.measuredAt, DateTime(2026, 10, 2, 7, 0));
        expect(updated.value, 81.0);

        await repo.deleteMeasurement(added.id);
        expect(await repo.getMeasurements(kilo.id), isEmpty);
      });

      test('measuredAt verilmezse şu anki zaman kullanılır', () async {
        final kilo = await builtinType('Kilo');
        final before = DateTime.now();
        final added = await repo.addMeasurement(kilo.id, 80);
        final after = DateTime.now();

        expect(added.measuredAt.isBefore(before), isFalse);
        expect(added.measuredAt.isAfter(after), isFalse);
      });

      test('değer 0 ya da negatifse ArgumentError fırlatır (ekleme ve güncelleme)', () async {
        final kilo = await builtinType('Kilo');
        await expectLater(repo.addMeasurement(kilo.id, 0), throwsArgumentError);
        await expectLater(repo.addMeasurement(kilo.id, -1), throwsArgumentError);

        final added = await repo.addMeasurement(kilo.id, 80, measuredAt: DateTime(2026, 10, 1));
        await expectLater(
          repo.updateMeasurement(added.copyWith(value: 0)),
          throwsArgumentError,
        );
        expect((await repo.getMeasurements(kilo.id)).single.value, 80);
      });

      test('olmayan tür için ekleme ArgumentError fırlatır', () async {
        await expectLater(repo.addMeasurement(999, 10), throwsArgumentError);
      });

      test('getMeasurements en eskiden en yeniye sıralar', () async {
        final kilo = await builtinType('Kilo');
        await repo.addMeasurement(kilo.id, 80, measuredAt: DateTime(2026, 10, 15));
        await repo.addMeasurement(kilo.id, 78, measuredAt: DateTime(2026, 10, 1));
        await repo.addMeasurement(kilo.id, 79, measuredAt: DateTime(2026, 10, 8));

        final measurements = await repo.getMeasurements(kilo.id);
        expect(measurements.map((m) => m.value).toList(), [78, 79, 80]);
      });

      test('getMeasurementSummaries ölçümsüz türü latest null olarak verir', () async {
        final summaries = await repo.getMeasurementSummaries();

        expect(summaries, hasLength(10));
        expect(summaries.first.type.name, 'Kilo');
        expect(summaries.first.latest, isNull);
        expect(summaries.first.previous, isNull);
        expect(summaries.first.change, isNull);
      });

      test('getMeasurementSummaries son iki ölçümü ve farkı verir', () async {
        final kilo = await builtinType('Kilo');
        await repo.addMeasurement(kilo.id, 80, measuredAt: DateTime(2026, 10, 1));
        await repo.addMeasurement(kilo.id, 82, measuredAt: DateTime(2026, 10, 10));
        await repo.addMeasurement(kilo.id, 90, measuredAt: DateTime(2026, 9, 1));

        final summary = (await repo.getMeasurementSummaries())
            .firstWhere((s) => s.type.id == kilo.id);

        expect(summary.latest?.value, 82);
        expect(summary.latest?.measuredAt, DateTime(2026, 10, 10));
        expect(summary.previous?.value, 80);
        expect(summary.change, 2.0);
      });
    });

    group('dışa ve içe aktarma', () {
      test('export yalnız özel türleri ve tüm ölçümleri sıralı verir', () async {
        final kilo = await builtinType('Kilo');
        final custom = await customType('Ön kol', 'cm');
        await repo.addMeasurement(custom.id, 27, measuredAt: DateTime(2026, 10, 9));
        await repo.addMeasurement(kilo.id, 80, measuredAt: DateTime(2026, 10, 10));
        await repo.addMeasurement(custom.id, 26, measuredAt: DateTime(2026, 10, 1));

        final exported = await repo.exportMeasurements();

        expect(exported.types.map((t) => t.name).toList(), ['Ön kol']);
        expect(exported.types.single.unit, 'cm');
        expect(exported.measurements.map((m) => m.typeName).toList(), [
          'Ön kol',
          'Ön kol',
          'Kilo',
        ]);
        expect(exported.measurements.map((m) => m.value).toList(), [26, 27, 80]);
        expect(exported.measurements.first.unit, 'cm');
        expect(exported.measurements.last.unit, 'kg');
      });

      test('import türleri adla eşleştirir (Türkçe harf farkı dahil) ve bilinmeyen türü oluşturur',
          () async {
        final added = await repo.importMeasurements(
          types: const [BackupMeasurementType(name: 'ÖN KOL', unit: 'cm')],
          measurements: [
            BackupMeasurement(
              typeName: 'sol kol',
              unit: 'cm',
              measuredAt: DateTime(2026, 10, 5),
              value: 33,
            ),
            BackupMeasurement(
              typeName: 'Ön kol',
              unit: 'cm',
              measuredAt: DateTime(2026, 10, 5, 9),
              value: 27,
            ),
            BackupMeasurement(
              typeName: 'Bilek',
              unit: 'cm',
              measuredAt: DateTime(2026, 10, 5),
              value: 17,
            ),
          ],
        );

        expect(added, 3);
        final types = await repo.getMeasurementTypes();
        // Yerleşik 10 tür değişmedi; "ÖN KOL" tek bir özel tür olarak eklendi ("Ön kol" ona eşleşti);
        // "Bilek" sona geldi.
        expect(types, hasLength(12));
        expect(types.map((t) => t.name).toList().sublist(10), ['ÖN KOL', 'Bilek']);

        final leftArm = types.firstWhere((t) => t.name == 'Sol kol');
        expect((await repo.getMeasurements(leftArm.id)).single.value, 33);
      });

      test('import aynı türde aynı zamanlı ölçümü atlar; ikinci içe aktarma 0 ekler', () async {
        final backupMeasurements = [
          BackupMeasurement(
            typeName: 'Kilo',
            unit: 'kg',
            measuredAt: DateTime(2026, 10, 1, 7),
            value: 80,
          ),
          BackupMeasurement(
            typeName: 'Kilo',
            unit: 'kg',
            measuredAt: DateTime(2026, 10, 8, 7),
            value: 79,
          ),
        ];

        expect(
          await repo.importMeasurements(types: const [], measurements: backupMeasurements),
          2,
        );
        expect(
          await repo.importMeasurements(types: const [], measurements: backupMeasurements),
          0,
        );

        final kilo = await builtinType('Kilo');
        expect(await repo.getMeasurements(kilo.id), hasLength(2));
      });

      test('geçersiz değerde import hiçbir şey yazmaz ve ArgumentError fırlatır', () async {
        final kilo = await builtinType('Kilo');
        await expectLater(
          repo.importMeasurements(
            types: const [BackupMeasurementType(name: 'Yeni', unit: 'cm')],
            measurements: [
              BackupMeasurement(
                typeName: 'Kilo',
                unit: 'kg',
                measuredAt: DateTime(2026, 10, 1),
                value: 80,
              ),
              BackupMeasurement(
                typeName: 'Yeni',
                unit: 'cm',
                measuredAt: DateTime(2026, 10, 1),
                value: 0,
              ),
            ],
          ),
          throwsArgumentError,
        );

        expect(await repo.getMeasurements(kilo.id), isEmpty);
        expect(await repo.getMeasurementTypes(), hasLength(10));
      });
    });
  });
}
