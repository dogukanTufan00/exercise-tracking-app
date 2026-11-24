import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/settings_repository.dart';
import 'package:exercise_tracking_app/domain/rest_timer.dart';

/// Testler için bellekte çalışan [SettingsRepository].
///
/// Kaydedilen her tema [savedThemeIds] listesine eklenir; testler kaydı bu listeden doğrular.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({AppThemeId initialTheme = AppThemeId.defaultTheme})
      : _themeId = initialTheme;

  AppThemeId _themeId;

  /// [setThemeId] ile kaydedilen temaların sırası.
  final List<AppThemeId> savedThemeIds = [];

  @override
  Future<AppThemeId> getThemeId() async => _themeId;

  @override
  Future<void> setThemeId(AppThemeId themeId) async {
    _themeId = themeId;
    savedThemeIds.add(themeId);
  }

  int _restSeconds = restDefaultSeconds;
  bool _restVibrateOnPhone = true;
  DateTime? _lastBackupAt;
  DateTime? _backupReminderDismissedAt;

  @override
  Future<int> getRestSeconds() async => _restSeconds;

  @override
  Future<void> setRestSeconds(int seconds) async {
    _restSeconds = clampRestSeconds(seconds);
  }

  @override
  Future<bool> getRestVibrateOnPhone() async => _restVibrateOnPhone;

  @override
  Future<void> setRestVibrateOnPhone(bool value) async {
    _restVibrateOnPhone = value;
  }

  @override
  Future<DateTime?> getLastBackupAt() async => _lastBackupAt;

  @override
  Future<void> setLastBackupAt(DateTime value) async {
    _lastBackupAt = value;
  }

  @override
  Future<DateTime?> getBackupReminderDismissedAt() async => _backupReminderDismissedAt;

  @override
  Future<void> setBackupReminderDismissedAt(DateTime value) async {
    _backupReminderDismissedAt = value;
  }
}
