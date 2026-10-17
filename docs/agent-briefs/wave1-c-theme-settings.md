# Dalga 1 – Ajan C: Tema sistemi + ayarlar repository

Önce [ortak kuralları](README.md) oku. `docs/DESIGN.md` bu görevin ana kaynağıdır.

## Dokunabileceğin dosyalar

- `pubspec.yaml` → **yalnızca** `flutter:` bölümüne `fonts:` eklemek için (başka hiçbir satıra dokunma)
- `lib/ui/core/theme/app_palette.dart` (yeni)
- `lib/ui/core/theme/app_theme.dart` (yeni)
- `lib/data/repositories/prefs_settings_repository.dart` (yeni)
- `test/ui/core/theme/app_theme_test.dart` (yeni)
- `test/data/repositories/prefs_settings_repository_test.dart` (yeni)

`lib/ui/core/theme/app_spacing.dart` hazır; **değiştirme**, kullan.

## 1. Fontlar (`pubspec.yaml`)

`assets/fonts/` içinde değişken (variable) fontlar var: `Oswald-Variable.ttf`, `Inter-Variable.ttf`.

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: Oswald
      fonts:
        - asset: assets/fonts/Oswald-Variable.ttf
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Variable.ttf
```

Değişken fontlarda kalınlık için `TextStyle`'a hem `fontWeight` hem de
`fontVariations: [FontVariation('wght', <değer>)]` ver (ör. 500 için ikisi de).

## 2. `app_palette.dart`

```dart
class AppPalette {
  const AppPalette({required this.brightness, required this.background, required this.surface,
    required this.outline, required this.onSurface, required this.muted,
    required this.primary, required this.onPrimary});
  // alanlar: Brightness brightness; Color background, surface, outline, onSurface, muted, primary, onPrimary;
  static AppPalette of(AppThemeId id); // switch ile
}
```

Değerler `docs/DESIGN.md` §2 tablosundan **birebir** (hex). İlk üç tema `Brightness.dark`, `lightBlue` `Brightness.light`.

## 3. `app_theme.dart`

`ThemeData buildAppTheme(AppThemeId id)` – Material 3 (`useMaterial3: true`). `ColorScheme`'i elle kur
(`ColorScheme.fromSeed` kullanma, renkler tam olarak tablodaki gibi olmalı):

| ColorScheme alanı | Değer |
|---|---|
| `brightness` | palette.brightness |
| `primary`, `secondary`, `tertiary` | palette.primary |
| `onPrimary`, `onSecondary`, `onTertiary` | palette.onPrimary |
| `surface` | palette.background |
| `surfaceContainerLowest` … `surfaceContainerHighest` (5 alan) | palette.surface |
| `onSurface` | palette.onSurface |
| `onSurfaceVariant` | palette.muted |
| `outline`, `outlineVariant` | palette.outline |
| `error` / `onError` | koyu temalarda `Color(0xFFFF6B6B)` / `Color(0xFF1A0000)`, açık temada `Color(0xFFC62828)` / `Colors.white` |

Ayrıca:

- `scaffoldBackgroundColor`: palette.background; `appBarTheme`: background, elevation 0, `scrolledUnderElevation: 0`,
  başlık `textTheme.headlineMedium`.
- **Metin teması** (`textTheme`), renkler onSurface; "muted" olanlar onSurfaceVariant:

| Stil | Font | Boyut | Kalınlık |
|---|---|---|---|
| `headlineMedium` (ekran başlığı) | Oswald | 26 | 500 |
| `titleLarge` (set değerleri: "60 kg × 10") | Oswald | 18 | 500 |
| `titleMedium` (kart başlığı, hareket adı) | Oswald | 18 | 500 |
| `bodyLarge`, `bodyMedium` (gövde) | Inter | 15 | 400 |
| `bodySmall` (yardımcı metin) | Inter | 13 | 400, muted |
| `labelLarge` (buton) | Inter | 15 | 500 |
| `labelMedium`, `labelSmall` (etiket) | Inter | 13 | 400, muted |

  Diğer tüm stiller Inter (`fontFamily: 'Inter'` ThemeData düzeyinde).
- `cardTheme`: renk palette.background, elevation 0, `margin: EdgeInsets.zero`, şekil yarıçap
  `AppSpacing.cardRadius`, kenarlık 1 px palette.outline.
- `filledButtonTheme`: arka plan primary, yazı onPrimary, yarıçap `AppSpacing.buttonRadius`,
  `minimumSize: Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget)`.
- `outlinedButtonTheme`: kenarlık outline, yazı onSurface, aynı yarıçap ve minimum boyut.
- `textButtonTheme`: yazı primary, aynı minimum boyut.
- `iconButtonTheme`: `minimumSize` minTouchTarget.
- `floatingActionButtonTheme`: primary / onPrimary, elevation 0, yuvarlak.
- `inputDecorationTheme`: `filled: true`, `fillColor` palette.surface, kenarlıksız, yarıçap 12; odaklanınca
  1.5 px primary kenarlık; ipucu metni muted.
- `chipTheme`: arka plan şeffaf, kenarlık 1 px outline, `StadiumBorder`, etiket `labelMedium` (muted);
  seçiliyken kenarlık ve etiket primary.
- `snackBarTheme`: arka plan palette.surface, içerik onSurface, aksiyon rengi primary, `behavior: floating`.
- `dividerTheme`: renk outline, kalınlık 1.
- `dialogTheme`: arka plan palette.surface, yarıçap 16.

## 4. `PrefsSettingsRepository implements SettingsRepository`

- `shared_preferences` paketinin klasik API'si: `SharedPreferences.getInstance()`.
- Anahtar: `'theme_id'`, değer `AppThemeId.name`. Okurken `AppThemeId.fromName(...)` kullan.

## 5. Testler

- `app_theme_test.dart`: her `AppThemeId` için `buildAppTheme` → `brightness`, `colorScheme.primary`,
  `scaffoldBackgroundColor`, `colorScheme.onSurfaceVariant` paletle aynı; `textTheme.headlineMedium!.fontFamily`
  `'Oswald'`, `bodyLarge!.fontFamily` `'Inter'`; filled buton minimum boyutu 48.
- `prefs_settings_repository_test.dart`: `SharedPreferences.setMockInitialValues({})` ile
  (1) boşken varsayılan tema, (2) kaydet → oku aynı tema, (3) kayıtlı değer tanınmıyorsa varsayılan.

## Bitti sayılması için

- `flutter analyze lib/ui/core/theme lib/data/repositories test/ui test/data/repositories/prefs_settings_repository_test.dart` temiz
- `flutter test test/ui/core/theme test/data/repositories/prefs_settings_repository_test.dart` tamamen geçiyor
