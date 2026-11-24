# Dalga 16b – Ajan CD: Telefon arayüzü — dinlenme şeridi, "Bitir", süre, ayarlar, yedek hatırlatması (#18, #22, #19)

Önce [ortak kuralları](README.md) (Dalga 2 ekran kuralları dahil), `docs/DESIGN.md` ve `docs/ARCHITECTURE.md` **§16**'yı oku.
Veri katmanı hazır ve test edilmiş (dalga 16a): bu dalgada yalnızca arayüz yazılır. Tek ajansın.

## Hazır olanlar (DEĞİŞTİRME, kullan)
- `RestController` (`lib/data/rest/rest_controller.dart`): `rest`, `restSeconds`, `vibrateOnPhone`, `start`, `adjust`, `skip`,
  `clearForWorkout`, `setRestSeconds`, `setVibrateOnPhone`, `clock`. `main.dart` onu `ChangeNotifierProvider<RestController>` ile sağlar;
  testlerde sağlayıcı olmayabilir.
- `lib/domain/rest_timer.dart`: `restRemainingSeconds`, `restRemainingFraction`, `restStepSeconds`, sınırlar.
- `Workout.finishedAt`, `WorkoutRepository.setWorkoutFinishedAt`; `WatchSyncService.activeWorkoutChanged`, `readWatchSync(context)`.
- `SettingsRepository`: `getLastBackupAt`/`setLastBackupAt`, `getBackupReminderDismissedAt`/`setBackupReminderDismissedAt`.
- Testler için `FakeWorkoutRepository`, `FakeSettingsRepository`, `FakeRestStore`, `FakeRestNotifier`.

## Dokunabileceğin dosyalar
- `lib/ui/core/rest_provider.dart` (yeni: `RestController? readRestController(BuildContext)` — `watch_sync_provider.dart` deseni)
- `lib/ui/core/formatters.dart` (+ `formatDuration`, `formatElapsed`, `formatRestClock`)
- `lib/ui/workout/workout_screen.dart`, `lib/ui/workout/workout_view_model.dart`, yeni `lib/ui/workout/widgets/rest_bar.dart`
- `lib/ui/history/history_screen.dart`, `lib/ui/history/history_view_model.dart`, yeni `lib/ui/history/widgets/backup_reminder_banner.dart`
  (ya da history klasöründe uygun bir dosya)
- `lib/ui/settings/settings_screen.dart`, `lib/ui/settings/backup_view_model.dart`
- `test/ui/...` altındaki ilgili testler (yeni + kırılanlar)

## 1. Biçimlendiriciler
- `formatDuration(Duration d)`: "45 dk", "1 sa", "1 sa 12 dk" (dakikaya aşağı yuvarla; 1 dk'dan kısa → "1 dk").
- `formatElapsed(Duration d)`: "42:13", bir saati geçince "1:02:13".
- `formatRestClock(int seconds)`: "1:30", "0:05".

## 2. Antrenman ekranı
- **Dinlenme başlatma:** `WorkoutViewModel` set başarıyla eklenince `RestController.start(workoutId)` çağırır (denetleyici kurucuya
  isteğe bağlı parametre olarak verilir; ekran `readRestController(context)` ile alır). Set düzenleme/silmede başlamaz.
- **Dinlenme şeridi (`RestBar`):** `RestController.rest` bu antrenmana aitse ekranın altında (Scaffold `bottomNavigationBar` ya da
  gövdenin altı) görünür: kalan süre büyük ve Oswald (`formatRestClock`), ince ilerleme çubuğu (`restRemainingFraction`),
  "−15", "+15" (`OutlinedButton`/`TextButton`) ve "Atla". Saniyede bir yenilenir (kendi `Timer.periodic`'i, dispose'da iptal);
  kalan süre `RestController.clock` ile hesaplanır. Saatte başlayan sayaç da burada görünür (aynı durum). Ekranda en fazla bir
  `FilledButton` kuralına uy (mevcut dolu düğme varsa şeritte dolu düğme kullanma).
- **Canlı süre:** antrenman bitirilmemiş ve `startedAt` 12 saatten yeniyse AppBar başlığının altında küçük `formatElapsed(now - startedAt)`
  (saniyede bir). Bitirilmişse `formatDuration(finishedAt - startedAt)` sabit gösterilir; eski (bitiş yok, 12 saatten eski) antrenmanda hiçbir şey.
- **"Bitir":** aynı koşulda (bitirilmemiş + 12 saatten yeni) AppBar'da metin düğmesi "Bitir". Onay diyaloğu: "Antrenmanı bitir?" /
  "Bitiş saati kaydedilecek." / "Vazgeç" – "Bitir". Onayda ViewModel: `setWorkoutFinishedAt(id, now)`, `restController?.clearForWorkout(id)`,
  sonra ekran `Navigator.pop`. (Repository saat sarmalayıcısı olduğu için saat kendiliğinden güncellenir.)
- Var olan `setActiveWorkout` çağrısı kalır; bitmiş antrenmanı etkin yapmama kuralı serviste.

## 3. Geçmiş ekranı
- Kartta `finishedAt` varsa süre (`formatDuration`), mevcut bilgi satırına " · 1 sa 12 dk" gibi eklenir.
- **Yedek hatırlatması (§16.4):** en az bir antrenman varsa ve (son yedek yok ya da 14 günden eski) ve (hiç kapatılmamış ya da 7 günden
  önce kapatılmış) ise listenin üstünde çerçeveli kart (DESIGN.md kart stili): "Henüz yedek almadın" ya da "Son yedeğin N gün önce",
  alt satır "Verilerin yalnızca bu telefonda.", düğmeler "Yedekle" (SettingsScreen'i açar, dönünce yeniden hesapla) ve kapat (×, `setBackupReminderDismissedAt(now)`).
  Hesap `HistoryViewModel`'de, `clock` enjekte edilebilir. `SettingsRepository` ekrana `context.read<SettingsRepository>()` ile gelir.

## 4. Ayarlar
- Yeni "Dinlenme" bölümü (mevcut bölüm başlığı stilinde): "Dinlenme süresi" satırı, sağda "−" / değer ("1:30") / "+" (15 sn adım, 15 sn – 10 dk),
  "Dinlenme bitince telefon da titresin" `SwitchListTile` (alt metin: "Saat her zaman titrer."). `RestController` yoksa bölüm gizlenir.
- `BackupViewModel.exportJson` başarıyla kaydedince `settings.setLastBackupAt(now)` (iptal/başarısızlıkta yazma). Kurucuya
  `SettingsRepository` gerekiyorsa ekle ve çağıranları güncelle.

## Testler (en az)
- Biçimlendiriciler; RestBar (kalan süre, +15/Atla çağrıları); "Bitir" görünürlüğü (yeni/eski/bitmiş) ve onay sonrası `finishedAt`;
  set ekleyince `start` çağrısı; Geçmiş'te süre metni; hatırlatma koşulları (yedek yok / 3 gün / 20 gün / yakında kapatılmış);
  Ayarlar'da süre adımı ve anahtar; başarılı JSON yedekte `lastBackupAt`.

## Doğrulama
`flutter analyze` → "No issues found!" ve `flutter test --timeout 60s` (tüm proje) geçmeli.
