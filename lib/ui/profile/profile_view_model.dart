import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/measurement_repository.dart';

/// Profil ekranının durumu: her ölçüm türünün son değeri ve değişimi (bkz. docs/ARCHITECTURE.md §13).
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._repository);

  final MeasurementRepository _repository;

  List<MeasurementSummary> _summaries = const [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _disposed = false;

  /// Her ölçüm türü, [MeasurementRepository.getMeasurementSummaries] sırasıyla.
  List<MeasurementSummary> get summaries => _summaries;

  bool get isLoading => _isLoading;

  /// Gösterilmeyi bekleyen Türkçe hata mesajı; yoksa `null`.
  String? get errorMessage => _errorMessage;

  /// Hata mesajını temizler; ekran mesajı SnackBar ile gösterdikten sonra çağırır.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// İlk yükleme: yükleme göstergesi açıkken özetleri okur.
  Future<void> load() async {
    _isLoading = true;
    _notify();
    await _fetch();
    _isLoading = false;
    _notify();
  }

  /// Özetleri yükleme göstergesi olmadan yeniden okur (ölçüm eklenince ya da detaydan dönünce).
  Future<void> refresh() async {
    await _fetch();
    _notify();
  }

  /// Ölçüm ekler. Başarılıysa `true`; hata mesajı: 'Ölçüm eklenemedi.'
  Future<bool> addMeasurement(int typeId, double value, DateTime measuredAt) async {
    try {
      await _repository.addMeasurement(typeId, value, measuredAt: measuredAt);
    } catch (_) {
      _errorMessage = 'Ölçüm eklenemedi.';
      _notify();
      return false;
    }
    await refresh();
    return true;
  }

  /// Özel ölçüm türü ekler. Başarılıysa `true`. Hata mesajları:
  /// aynı ad → 'Bu adda bir ölçüm zaten var.'; diğer → 'Ölçüm eklenemedi.'
  Future<bool> createType(String name, String unit) async {
    try {
      await _repository.createMeasurementType(name, unit);
    } on DuplicateMeasurementTypeException {
      _errorMessage = 'Bu adda bir ölçüm zaten var.';
      _notify();
      return false;
    } catch (_) {
      _errorMessage = 'Ölçüm eklenemedi.';
      _notify();
      return false;
    }
    await refresh();
    return true;
  }

  /// Özetleri repository'den okur; hata olursa [errorMessage] yazılır.
  Future<void> _fetch() async {
    try {
      final summaries = await _repository.getMeasurementSummaries();
      if (_disposed) return;
      _summaries = summaries;
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
