# Dalga 10 – Ajan V: Sekmeye dönünce listeleri yenile (#17)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil) ve `lib/ui/app_shell.dart`'ı baştan sona.
Bu dalgada başka bir ajan aynı anda veri katmanında (`lib/data/`, `lib/main.dart`, `test/data/`, `test/fakes/`,
`test/widget_test.dart`) çalışıyor; listende olmayan dosyaya dokunma.

## Hata

Alt gezinme çubuğundan beri sekmeler `IndexedStack` içinde canlı kalıyor. Hareketler sekmesi kataloğu bir kez yükler;
antrenmanda oluşturulan ya da düzenlenen bir hareket, uygulama yeniden açılana kadar listede görünmez. Profil sekmesi
de aynı durumda: Ayarlar'dan yedek geri yüklenince yeni ölçümler görünmez.

## Dokunabileceğin dosyalar

- `lib/ui/app_shell.dart`
- `test/ui/app_shell_test.dart`
- `lib/ui/exercises/exercises_screen.dart`
- `test/ui/exercises/exercises_screen_test.dart`
- `lib/ui/profile/profile_screen.dart`
- `test/ui/profile/profile_screen_test.dart`

## Çözüm

1. `app_shell.dart`'ta sekmeleri sırayla değil adla tanımla (sonraki dalgada araya "Program" sekmesi eklenecek):
   ```dart
   /// Alt çubuğun sekmeleri; sıra [NavigationBar] sırasıdır.
   enum AppTab { workouts, exercises, profile }
   ```
2. `AppShell`, seçili sekmeyi alt ağaca bir `ValueListenable<AppTab>` olarak sağlar (ör.
   `ValueNotifier<AppTab>`; `Provider<ValueListenable<AppTab>>.value` ya da küçük bir `InheritedNotifier`).
   Ekranlar bunu `context` üzerinden bulur; bulamazsa (ekran tek başına test ediliyorsa) hiçbir şey yapmaz.
3. `ExercisesScreen`: kendi sekmesi (`AppTab.exercises`) yeniden seçildiğinde listeyi mevcut sorguyla yeniler
   (`search(query)`); yükleme göstergesi göstermeden (eski liste yenisi gelene kadar kalır). Detay ekranı açıkken
   (sekme yığını kökte değilken) de yenilemek sorun değil.
4. `ProfileScreen`: `AppTab.profile` seçildiğinde özetleri yükleme göstergesi olmadan yeniler (ViewModel'de böyle
   bir `refresh()` varsa onu kullan; yoksa ekle — `profile_view_model.dart` listende değil, bu yüzden yalnızca mevcut
   public metotlarla yap; gerekirse `load()` kullan).
5. Dinleyiciler `dispose`'da kaldırılır.

## Testler

- `app_shell_test.dart`: Antrenmanlar sekmesinde repository'ye doğrudan yeni bir hareket ekle (`FakeWorkoutRepository`),
  Hareketler sekmesine geç → yeni hareket listede. Benzer şekilde ölçüm ekle → Profil sekmesine geç → değer görünür.
- Mevcut testler bozulmamalı.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
