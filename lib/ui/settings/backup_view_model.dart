import 'package:flutter/foundation.dart';

import '../../data/backup/backup_csv_exporter.dart';
import '../../data/backup/backup_json_codec.dart';
import '../../data/models/backup_data.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/services/backup_file_service.dart';

/// Ayarlar > Veriler bölümünün durumu: dışa aktarma, yedek alma ve yedekten geri yükleme.
class BackupViewModel extends ChangeNotifier {
  BackupViewModel(
    this._repository,
    this._files, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WorkoutRepository _repository;
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
      final data = await _repository.exportBackup();
      if (_isEmpty(data)) {
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
      _message = _importMessage(result);
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

  static bool _isEmpty(BackupData data) {
    return data.exercises.isEmpty && data.workouts.isEmpty;
  }

  static String _importMessage(ImportResult result) {
    final buffer = StringBuffer(
      '${result.addedWorkouts} antrenman eklendi, '
      '${result.skippedWorkouts} antrenman atlandı',
    );
    if (result.addedExercises > 0) {
      buffer.write(', ${result.addedExercises} yeni hareket');
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
