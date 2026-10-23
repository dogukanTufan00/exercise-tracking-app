import 'package:exercise_tracking_app/ui/profile/profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_measurement_repository.dart';

void main() {
  late FakeMeasurementRepository repo;
  late ProfileViewModel viewModel;

  setUp(() {
    repo = FakeMeasurementRepository();
    viewModel = ProfileViewModel(repo);
  });

  tearDown(() {
    viewModel.dispose();
  });

  Future<int> typeIdNamed(String name) async {
    final types = await repo.getMeasurementTypes();
    return types.firstWhere((t) => t.name == name).id;
  }

  test('yükleme: 10 yerleşik tür özetlenir ve yükleme biter', () async {
    expect(viewModel.isLoading, isTrue);

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.summaries.length, 10);
    expect(viewModel.summaries.first.type.name, 'Kilo');
    expect(viewModel.summaries.every((s) => s.latest == null), isTrue);
  });

  test('ölçüm eklenince özet son değeri ve değişimi güncellenir', () async {
    await viewModel.load();
    final weight = await typeIdNamed('Kilo');

    await viewModel.addMeasurement(weight, 82, DateTime(2026, 10, 1, 12));
    await viewModel.addMeasurement(weight, 82.5, DateTime(2026, 10, 8, 12));

    final summary = viewModel.summaries.first;
    expect(summary.latest?.value, 82.5);
    expect(summary.change, closeTo(0.5, 1e-9));
    expect(viewModel.errorMessage, isNull);
  });

  test('özel tür listenin sonuna eklenir', () async {
    await viewModel.load();

    final ok = await viewModel.createType('Ön kol', 'cm');

    expect(ok, isTrue);
    expect(viewModel.summaries.length, 11);
    expect(viewModel.summaries.last.type.name, 'Ön kol');
    expect(viewModel.summaries.last.type.unit, 'cm');
  });

  test('aynı adda tür eklenirse mesaj verilir ve liste değişmez', () async {
    await viewModel.load();

    final ok = await viewModel.createType('SAĞ KOL', 'cm');

    expect(ok, isFalse);
    expect(viewModel.errorMessage, 'Bu adda bir ölçüm zaten var.');
    expect(viewModel.summaries.length, 10);

    viewModel.clearError();
    expect(viewModel.errorMessage, isNull);
  });

  test('geçersiz değer ile ölçüm eklenemezse Türkçe hata verilir', () async {
    await viewModel.load();
    final weight = await typeIdNamed('Kilo');

    final ok = await viewModel.addMeasurement(weight, 0, DateTime(2026, 10, 1));

    expect(ok, isFalse);
    expect(viewModel.errorMessage, 'Ölçüm eklenemedi.');
  });
}
