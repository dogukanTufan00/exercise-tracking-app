import '../models/models.dart';

/// Kullanıcı tercihleri. Uygulaması `shared_preferences` kullanır.
abstract interface class SettingsRepository {
  /// Kayıtlı tema; hiç seçilmemişse [AppThemeId.defaultTheme].
  Future<AppThemeId> getThemeId();

  Future<void> setThemeId(AppThemeId themeId);
}
