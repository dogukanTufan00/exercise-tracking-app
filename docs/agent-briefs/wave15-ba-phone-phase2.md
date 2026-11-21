# Dalga 15 – Ajan BA: Telefon tarafı, Faz 2 (#25)

Önce [ortak kuralları](README.md) (Kotlin bölümü dahil) oku, sonra `docs/ARCHITECTURE.md` §15'in tamamını (özellikle §15.4,
§15.5 ve **§15.8**). Aynı anda üç ajan `wear/` içinde çalışıyor; `wear/`'e dokunma.

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

- `lib/data/watch/watch_protocol.dart`: `workoutId` artık yalnızca `AddSetEvent`/`DeleteSetEvent`'te; yeni
  `StartWorkoutEvent(programDayId: int?)`, `WatchProgram`, `WatchProgramDay`, `watchProgramPath`, `watchAppliedPath`.
- `lib/data/watch/wear_channel.dart`: yeni `publishProgram`, `clearProgram`, `publishApplied`.
- `WatchSyncService`: kurucuya `programRepository` eklendi; yeni `programChanged()` ve `activeWorkoutChanged()` iskeletleri.

## Dokunabileceğin dosyalar

- `lib/data/watch/watch_sync_service.dart` (gövdeler + private üyeler; public imzalar sabit)
- `lib/data/watch/watch_aware_workout_repository.dart`, `lib/data/watch/watch_aware_program_repository.dart` (yeni)
- `lib/main.dart`
- `lib/ui/workout/workout_view_model.dart`, `lib/ui/history/history_view_model.dart`, `lib/ui/history/history_screen.dart`
  (yalnızca elle `workoutChanged` çağrılarını kaldırmak için; bkz. 3)
- `test/fakes/fake_wear_channel.dart` ve `test/` altındaki saat testleri + bu değişikliklerin kırdığı testler
- `android/app/src/main/kotlin/com/dogukantufan00/exercise_tracking_app/MainActivity.kt`

## 1. `WatchSyncService`

- Protokol değişikliğine uyarla (`event.workoutId` yalnızca set olaylarında).
- **`StartWorkoutEvent`**: `createdAt` `clock()`'tan 12 saatten eskiyse yok say. `programDayId` varsa
  `programRepository.startWorkoutFromDay(id, startedAt: createdAt)` (gün yoksa `ArgumentError` → yok say), `null` ise
  `repository.createWorkout(startedAt: createdAt)`. Sonra yeni antrenman etkin olur (store) ve yayınlanır; id
  `workoutUpdates`'e de yayılır. Etkin antrenman olmasa da işlenir (set olaylarının aksine).
- **`programChanged()`**: `programRepository.getActiveProgramDetail()`; yoksa `clearProgram()`, varsa `WatchProgram`
  (günler `position` sırasıyla; `exercises` = gün hareketlerinin adları sırasıyla) → `jsonEncode` → `publishProgram`.
  `start()` bir kez çağırır.
- **`/events/applied`**: her olay işleme turunda en az bir yeni olay işlendiyse, ayrıca `start()`'ta,
  `{"protocol": 1, "appliedEventIds": [son 50]}` → `publishApplied`.
- Hiçbir public metot hata fırlatmaz.

## 2. Repository sarmalayıcıları (§15.8 madde 2)

`class WatchAwareWorkoutRepository implements WorkoutRepository` (kurucu: iç repository + `WatchSyncService`):
tüm metotları içe iletir; **değiştirici** her çağrı başarıyla bittikten sonra servise haber verir (beklemeden, `unawaited`):
- Antrenman id'si doğrudan bilinen çağrılar (`updateWorkoutTitle`, `deleteWorkout`, `addExerciseToWorkout`) →
  `workoutChanged(id)`.
- Geri kalan tüm değiştirici çağrılar (alt kayıt id'si alanlar: not, hareket kaldır/değiştir, set ekle/güncelle/sil;
  katalog: `updateExercise`, `mergeExercises`; yedekten geri yükleme) → `activeWorkoutChanged()` (sözleşmede hazır:
  etkin antrenmanı koşulsuz yeniden yayınlar). `createExercise` ve okuma metotları → hiçbir şey.

`class WatchAwareProgramRepository implements ProgramRepository`: değiştirici her çağrıdan sonra `programChanged()`;
`startWorkoutFromDay` sonrası ayrıca hiçbir şey (etkinliği Antrenman ekranı belirler). Okuma metotları yalnızca iletir.

`main.dart`: servis **sarılmamış** repository'lerle kurulur; sağlayıcılara (`Provider<WorkoutRepository>`,
`Provider<ProgramRepository>`) **sarılmış** olanlar verilir.

## 3. Elle çağrıları kaldır

`WorkoutViewModel` içindeki `_run` sonrası `workoutChanged` çağrısı ve `HistoryViewModel`'in silme sonrası çağrısı
artık sarmalayıcıda; kaldır (çift yayın olmasın). `setActiveWorkout` (yükleme) ve `workoutUpdates` dinlemesi KALIR.
`HistoryViewModel`'in `watchSync` parametresi gereksizse kaldır ve ilgili testi sarmalayıcı testine taşı.

## 4. Kotlin (`MainActivity.kt`)

`publishProgram(String)` → `/program/active`, `clearProgram` → silme, `publishApplied(String)` → `/events/applied`;
mevcut `publishSnapshot` / `clearSnapshot` deseniyle aynı (DataMap `json` anahtarı, `setUrgent`, hata yalnızca `Log.w`).

## 5. Testler

Protokol (yeni olay ve program JSON gidiş-dönüş, `workoutId`'siz başlatma); servis (günden başlatma, boş başlatma, silinmiş
gün, 12 saatten eski olay, aynı başlatma iki kez → tek antrenman, başlatma sonrası etkin + yayın, `programChanged`
yayın/silme, `publishApplied` içeriği); iki sarmalayıcı (değiştirici çağrı → doğru yayın, okuma → yayın yok).

## Bitti sayılması için

`flutter analyze lib test` temiz; `flutter test --timeout 120s` tamamen geçiyor. `flutter build apk --debug` ile Kotlin
derlemesini dene; sandbox yüzünden ağ/dosya hatası verirse raporda yaz.
