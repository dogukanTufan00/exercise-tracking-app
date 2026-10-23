import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/program_repository.dart';

/// Program günü düzenleme ekranının durumu: gün adı, planlanan gün, hareketler ve hedefleri.
///
/// Gün, id'sinden bulunur: programlar gezilir ve günü içeren program yüklenir. Her değişiklikten
/// sonra program yeniden okunur; böylece ekran her zaman veritabanındaki son hali gösterir.
class DayEditViewModel extends ChangeNotifier {
  DayEditViewModel(this._repository, this.dayId);

  final ProgramRepository _repository;

  /// Düzenlenen günün id'si.
  final int dayId;

  ProgramDetail? _program;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  /// Düzenlenen gün; bulunamadıysa `null`.
  ProgramDay? get day => _dayDetail?.day;

  /// Günün hareketleri, sıraya göre.
  List<ProgramDayExerciseDetail> get exercises => _dayDetail?.exercises ?? const [];

  bool get isLoading => _isLoading;

  /// Ekranda gösterilecek hata; gösterildikten sonra [clearError] ile temizlenmeli.
  String? get errorMessage => _errorMessage;

  /// Günün detayı (gün ve hareketleri); bulunamadıysa `null`.
  ProgramDayDetail? get _dayDetail {
    final program = _program;
    if (program == null) return null;
    for (final detail in program.days) {
      if (detail.day.id == dayId) return detail;
    }
    return null;
  }

  /// Tüm programlarda günü arar ve bulduğu programı yükler.
  Future<void> load() async {
    _isLoading = true;
    _notify();

    try {
      _program = await _findProgram();
    } catch (_) {
      _errorMessage = 'Gün yüklenemedi';
    }

    _isLoading = false;
    _notify();
  }

  /// Günün adını değiştirir. Ad boşsa ya da gün yoksa `false` döner.
  Future<bool> rename(String name) async {
    final current = day;
    final cleaned = name.trim();
    if (current == null || cleaned.isEmpty) return false;

    return _run(
      () => _repository.updateDay(_copyDay(current, name: cleaned, weekday: current.weekday)),
      'Gün adı kaydedilemedi',
    );
  }

  /// Planlanan günü değiştirir; `null` = esnek gün.
  Future<bool> setWeekday(int? weekday) async {
    final current = day;
    if (current == null) return false;
    if (current.weekday == weekday) return true;

    return _run(
      () => _repository.updateDay(_copyDay(current, name: current.name, weekday: weekday)),
      'Planlanan gün kaydedilemedi',
    );
  }

  /// Günü ve hareketlerini siler. Başarılıysa `true` döner; ekran bu durumda kapanır.
  Future<bool> deleteDay() {
    return _run(() => _repository.deleteDay(dayId), 'Gün silinemedi');
  }

  /// Güne hareket ekler (sona).
  Future<bool> addExercise(int exerciseId, ExerciseTarget target) {
    return _run(
      () => _repository.addDayExercise(dayId, exerciseId, target),
      'Hareket eklenemedi',
    );
  }

  /// Günün bir hareketinin hedefini değiştirir.
  Future<bool> updateTarget(int dayExerciseId, ExerciseTarget target) {
    return _run(
      () => _repository.updateDayExerciseTarget(dayExerciseId, target),
      'Hedef kaydedilemedi',
    );
  }

  /// Hareketi günden çıkarır.
  Future<bool> removeExercise(int dayExerciseId) {
    return _run(
      () => _repository.removeDayExercise(dayExerciseId),
      'Hareket çıkarılamadı',
    );
  }

  /// [index] numaralı hareketi [delta] kadar kaydırır (-1 yukarı, +1 aşağı). Sınır dışıysa hiçbir şey yapmaz.
  Future<bool> moveExercise(int index, int delta) {
    final current = exercises;
    final target = index + delta;
    if (index < 0 || index >= current.length || target < 0 || target >= current.length) {
      return Future.value(false);
    }

    final ids = [for (final detail in current) detail.dayExercise.id];
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    return _run(
      () => _repository.reorderDayExercises(dayId, ids),
      'Sıralama kaydedilemedi',
    );
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Yazma işlemini çalıştırır, programı yeniden okur. Hata olursa [failureMessage] yazılır.
  Future<bool> _run(Future<void> Function() action, String failureMessage) async {
    if (_program == null) return false;

    try {
      await action();
      await _refresh();
      _notify();
      return true;
    } catch (_) {
      _errorMessage = failureMessage;
      _notify();
      return false;
    }
  }

  /// Günü içeren programı bulur; yoksa `null`.
  Future<ProgramDetail?> _findProgram() async {
    for (final program in await _repository.getPrograms()) {
      final detail = await _repository.getProgramDetail(program.id);
      if (detail == null) continue;
      if (detail.days.any((d) => d.day.id == dayId)) return detail;
    }
    return null;
  }

  /// Yüklü programı veritabanından yeniden okur.
  Future<void> _refresh() async {
    final programId = _program?.program.id;
    if (programId == null) return;
    _program = await _repository.getProgramDetail(programId);
  }

  ProgramDay _copyDay(ProgramDay day, {required String name, required int? weekday}) {
    return ProgramDay(
      id: day.id,
      programId: day.programId,
      name: name,
      position: day.position,
      weekday: weekday,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
