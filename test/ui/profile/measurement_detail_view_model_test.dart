import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/ui/profile/measurement_detail_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_measurement_repository.dart';

void main() {
  late FakeMeasurementRepository repo;
  late MeasurementType weight;

  setUp(() async {
    repo = FakeMeasurementRepository();
    weight = (await repo.getMeasurementTypes()).first;
  });

  test('yükleme boş ölçümle biter; boşsa isEmpty doğru', () async {
    final viewModel = MeasurementDetailViewModel(repo, type: weight);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isEmpty, isTrue);
    expect(viewModel.type.name, 'Kilo');
  });

  test('ölçümler en eskiden en yeniye sıralanır', () async {
    final viewModel = MeasurementDetailViewModel(repo, type: weight);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    await viewModel.addMeasurement(81, DateTime(2026, 10, 8, 12));
    await viewModel.addMeasurement(80, DateTime(2026, 10, 1, 12));

    expect(viewModel.measurements.map((m) => m.value), [80, 81]);
    expect(viewModel.isEmpty, isFalse);
  });

  test('düzenleme değeri ve tarihi günceller', () async {
    final viewModel = MeasurementDetailViewModel(repo, type: weight);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await viewModel.addMeasurement(80, DateTime(2026, 10, 1, 12));
    final original = viewModel.measurements.single;

    final ok = await viewModel.updateMeasurement(
      original,
      value: 79.5,
      measuredAt: DateTime(2026, 10, 3, 12),
    );

    expect(ok, isTrue);
    final updated = viewModel.measurements.single;
    expect(updated.id, original.id);
    expect(updated.value, 79.5);
    expect(updated.measuredAt, DateTime(2026, 10, 3, 12));
  });

  test('silinen ölçüm geri alınınca aynı değer ve tarihle döner', () async {
    final viewModel = MeasurementDetailViewModel(repo, type: weight);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await viewModel.addMeasurement(80, DateTime(2026, 10, 1, 12));
    final removed = viewModel.measurements.single;

    await viewModel.deleteMeasurement(removed);
    expect(viewModel.isEmpty, isTrue);

    await viewModel.restoreMeasurement(removed);
    final restored = viewModel.measurements.single;
    expect(restored.value, 80);
    expect(restored.measuredAt, DateTime(2026, 10, 1, 12));
  });

  test('özel tür silinebilir; ölçümleri ile birlikte gider', () async {
    final custom = await repo.createMeasurementType('Ön kol', 'cm');
    final viewModel = MeasurementDetailViewModel(repo, type: custom);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await viewModel.addMeasurement(28, DateTime(2026, 10, 1, 12));

    final ok = await viewModel.deleteType();

    expect(ok, isTrue);
    final names = (await repo.getMeasurementTypes()).map((t) => t.name);
    expect(names, isNot(contains('Ön kol')));
  });

  test('yerleşik tür silinemez; Türkçe hata verilir', () async {
    final viewModel = MeasurementDetailViewModel(repo, type: weight);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    final ok = await viewModel.deleteType();

    expect(ok, isFalse);
    expect(viewModel.errorMessage, 'Ölçüm türü silinemedi.');
  });
}
