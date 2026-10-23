import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/measurement_repository.dart';

/// Ölçüm detay ekranının durumu: bir türün ölçümleri (en eskiden en yeniye) ve yükleme/hata bilgisi.
///
/// Her değişiklikten sonra ölçümler repository'den yeniden okunur; böylece liste ve grafik güncel kalır.
class MeasurementDetailViewModel extends ChangeNotifier {
  MeasurementDetailViewModel(this._repository, {required this.type});

  final MeasurementRepository _repository;

  /// Detayı gösterilen ölçüm türü.
  final MeasurementType type;

  List<BodyMeasurement> _measurements = const [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _disposed = false;

  /// Türün tüm ölçümleri, en eskiden en yeniye (grafik için; liste ters çevrilerek gösterilir).
  List<BodyMeasurement> get measurements => _measurements;

  bool get isLoading => _isLoading;

  /// Gösterilmeyi bekleyen Türkçe hata mesajı; yoksa `null`.
  String? get errorMessage => _errorMessage;

  /// Hiç ölçüm yoksa `true`.
  bool get isEmpty => _measurements.isEmpty;

  /// Hata mesajını temizler; ekran mesajı SnackBar ile gösterdikten sonra çağırır.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// İlk yükleme: yükleme göstergesi açıkken ölçümleri okur.
  Future<void> load() async {
    _isLoading = true;
    _notify();
    await _fetch();
    _isLoading = false;
    _notify();
  }

  /// Yeni ölçüm ekler. Başarılıysa `true`; hata mesajı: 'Ölçüm eklenemedi.'
  Future<bool> addMeasurement(double value, DateTime measuredAt) {
    return _run(
      () => _repository.addMeasurement(type.id, value, measuredAt: measuredAt),
      failure: 'Ölçüm eklenemedi.',
    );
  }

  /// Ölçümün değerini ve tarihini günceller. Hata mesajı: 'Ölçüm güncellenemedi.'
  Future<bool> updateMeasurement(
    BodyMeasurement measurement, {
    required double value,
    required DateTime measuredAt,
  }) {
    return _run(
      () => _repository.updateMeasurement(
        measurement.copyWith(value: value, measuredAt: measuredAt),
      ),
      failure: 'Ölçüm güncellenemedi.',
    );
  }

  /// Ölçümü siler. Hata mesajı: 'Ölçüm silinemedi.'
  Future<bool> deleteMeasurement(BodyMeasurement measurement) {
    return _run(
      () => _repository.deleteMeasurement(measurement.id),
      failure: 'Ölçüm silinemedi.',
    );
  }

  /// Silinen ölçümü aynı değer ve tarihle geri ekler ("Geri al"). Hata mesajı: 'Ölçüm geri alınamadı.'
  Future<bool> restoreMeasurement(BodyMeasurement measurement) {
    return _run(
      () => _repository.addMeasurement(
        measurement.typeId,
        measurement.value,
        measuredAt: measurement.measuredAt,
      ),
      failure: 'Ölçüm geri alınamadı.',
    );
  }

  /// Özel ölçüm türünü ve tüm ölçümlerini siler. Başarılıysa `true` (ekran kapanır).
  /// Hata mesajı: 'Ölçüm türü silinemedi.'
  Future<bool> deleteType() async {
    try {
      await _repository.deleteMeasurementType(type.id);
    } catch (_) {
      _errorMessage = 'Ölçüm türü silinemedi.';
      _notify();
      return false;
    }
    return true;
  }

  /// [action] çalışır, sonra ölçümler yeniden okunur. Hata olursa [failure] mesajı yazılır.
  Future<bool> _run(
    Future<Object?> Function() action, {
    required String failure,
  }) async {
    try {
      await action();
    } catch (_) {
      _errorMessage = failure;
      _notify();
      return false;
    }
    await _fetch();
    _notify();
    return true;
  }

  /// Ölçümleri repository'den okur; hata olursa [errorMessage] yazılır.
  Future<void> _fetch() async {
    try {
      final measurements = await _repository.getMeasurements(type.id);
      if (_disposed) return;
      _measurements = measurements;
    } catch (_) {
      if (_disposed) return;
      _errorMessage = 'Ölçümler yüklenemedi.';
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
