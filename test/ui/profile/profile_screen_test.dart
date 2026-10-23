import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/measurement_repository.dart';
import 'package:exercise_tracking_app/ui/core/theme/app_theme.dart';
import 'package:exercise_tracking_app/ui/profile/measurement_detail_screen.dart';
import 'package:exercise_tracking_app/ui/profile/profile_screen.dart';
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

  Future<void> pumpProfile(
    WidgetTester tester, {
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
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<int> typeIdNamed(String name) async {
    final types = await repo.getMeasurementTypes();
    return types.firstWhere((t) => t.name == name).id;
  }

  testWidgets('10 yerleşik tür listelenir; ölçümü olmayanlar boş metin gösterir',
      (tester) async {
    await pumpProfile(tester);

    expect(find.text('Kilo'), findsOneWidget);
    expect(find.text('Boyun'), findsOneWidget);
    expect(find.text('Henüz ölçüm yok'), findsNWidgets(10));
  });

  testWidgets('hızlı ekleme ile değer ve değişim görünür', (tester) async {
    final weight = await typeIdNamed('Kilo');
    await repo.addMeasurement(weight, 82, measuredAt: DateTime(2020, 1, 1, 12));

    await pumpProfile(tester);
    await tester.tap(find.byTooltip('Ölçüm ekle').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '82,5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('82,5 kg'), findsOneWidget);
    expect(find.text('+0,5 kg'), findsOneWidget);
  });

  testWidgets('azalış eksi işaretle görünür', (tester) async {
    final weight = await typeIdNamed('Kilo');
    await repo.addMeasurement(weight, 82.5, measuredAt: DateTime(2020, 1, 1, 12));
    await repo.addMeasurement(weight, 81, measuredAt: DateTime(2021, 1, 1, 12));

    await pumpProfile(tester);

    expect(find.text('81 kg'), findsOneWidget);
    expect(find.text('−1,5 kg'), findsOneWidget);
  });

  testWidgets('0 girilince hata metni görünür ve Kaydet kapalı kalır', (tester) async {
    await pumpProfile(tester);
    await tester.tap(find.byTooltip('Ölçüm ekle').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();

    expect(find.text("0'dan büyük bir değer girin"), findsOneWidget);
    final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'));
    expect(save.onPressed, isNull);
  });

  testWidgets('özel tür eklenir ve listenin sonunda görünür', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byTooltip('Özel ölçüm ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ön kol');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Ön kol'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Ön kol')).dy,
      greaterThan(tester.getCenter(find.text('Boyun')).dy),
    );
  });

  testWidgets('satıra dokununca ölçüm detayı açılır; yerleşik türde Ölçümü sil yok',
      (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Kilo'));
    await tester.pumpAndSettle();

    expect(find.byType(MeasurementDetailScreen), findsOneWidget);
    expect(find.byTooltip('Seçenekler'), findsNothing);
  });

  testWidgets('360x780 ve yazı 1.3 ile liste ve diyalog taşmaz', (tester) async {
    final weight = await typeIdNamed('Kilo');
    await repo.addMeasurement(weight, 82, measuredAt: DateTime(2020, 1, 1, 12));
    await repo.addMeasurement(weight, 82.5, measuredAt: DateTime(2020, 2, 1, 12));

    await pumpProfile(tester, size: const Size(360, 780), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('+0,5 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Özel ölçüm ekle'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
