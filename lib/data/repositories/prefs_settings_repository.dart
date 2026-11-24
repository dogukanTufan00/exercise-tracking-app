import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/rest_timer.dart';
import '../models/models.dart';
import 'settings_repository.dart';

/// [SettingsRepository] uygulaması; tema, dinlenme ve yedek hatırlatması ayarlarını `shared_preferences` ile saklar.
class PrefsSettingsRepository implements SettingsRepository {
  static const String _themeKey = 'theme_id';
  static const String _restSecondsKey = 'rest_seconds';
  static const String _restVibrateKey = 'rest_vibrate_on_phone';
  static const String _lastBackupKey = 'last_backup_at';
  static const String _backupDismissedKey = 'backup_reminder_dismissed_at';

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

  // ------------------------------------------------ Dinlenme (§16.2)

  @override
  Future<int> getRestSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    // Ekransız motor da yazar; her okumada disk okunur.
    await prefs.reload();
    return clampRestSeconds(prefs.getInt(_restSecondsKey) ?? restDefaultSeconds);
  }

  @override
  Future<void> setRestSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_restSecondsKey, clampRestSeconds(seconds));
  }

  @override
  Future<bool> getRestVibrateOnPhone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_restVibrateKey) ?? true;
  }

  @override
  Future<void> setRestVibrateOnPhone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_restVibrateKey, value);
  }

  // ------------------------------------------------ Yedek hatırlatması (§16.4)

  @override
  Future<DateTime?> getLastBackupAt() => _readDate(_lastBackupKey);

  @override
  Future<void> setLastBackupAt(DateTime value) => _writeDate(_lastBackupKey, value);

  @override
  Future<DateTime?> getBackupReminderDismissedAt() => _readDate(_backupDismissedKey);

  @override
  Future<void> setBackupReminderDismissedAt(DateTime value) =>
      _writeDate(_backupDismissedKey, value);

  Future<DateTime?> _readDate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    return text == null ? null : DateTime.tryParse(text);
  }

  Future<void> _writeDate(String key, DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value.toIso8601String());
  }
}
