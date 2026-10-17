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
}
