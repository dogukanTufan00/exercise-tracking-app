import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/settings_repository.dart';
import 'app_theme.dart';

/// Seçili temayı tutan ve değişince dinleyicileri bilgilendiren denetleyici.
///
/// Uygulamanın tema durumu buradadır; ayarlar ekranının ViewModel'i de budur.
class ThemeController extends ChangeNotifier {
  ThemeController(this._repository);

  final SettingsRepository _repository;

  /// Her tema için `ThemeData` yalnızca bir kez üretilir.
  final Map<AppThemeId, ThemeData> _themes = {};

  AppThemeId _themeId = AppThemeId.defaultTheme;
  bool _disposed = false;

  /// Seçili tema kimliği. [load] çağrılmadan önce varsayılan temadır.
  AppThemeId get themeId => _themeId;

  /// Seçili temanın `ThemeData`'sı.
  ThemeData get theme => _themes.putIfAbsent(_themeId, () => buildAppTheme(_themeId));

  /// Kayıtlı temayı repository'den okur.
  Future<void> load() async {
    final savedId = await _repository.getThemeId();
    if (_disposed) return;
    _themeId = savedId;
    notifyListeners();
  }

  /// Temayı hemen uygular, ardından kalıcı olarak kaydeder.
  Future<void> setTheme(AppThemeId id) async {
    _themeId = id;
    notifyListeners();
    await _repository.setThemeId(id);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
