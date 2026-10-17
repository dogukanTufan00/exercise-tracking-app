/// Kullanıcının seçebileceği renk temaları. Renk değerleri `lib/ui/core/theme/` içindedir;
/// burada yalnızca kimlik ve görünen ad bulunur, böylece veri katmanı arayüze bağımlı olmaz.
enum AppThemeId {
  darkOrange('Koyu turuncu'),
  redBlack('Kırmızı siyah'),
  yellowNavy('Sarı lacivert'),
  lightBlue('Açık mavi');

  const AppThemeId(this.label);

  final String label;

  static const AppThemeId defaultTheme = AppThemeId.darkOrange;

  /// Kayıtlı değeri enum'a çevirir. Değer yoksa ya da tanınmıyorsa varsayılan tema döner.
  static AppThemeId fromName(String? name) {
    return AppThemeId.values.firstWhere(
      (theme) => theme.name == name,
      orElse: () => defaultTheme,
    );
  }
}
