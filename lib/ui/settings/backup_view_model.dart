import 'package:flutter/foundation.dart';

import '../../data/backup/backup_csv_exporter.dart';
import '../../data/backup/backup_json_codec.dart';
import '../../data/models/backup_data.dart';
import '../../data/repositories/measurement_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/services/backup_file_service.dart';

/// Ayarlar > Veriler bölümünün durumu: dışa aktarma, yedek alma ve yedekten geri yükleme.
class BackupViewModel extends ChangeNotifier {
  BackupViewModel(
    this._repository,
    this._measurements,
    this._files, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WorkoutRepository _repository;
  final MeasurementRepository _measurements;
  final BackupFileService _files;
  final DateTime Function() _clock;

  bool _isBusy = false;
  String? _message;
  String? _errorMessage;
  bool _disposed = false;

  /// Bir dışa aktarma ya da içe aktarma sürüyorsa `true`.
  bool get isBusy => _isBusy;

  /// Başarı bilgisi (SnackBar ile gösterilir); yoksa `null`.
  String? get message => _message;

  /// Hata mesajı (SnackBar ile gösterilir); yoksa `null`.
  String? get errorMessage => _errorMessage;

  /// Başarı mesajını temizler; ekran mesajı gösterdikten sonra çağırır.
  void clearMessage() {
    if (_message == null) return;
    _message = null;
    _notify();
  }

  /// Hata mesajını temizler; ekran mesajı gösterdikten sonra çağırır.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// Tüm verileri Excel'de açılabilir CSV olarak paylaşır.
  Future<void> exportCsv() {
    return _run(() async {
      final data = await _repository.exportBackup();
      if (_isEmpty(data)) {
        _errorMessage = _noDataMessage;
        return;
      }
      await _files.shareTextFile(
        fileName: 'antrenmanlar-${_dateStamp()}.csv',
        content: exportBackupCsv(data),
        mimeType: 'text/csv',
      );
    });
  }

  /// Tüm verileri geri yüklenebilir JSON yedeği olarak, kullanıcının seçtiği konuma kaydeder.
  ///
  /// Paylaşım menüsü yerine "Farklı kaydet" kullanılır: amaç bir yere göndermek değil,
  /// dosyayı telefonda bulunabilir bir yere koymak.
  Future<void> exportJson() {
    return _run(() async {
      final workoutData = await _repository.exportBackup();
      final measurementData = await _measurements.exportMeasurements();
      final data = BackupData(
        exportedAt: workoutData.exportedAt,
        exercises: workoutData.exercises,
        workouts: workoutData.workouts,
        measurementTypes: measurementData.types,
        measurements: measurementData.measurements,
      );
      if (_isEmpty(data) &&
          data.measurementTypes.isEmpty &&
          data.measurements.isEmpty) {
        // JSON yedeği hareket, antrenman ve ölçümlerin hepsi boşsa alınmaz.
        _errorMessage = _noDataMessage;
        return;
      }
      final saved = await _files.saveTextFile(
        fileName: 'antrenman-yedegi-${_dateStamp()}.json',
        content: encodeBackupJson(data),
        mimeType: 'application/json',
      );
      if (saved) _message = 'Yedek kaydedildi';
    });
  }

  /// Seçilen JSON yedeğini mevcut verilerle birleştirir. Hiçbir mevcut veri silinmez.
  ///
  /// Önce antrenmanlar, sonra ölçümler içe aktarılır; her biri kendi içinde ya hep ya hiç.
  Future<void> importJson() {
    return _run(() async {
      final text = await _files.pickTextFile();
      if (text == null) return;

      final data = decodeBackupJson(text);
      final ImportResult result;
      try {
        result = await _repository.importBackup(data);
      } on ArgumentError {
        _errorMessage =
            'Yedek dosyasında geçersiz değerler var; hiçbir şey değiştirilmedi.';
        return;
      }

      // Antrenmanlar artık yazıldı; ölçümler ayrı transaction'da. Hata olursa mesaj bunu söylemeli.
      final int addedMeasurements;
      try {
        addedMeasurements = await _measurements.importMeasurements(
          types: data.measurementTypes,
          measurements: data.measurements,
        );
      } on ArgumentError {
        _errorMessage =
            'Antrenmanlar eklendi ama ölçümler geçersiz değerler içerdiği için eklenemedi.';
        return;
      }
      _message = _importMessage(result, addedMeasurements);
    });
  }

  /// Ortak akış: aynı anda tek işlem çalışır; hataları Türkçe mesaja çevirir.
  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    _isBusy = true;
    _notify();

    try {
      await action();
    } on BackupFormatException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'İşlem tamamlanamadı.';
    }

    _isBusy = false;
    _notify();
  }

  static const String _noDataMessage = 'Henüz kaydedilmiş veri yok.';

  /// CSV için "veri yok" kontrolü: yalnızca hareket ve antrenman (CSV ölçüm içermez).
  static bool _isEmpty(BackupData data) {
    return data.exercises.isEmpty && data.workouts.isEmpty;
  }

  static String _importMessage(ImportResult result, int addedMeasurements) {
    final buffer = StringBuffer(
      '${result.addedWorkouts} antrenman eklendi, '
      '${result.skippedWorkouts} antrenman atlandı',
    );
    if (result.addedExercises > 0) {
      buffer.write(', ${result.addedExercises} yeni hareket');
    }
    if (addedMeasurements > 0) {
      buffer.write(', $addedMeasurements ölçüm');
    }
    return buffer.toString();
  }

  /// Dosya adları için bugünün tarihi: `YYYY-MM-DD`.
  String _dateStamp() {
    final now = _clock();
    return '${_pad(now.year, 4)}-${_pad(now.month, 2)}-${_pad(now.day, 2)}';
  }

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
