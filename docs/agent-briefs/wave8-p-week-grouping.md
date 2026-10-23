# Dalga 8 – Ajan P: Geçmişi haftalara göre gruplama (#15)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil) ve `docs/ARCHITECTURE.md` §13.
Bu dalgada başka bir ajan aynı anda veri katmanında (`lib/data/`, `lib/main.dart`) çalışıyor; listende olmayan
dosyaya dokunma. Veri modeli ve repository **değişmez**: gruplama tarihlerden hesaplanır.

## Amaç

Antrenmanlar ekranındaki liste haftalara bölünür. Her haftanın üstünde bir başlık:
**"13–19 Ekim"** ve yanında soluk renkte **"3 antrenman · 48 set"**. Hafta **Pazartesi–Pazar**.

## Dokunabileceğin dosyalar

- `lib/domain/week_grouping.dart` (yeni)
- `test/domain/week_grouping_test.dart` (yeni)
- `lib/ui/core/formatters.dart` (yalnızca yeni fonksiyon)
- `test/ui/core/formatters_test.dart`
- `lib/ui/history/history_view_model.dart`
- `lib/ui/history/history_screen.dart`
- `test/ui/history/history_view_model_test.dart`
- `test/ui/history/history_screen_test.dart`

## 1. Gruplama (`lib/domain/week_grouping.dart`, saf Dart)

```dart
/// [date]'in haftasının Pazartesi günü, saat 00:00 (yerel).
/// `DateTime(y, m, d - (weekday - 1))` ile hesapla (gün ekleyerek değil: yaz saati geçişlerinde kayar).
DateTime startOfWeek(DateTime date);

/// Bir haftanın antrenmanları.
class WeekGroup {
  const WeekGroup({required this.weekStart, required this.workouts});
  final DateTime weekStart;            // Pazartesi 00:00
  final List<WorkoutSummary> workouts; // girdi sırası korunur (en yeni üstte)
  int get setCount;                    // workouts'un setCount toplamı
}

/// [workouts] en yeniden en eskiye sıralı gelir (repository böyle döndürür); gruplar da en yeni hafta önce.
/// Antrenmanı olmayan haftalar için grup oluşturulmaz.
List<WeekGroup> groupByWeek(List<WorkoutSummary> workouts);
```

Testler: Pazartesi/Pazar sınırı (Pazar 23:59 ile Pazartesi 00:00 farklı haftalarda), yıl dönümü haftası
(29 Aralık 2025 Pazartesi – 4 Ocak 2026), boş liste, sıra korunuyor, `setCount`.

## 2. Hafta başlığı metni (`lib/ui/core/formatters.dart`)

```dart
/// Pazartesi [weekStart] ile başlayan haftanın Türkçe aralığı:
/// aynı ay → "13–19 Ekim"; ay değişiyor → "29 Eyl – 5 Eki"; yıl değişiyor → "29 Ara 2025 – 4 Oca 2026".
/// Hafta [now]'ın yılında değilse (ve yıl değişmiyorsa) yıl eklenir: "13–19 Ekim 2025".
String formatWeekRange(DateTime weekStart, {DateTime? now});
```

`intl`'in `DateFormat(..., 'tr')` kalıplarını kullan (`d`, `MMMM`, `MMM`, `y`). Tire: aynı ayda "–" (boşluksuz),
farklı ayda " – " (boşluklu). Testler bu dört durumu kapsar (`now` vererek).

## 3. ViewModel ve ekran

- `HistoryViewModel`: `List<WeekGroup> get weeks` → `groupByWeek(workouts)`. `workouts` kalır.
- `history_screen.dart`: liste haftalara göre çizilir. Her grubun önünde başlık satırı:
  `formatWeekRange(weekStart)` (`titleSmall`) + boşluk + `"{n} antrenman · {setCount} set"` (`bodySmall`,
  `onSurfaceVariant`). Başlıklar kart değildir, dokunulmaz. Başlıkla kartlar arasında `AppSpacing.sm`, gruplar arasında
  `AppSpacing.lg` boşluk.
- Kart davranışları (dokun → aç, uzun bas → sil, sonra liste yenilenir) aynen kalır. Boş durum aynen kalır.
- Uzun listede performans için `ListView.builder` kullanmaya devam et (başlık ve kartları düz bir öğe listesine çevir).

## 4. Testler (yukarıdakilere ek)

- ViewModel: `weeks` farklı haftalardaki antrenmanları doğru gruplar.
- Ekran: iki farklı haftada antrenman → iki başlık ("13–19 Ekim" gibi) ve doğru sayılar; kartlara dokunma/silme
  testleri bozulmaz; 360 × 780, yazı 1.3'te başlık satırı taşmaz (gerekirse başlık metni alt satıra kayar).

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
