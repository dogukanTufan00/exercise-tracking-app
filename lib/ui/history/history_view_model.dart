import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/program_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/week_grouping.dart';

/// Geçmiş ekranının durumu: antrenman özetleri, yükleme ve hata bilgisi.
///
/// Antrenman başlatma sayfası için etkin programı da okur ve programın bir gününden antrenman başlatır.
/// [watchUpdates] verilirse saatten gelen her değişiklikte (ör. saatten başlatılan antrenman) liste yeniden okunur.
/// [settings] verilirse yedek hatırlatması hesaplanır (§16.4); yoksa hatırlatma hiç gösterilmez.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(
    this._repository,
    this._programRepository, {
    Stream<int>? watchUpdates,
    this.settings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _watchSubscription = watchUpdates?.listen((_) => load());
  }

  final WorkoutRepository _repository;
  final ProgramRepository _programRepository;
  final SettingsRepository? settings;
  final DateTime Function() _clock;
  StreamSubscription<int>? _watchSubscription;

  /// Son yedek bu süreden eskiyse hatırlatma gösterilir.
  static const Duration backupStaleAfter = Duration(days: 14);

  /// Hatırlatma kapatıldıktan sonra bu süre geçmeden yeniden gösterilmez.
  static const Duration reminderSnoozeAfterDismiss = Duration(days: 7);

  List<WorkoutSummary> _workouts = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _backupReminderTitle;
  bool _disposed = false;

  /// Repository'nin döndürdüğü sırayla (en yeni üstte).
  List<WorkoutSummary> get workouts => _workouts;

  /// [workouts] Pazartesi–Pazar haftalarına göre gruplanmış hali (en yeni hafta üstte).
  List<WeekGroup> get weeks => groupByWeek(workouts);

  /// İlk yüklemede `true`; her [load] çağrısında da true olur.
  bool get isLoading => _isLoading;

  /// Gösterilmeyi bekleyen Türkçe hata mesajı; yoksa `null`.
  String? get errorMessage => _errorMessage;

  /// Hata mesajını temizler; ekran mesajı SnackBar ile gösterdikten sonra çağırır.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  /// Yedek hatırlatmasının başlığı ("Henüz yedek almadın" ya da "Son yedeğin N gün önce"); gösterilmiyorsa `null`.
  String? get backupReminderTitle => _backupReminderTitle;

  /// Hatırlatmayı kapatır (×) ve kapatma zamanını saklar.
  Future<void> dismissBackupReminder() async {
    _backupReminderTitle = null;
    _notify();
    final repository = settings;
    if (repository == null) return;
    try {
      await repository.setBackupReminderDismissedAt(_clock());
    } on Exception {
      // Kayıt başarısızsa hatırlatma yine de bu oturumda kapalı kalır.
    }
  }

  /// Antrenman özetlerini repository'den yeniden okur; yedek hatırlatmasını da yeniden hesaplar.
  Future<void> load() async {
    _isLoading = true;
    _notify();

    try {
      final summaries = await _repository.getWorkoutSummaries();
      if (_disposed) return;
      _workouts = summaries;
    } on Exception {
      if (_disposed) return;
      _errorMessage = 'Antrenmanlar yüklenemedi.';
    }

    _isLoading = false;
    await _computeBackupReminder();
    _notify();
  }

  /// Hatırlatma koşulları (§16.4): en az bir antrenman var; son yedek yok ya da 14 günden eski;
  /// hatırlatma hiç kapatılmamış ya da 7 günden önce kapatılmış.
  Future<void> _computeBackupReminder() async {
    _backupReminderTitle = null;
    final repository = settings;
    if (repository == null || _workouts.isEmpty) return;

    try {
      final now = _clock();
      final lastBackup = await repository.getLastBackupAt();
      if (lastBackup != null && now.difference(lastBackup) <= backupStaleAfter) {
        return;
      }

      final dismissedAt = await repository.getBackupReminderDismissedAt();
      if (dismissedAt != null &&
          now.difference(dismissedAt) < reminderSnoozeAfterDismiss) {
        return;
      }

      _backupReminderTitle = lastBackup == null
          ? 'Henüz yedek almadın'
          : 'Son yedeğin ${now.difference(lastBackup).inDays} gün önce';
    } on Exception {
      // Ayar okunamazsa hatırlatma gösterilmez; liste yine de açılır.
      _backupReminderTitle = null;
    }
  }

  /// Yeni (başlıksız) bir antrenman oluşturur ve id'sini döndürür; hata olursa `null`.
  Future<int?> startWorkout() async {
    try {
      final workout = await _repository.createWorkout();
      return workout.id;
    } on Exception {
      _errorMessage = 'Antrenman başlatılamadı.';
      _notify();
      return null;
    }
  }

  /// Etkin programın detayı; etkin program yoksa `null`. Okuma hatasında `null` döner ve
  /// [errorMessage] ayarlanır.
  Future<ProgramDetail?> loadActiveProgram() async {
    try {
      return await _programRepository.getActiveProgramDetail();
    } catch (_) {
      _errorMessage = 'Program yüklenemedi.';
      _notify();
      return null;
    }
  }

  /// Programın bir gününden yeni antrenman oluşturur ve id'sini döndürür; hata olursa `null`.
  Future<int?> startFromProgramDay(int dayId) async {
    try {
      final workout = await _programRepository.startWorkoutFromDay(dayId);
      return workout.id;
    } catch (_) {
      _errorMessage = 'Antrenman başlatılamadı.';
      _notify();
      return null;
    }
  }

  /// Antrenmanı repository'den siler ve listeden çıkarır.
  Future<void> deleteWorkout(int id) async {
    try {
      await _repository.deleteWorkout(id);
      if (_disposed) return;
      _workouts = [
        for (final summary in _workouts)
          if (summary.workout.id != id) summary,
      ];
    } on Exception {
      _errorMessage = 'Antrenman silinemedi.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchSubscription?.cancel();
    super.dispose();
  }
}
