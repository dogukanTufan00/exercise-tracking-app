import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/measurement_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/profile/measurement_detail_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_measurement_repository.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  late FakeMeasurementRepository repo;

  setUp(() {
    repo = FakeMeasurementRepository();
  });

  /// Ekranı bir "Aç" düğmesinin arkasına koyar; ekran bir rota olarak açılır (geri dönüş için).
  Future<void> pumpDetail(
    WidgetTester tester,
    MeasurementType type, {
    Size size = const Size(800, 1600),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      Provider<MeasurementRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.darkOrange),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MeasurementDetailScreen(type: type),
                    ),
                  ),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
  }

  Future<MeasurementType> builtinNamed(String name) async {
    final types = await repo.getMeasurementTypes();
    return types.firstWhere((t) => t.name == name);
  }

  testWidgets('ölçüm yoksa boş durum görünür ve grafik yok', (tester) async {
    final weight = await builtinNamed('Kilo');

    await pumpDetail(tester, weight);

    expect(find.text('Henüz ölçüm yok'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('tek ölçümde grafik yerine bilgi metni görünür', (tester) async {
    final weight = await builtinNamed('Kilo');
    await repo.addMeasurement(weight.id, 80, measuredAt: DateTime(2026, 10, 1, 12));

    await pumpDetail(tester, weight);

    expect(find.text('Grafik için en az iki ölçüm gerekli.'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('1 Ekim 2026'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
  });

  testWidgets('iki ölçümde grafik ve liste (en yeni üstte) görünür', (tester) async {
    final weight = await builtinNamed('Kilo');
    await repo.addMeasurement(weight.id, 80, measuredAt: DateTime(2026, 10, 1, 12));
    await repo.addMeasurement(weight.id, 81.5, measuredAt: DateTime(2026, 10, 8, 12));

    await pumpDetail(tester, weight);

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('81,5 kg'), findsOneWidget);
    expect(
      tester.getCenter(find.text('8 Ekim 2026')).dy,
      lessThan(tester.getCenter(find.text('1 Ekim 2026')).dy),
    );
  });

  testWidgets('bir ölçüme dokununca düzenleme diyaloğu açılır ve değer güncellenir',
      (tester) async {
    final weight = await builtinNamed('Kilo');
    await repo.addMeasurement(weight.id, 80, measuredAt: DateTime(2026, 10, 1, 12));
    await repo.addMeasurement(weight.id, 81.5, measuredAt: DateTime(2026, 10, 8, 12));

    await pumpDetail(tester, weight);
    await tester.tap(find.text('8 Ekim 2026'));
    await tester.pumpAndSettle();

    expect(find.text('81,5'), findsOneWidget); // alan önceki değerle dolu
    await tester.enterText(find.byType(TextField), '82');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('82 kg'), findsOneWidget);
    expect(find.text('81,5 kg'), findsNothing);
  });

  testWidgets('kayıt silinir, Geri al ile geri gelir', (tester) async {
    final weight = await builtinNamed('Kilo');
    await repo.addMeasurement(weight.id, 80, measuredAt: DateTime(2026, 10, 1, 12));
    await repo.addMeasurement(weight.id, 81.5, measuredAt: DateTime(2026, 10, 8, 12));

    await pumpDetail(tester, weight);
    await tester.tap(find.byTooltip('Kaydı sil').first);
    await tester.pumpAndSettle();

    expect(find.text('8 Ekim 2026'), findsNothing);
    expect(find.text('Kayıt silindi.'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    expect(find.text('8 Ekim 2026'), findsOneWidget);
    expect(find.text('81,5 kg'), findsOneWidget);
  });

  testWidgets('Ölçüm ekle düğmesi yeni ölçümü listeye ekler', (tester) async {
    final weight = await builtinNamed('Kilo');

    await pumpDetail(tester, weight);
    await tester.tap(find.byTooltip('Ölçüm ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '90');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('90 kg'), findsOneWidget);
    expect(find.text('Henüz ölçüm yok'), findsNothing);
  });

  testWidgets('özel tür Ölçümü sil ile silinir ve ekran kapanır', (tester) async {
    final custom = await repo.createMeasurementType('Ön kol', 'cm');

    await pumpDetail(tester, custom);
    await tester.tap(find.byTooltip('Seçenekler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ölçümü sil'));
    await tester.pumpAndSettle();
    expect(find.text('Bu ölçüm ve tüm kayıtları silinecek.'), findsOneWidget);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(find.byType(MeasurementDetailScreen), findsNothing);
    expect(find.text('Aç'), findsOneWidget);
    final names = (await repo.getMeasurementTypes()).map((t) => t.name);
    expect(names, isNot(contains('Ön kol')));
  });

  testWidgets('yerleşik türde Ölçümü sil seçeneği yok', (tester) async {
    final weight = await builtinNamed('Kilo');

    await pumpDetail(tester, weight);

    expect(find.byTooltip('Seçenekler'), findsNothing);
  });

  testWidgets('360x780 ve yazı 1.3 ile grafik, liste ve diyalog taşmaz', (tester) async {
    final weight = await builtinNamed('Kilo');
    for (var day = 1; day <= 8; day++) {
      await repo.addMeasurement(
        weight.id,
        80 + day * 0.5,
        measuredAt: DateTime(2026, 9, day * 3, 12),
      );
    }

    await pumpDetail(tester, weight, size: const Size(360, 780), textScale: 1.3);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Ölçüm ekle'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
