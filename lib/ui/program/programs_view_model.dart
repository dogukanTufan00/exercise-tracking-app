import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/program_repository.dart';

/// Programlar ekranının durumu: tüm programların listesi ve etkin programın seçimi.
class ProgramsViewModel extends ChangeNotifier {
  ProgramsViewModel(this._repository);

  final ProgramRepository _repository;

  List<Program> _programs = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  /// Tüm programlar, oluşturulma sırasıyla.
  List<Program> get programs => _programs;

  bool get isLoading => _isLoading;

  /// Ekranda gösterilecek hata; gösterildikten sonra [clearError] ile temizlenmeli.
  String? get errorMessage => _errorMessage;

  /// Programları okur.
  Future<void> load() async {
    _isLoading = true;
    _notify();
    try {
      final programs = await _repository.getPrograms();
      if (_disposed) return;
      _programs = programs;
    } catch (_) {
      if (_disposed) return;
      _errorMessage = 'Programlar yüklenemedi.';
    }
    _isLoading = false;
    _notify();
  }

  /// Yeni program oluşturur ve listeyi yeniler. Başarılıysa `true` döner.
  Future<bool> createProgram(String name) async {
    try {
      await _repository.createProgram(name);
    } catch (_) {
      _fail();
      return false;
    }
    await load();
    return true;
  }

  /// Programı etkin yapar ve listeyi yeniler. Başarılıysa `true` döner.
  Future<bool> setActiveProgram(int programId) async {
    try {
      await _repository.setActiveProgram(programId);
    } catch (_) {
      _fail();
      return false;
    }
    await load();
    return true;
  }

  /// Gösterilen hatayı temizler.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  void _fail() {
    if (_disposed) return;
    _errorMessage = 'İşlem tamamlanamadı.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
