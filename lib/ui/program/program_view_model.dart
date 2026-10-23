import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/program_repository.dart';

/// Program sekmesinin durumu: etkin programın ayrıntısı ve günlerin düzenlenmesi.
///
/// Her değişiklik repository'ye yazılır ve ardından etkin program yeniden okunur.
class ProgramViewModel extends ChangeNotifier {
  ProgramViewModel(this._repository);

  final ProgramRepository _repository;

  ProgramDetail? _detail;
  bool _hasPrograms = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  /// Etkin programın ayrıntısı; etkin program yoksa `null`.
  ProgramDetail? get detail => _detail;

  /// Hiç program var mı (etkin olması gerekmez).
  bool get hasPrograms => _hasPrograms;

  /// İlk yükleme sürüyor mu (sekmeye dönüşlerde `true` olmaz).
  bool get isLoading => _isLoading;

  /// Ekranda gösterilecek hata; gösterildikten sonra [clearError] ile temizlenmeli.
  String? get errorMessage => _errorMessage;

  /// İlk yükleme; göstergeyi açar ve [refresh] çağırır.
  Future<void> load() async {
    _isLoading = true;
    await refresh();
    _isLoading = false;
    _notify();
  }

  /// Etkin programı yeniden okur. Yükleme göstergesi göstermez.
  Future<void> refresh() async {
    try {
      final programs = await _repository.getPrograms();
      final active = await _repository.getActiveProgramDetail();
      if (_disposed) return;
      _hasPrograms = programs.isNotEmpty;
      _detail = active;
    } catch (_) {
      if (_disposed) return;
      _errorMessage = 'Program yüklenemedi.';
    }
    _notify();
  }

  /// Yeni program oluşturur (ilk programsa zaten etkin olur).
  Future<void> createProgram(String name) async {
    await _apply(() async {
      await _repository.createProgram(name);
    });
  }

  /// Etkin programı yeniden adlandırır.
  Future<void> renameActiveProgram(String name) async {
    final programId = _detail?.program.id;
    if (programId == null) return;
    await _apply(() => _repository.renameProgram(programId, name));
  }

  /// Etkin programı günleriyle birlikte siler.
  Future<void> deleteActiveProgram() async {
    final programId = _detail?.program.id;
    if (programId == null) return;
    await _apply(() => _repository.deleteProgram(programId));
  }

  /// Etkin programa yeni gün ekler ve günün id'sini döndürür; başarısızsa `null`.
  Future<int?> addDay(String name) async {
    final programId = _detail?.program.id;
    if (programId == null) return null;
    try {
      final day = await _repository.addDay(programId, name);
      await refresh();
      return day.id;
    } catch (_) {
      _fail();
      return null;
    }
  }

  /// [index] numaralı günü [offset] kadar kaydırır (-1 yukarı, +1 aşağı). Sınır dışıysa hiçbir şey yapmaz.
  Future<void> moveDay(int index, int offset) async {
    final detail = _detail;
    if (detail == null) return;
    final days = detail.days;
    final target = index + offset;
    if (index < 0 || index >= days.length || target < 0 || target >= days.length) return;

    final ids = [for (final d in days) d.day.id];
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    await _apply(() => _repository.reorderDays(detail.program.id, ids));
  }

  /// Gösterilen hatayı temizler.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// Yazma işlemini çalıştırır; hata olursa mesajı bırakır, başarıda listeyi yeniler.
  Future<void> _apply(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _fail();
      return;
    }
    await refresh();
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
