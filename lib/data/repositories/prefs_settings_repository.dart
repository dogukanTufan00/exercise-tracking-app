import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'settings_repository.dart';

/// [SettingsRepository] uygulaması; tema seçimini `shared_preferences` ile saklar.
class PrefsSettingsRepository implements SettingsRepository {
  static const String _themeKey = 'theme_id';

  @override
  Future<AppThemeId> getThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    return AppThemeId.fromName(prefs.getString(_themeKey));
  }

  @override
  Future<void> setThemeId(AppThemeId themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeId.name);
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
