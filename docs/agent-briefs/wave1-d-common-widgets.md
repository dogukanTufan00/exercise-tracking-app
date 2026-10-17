# Dalga 1 – Ajan D: Ortak bileşenler + biçimlendiriciler

Önce [ortak kuralları](README.md) oku.

## Dokunabileceğin dosyalar (yalnızca bunlar, hepsi yeni)

- `lib/ui/core/formatters.dart`
- `lib/ui/core/widgets/number_stepper.dart`
- `lib/ui/core/widgets/muscle_group_chip.dart`
- `lib/ui/core/widgets/empty_state.dart`
- `test/ui/core/formatters_test.dart`
- `test/ui/core/widgets/number_stepper_test.dart`
- `test/ui/core/widgets/muscle_group_chip_test.dart`
- `test/ui/core/widgets/empty_state_test.dart`

Uygulamanın teması başka bir ajan tarafından aynı anda yazılıyor. Bu yüzden **renk ve yazı stillerini yalnızca**
`Theme.of(context).colorScheme` ve `Theme.of(context).textTheme` üzerinden al; hiçbir yerde `Color(...)`,
`Colors.xxx`, `fontSize` ya da `fontFamily` yazma. Boşluk/boyutlar için `AppSpacing` (`lib/ui/core/theme/app_spacing.dart`).
Kullanılacak rol adları:

| Ne | Nereden |
|---|---|
| Normal metin / ikon | `colorScheme.onSurface` |
| Soluk metin | `colorScheme.onSurfaceVariant` |
| Vurgu (seçili, aktif) | `colorScheme.primary` |
| İnce kenarlık | `colorScheme.outline` |
| Giriş alanı / kutu dolgusu | `colorScheme.surfaceContainerHighest` |
| Sayı (stepper değeri) | `textTheme.titleLarge` |
| Başlık (boş durum) | `textTheme.titleMedium` |
| Etiket | `textTheme.labelMedium` |
| Yardımcı metin | `textTheme.bodySmall` |

## 1. `formatters.dart`

```dart
/// 60.0 → "60", 62.5 → "62,5", 62.25 → "62,25" (Türkçe ondalık virgül, en çok 2 basamak, gereksiz sıfır yok).
String formatWeight(double kg);

/// "60 kg × 10"
String formatSet(double weightKg, int reps);

/// DateTime(2026, 10, 17, 18, 30) → "17 Ekim 2026 · 18:30"
/// `intl` DateFormat('d MMMM y · HH:mm', 'tr') kullanır.
/// Uygulama başlarken bir kez `initializeDateFormatting('tr')` (package:intl/date_symbol_data_local.dart)
/// çağrılmış olmalıdır; bunu doküman yorumunda belirt.
String formatWorkoutDate(DateTime dateTime);

/// "62,5" veya "62.5" gibi kullanıcı girdisini double'a çevirir; geçersizse null. Boşlukları kırpar.
double? parseDecimal(String input);
```

Testte `setUpAll(() => initializeDateFormatting('tr'))`.

## 2. `NumberStepper` (StatelessWidget)

```dart
NumberStepper({
  super.key,
  required double value,
  required double step,          // ağırlık 2.5, tekrar 1
  required ValueChanged<double> onChanged,
  double min = 0,
  double? max,
  String? unit,                  // "kg" verilirse değerin yanında küçük yazılır
  required String label,         // ekran okuyucu ve diyalog başlığı, ör. "Ağırlık"
  bool allowDecimal = true,      // tekrar için false
})
```

Yatay düzen: `[ − ]  değer (birim)  [ + ]`; kutu dolgusu `surfaceContainerHighest`, yarıçap `AppSpacing.buttonRadius`.

- − ve + `IconButton` (`Icons.remove`, `Icons.add`), en az 48×48, `tooltip` "Azalt" / "Artır".
- Yeni değer `min`'in altına (ya da `max`'ın üstüne) düşecekse o buton **devre dışı** (`onPressed: null`).
- Kayan nokta hatalarına karşı yeni değeri 2 basamağa yuvarla (60.1 + 2.5 gibi durumlarda).
- Butona basınca `HapticFeedback.selectionClick()` ve `onChanged(yeniDeğer)`.
- Değer `formatWeight` ile gösterilir.
- **Değere dokununca** bir `AlertDialog` açılır: başlık `label`, sayı klavyeli `TextField`
  (`allowDecimal` false ise `TextInputType.number`, değilse `numberWithOptions(decimal: true)`), mevcut değerle dolu
  ve tümü seçili; "İptal" ve "Tamam" butonları. Girdi `parseDecimal` ile okunur; geçersizse, aralık dışındaysa ya da
  `allowDecimal` false iken ondalıklıysa `TextField` altında `errorText` gösterilir ve diyalog kapanmaz.
  Geçerliyse `onChanged` çağrılır ve diyalog kapanır.
- `Semantics(label: label, value: ...)` ile sar.

## 3. `MuscleGroupChip` (StatelessWidget)

```dart
MuscleGroupChip({super.key, required MuscleGroup group, bool selected = false, VoidCallback? onTap})
```

- Hap şeklinde (`StadiumBorder`), 1 px kenarlık, `group.label` metni `labelMedium`.
- Seçili değilken kenarlık `outline`, metin `onSurfaceVariant`; seçiliyken ikisi de `primary`.
- `onTap` null ise sadece görsel etiket. Doluysa `InkWell` ile dokunulabilir ve dokunma alanı en az 48 yükseklik
  (görsel hap daha küçük kalabilir; dikey boşlukla tamamla). `Semantics(button: true, selected: selected)`.

## 4. `EmptyState` (StatelessWidget)

```dart
EmptyState({super.key, required IconData icon, required String title, required String message,
  String? actionLabel, VoidCallback? onAction})
```

- Ortalanmış sütun: 48 boyutunda ikon (`onSurfaceVariant`), başlık `titleMedium`, mesaj `bodySmall` ortalı,
  `actionLabel` ve `onAction` ikisi de varsa `FilledButton`. Elemanlar arası `AppSpacing` değerleri.

## 5. Testler

Widget testlerinde bileşeni `MaterialApp(theme: ThemeData(useMaterial3: true), home: Scaffold(body: ...))` ile sar
(tema ajanının dosyalarını kullanma).

- `formatters_test.dart`: `formatWeight` (60, 62.5, 62.25, 0), `formatSet`, `formatWorkoutDate`
  (Ekim ayı adı Türkçe), `parseDecimal` ("62,5", "62.5", " 10 ", "abc", "").
- `number_stepper_test.dart`: + ve − doğru değerle `onChanged` çağırır; `min`'de − devre dışı; değere dokununca
  diyalog açılır, "70,5" girip Tamam → `onChanged(70.5)`; geçersiz girdide hata metni görünür ve diyalog açık kalır;
  `allowDecimal: false` iken "8,5" reddedilir.
- `muscle_group_chip_test.dart`: etiketi gösterir; dokununca `onTap` çağrılır; `onTap` yokken dokunulabilir değil.
- `empty_state_test.dart`: başlık ve mesajı gösterir; buton yalnızca etiket + callback verilince görünür ve çalışır.

## Bitti sayılması için

- `flutter analyze lib/ui/core test/ui/core` temiz (tema ajanının dosyaları henüz yoksa sadece kendi dosyalarını analiz et)
- `flutter test test/ui/core/formatters_test.dart test/ui/core/widgets` tamamen geçiyor
