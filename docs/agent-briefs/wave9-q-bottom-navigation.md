# Dalga 9 – Ajan Q: Alt gezinme çubuğu (#13)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil) ve `docs/ARCHITECTURE.md` §8 ile §13.
Bu dalgada iki ajan daha çalışıyor: biri `lib/ui/profile/` (profil ekranı), diğeri yedekleme (`lib/data/backup/`,
`lib/ui/settings/`). Listende olmayan dosyaya dokunma.

## Amaç

Uygulamanın kökü artık tek ekran değil, alt gezinme çubuklu bir kabuk:

| Sekme | Etiket | İkon | Ekran |
|---|---|---|---|
| 0 | Antrenmanlar | `Icons.fitness_center` | `HistoryScreen()` |
| 1 | Hareketler | `Icons.insights_outlined` (seçiliyken `Icons.insights`) | `ExercisesScreen()` |
| 2 | Profil | `Icons.person_outline` (seçiliyken `Icons.person`) | `ProfileScreen()` |

`ProfileScreen` (`lib/ui/profile/profile_screen.dart`) iskelet olarak hazır; başka bir ajan dolduruyor.
Sen yalnızca `const ProfileScreen()` olarak kullan, dosyasını **değiştirme**.

## Dokunabileceğin dosyalar

- `lib/ui/app_shell.dart` (yeni)
- `test/ui/app_shell_test.dart` (yeni)
- `lib/main.dart` (yalnızca `home:`)
- `test/widget_test.dart`
- `lib/ui/history/history_screen.dart`
- `test/ui/history/history_screen_test.dart`
- `lib/ui/exercises/exercises_screen.dart`
- `test/ui/exercises/exercises_screen_test.dart`

## 1. `AppShell` (`lib/ui/app_shell.dart`)

- `StatefulWidget`; Material 3 `NavigationBar` (renkler temadan, sabit renk yok).
- **Her sekmenin kendi gezinme yığını:** her sekme bir `Navigator` (kendi `GlobalKey<NavigatorState>`'iyle) içinde;
  sekmeler `IndexedStack` ile tutulur. Sekme değiştirip geri gelince ekran ve kaydırma konumu korunur
  (örn. Hareketler'de bir hareketin detayı açıkken Profil'e geçip dönünce detay hâlâ açık).
- Aktif sekmeye tekrar dokunmak o sekmenin yığınını köke döndürür (`popUntil(first)`).
- **Geri tuşu** (`PopScope`): önce aktif sekmenin yığınında geri gider; yığın kökteyse ve aktif sekme 0 değilse
  sekme 0'a döner; sekme 0'ın kökündeyse uygulama kapanır (normal davranış).

## 2. Tam ekran açılan sayfalar

Antrenman ekranı ve Ayarlar **alt çubuğun üstünü kaplasın** (antrenman sırasında çubuk yer kaplamasın):
`HistoryScreen` bu ikisini `Navigator.of(context, rootNavigator: true).push(...)` ile açar. Dönüşteki
yenileme davranışları aynen kalır. Hareket detay ekranı (Hareketler sekmesinden) sekmenin kendi yığınında açılır.

## 3. Mevcut ekranlardaki değişiklikler

- `HistoryScreen`: AppBar'daki **Hareketler simgesini kaldır** (artık sekme); Ayarlar simgesi kalır.
- `ExercisesScreen`: sekme kökü olduğu için AppBar'da geri oku olmamalı (kendiliğinden olur; kontrol et).
- `main.dart`: `home: const AppShell()`.

## 4. Testler

- `app_shell_test.dart`: üç sekme etiketi görünür; Hareketler'e dokununca `ExercisesScreen`, Profil'e dokununca
  `ProfileScreen` görünür; Hareketler'de bir hareketin detayını açıp Profil'e geçip geri dönünce detay hâlâ açık;
  aynı sekmeye tekrar dokununca köke döner; antrenman başlatınca `WorkoutScreen` açıkken `NavigationBar`
  görünmez (tam ekran). Provider'lar için `FakeWorkoutRepository` ve `FakeMeasurementRepository` kullan.
- Geçmiş ekranı testinden Hareketler simgesi testini kaldır/güncelle; diğerleri bozulmamalı.
- 360 × 780, yazı 1.3'te alt çubuk taşmaz.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
