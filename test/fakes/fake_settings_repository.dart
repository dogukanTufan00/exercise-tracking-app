import 'package:exercise_tracking_app/data/models/models.dart';
import 'package:exercise_tracking_app/data/repositories/settings_repository.dart';

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

  // TODO(dalga 16, CB): dinlenme ve yedek hatırlatması ayarlarını uygula.
  @override
  Future<int> getRestSeconds() => throw UnimplementedError();

  @override
  Future<void> setRestSeconds(int seconds) => throw UnimplementedError();

  @override
  Future<bool> getRestVibrateOnPhone() => throw UnimplementedError();

  @override
  Future<void> setRestVibrateOnPhone(bool value) => throw UnimplementedError();

  @override
  Future<DateTime?> getLastBackupAt() => throw UnimplementedError();

  @override
  Future<void> setLastBackupAt(DateTime value) => throw UnimplementedError();

  @override
  Future<DateTime?> getBackupReminderDismissedAt() => throw UnimplementedError();

  @override
  Future<void> setBackupReminderDismissedAt(DateTime value) => throw UnimplementedError();
}
