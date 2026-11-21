# Dalga 15 – Ajan BC: Saatin veri katmanı, Faz 2 (#25)

Önce [ortak kuralları](README.md) (Kotlin bölümü) oku, sonra `docs/ARCHITECTURE.md` §15 (özellikle §15.6 ve **§15.8**).
Aynı anda çalışanlar: BA (`lib/`, `android/`), BD (`ui/`, `MainActivity.kt`), BE (`session/`, `tile/`, `WatchApp.kt`, manifest).

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

`wear/app/src/main/java/com/dogukantufan00/exercise_tracking_app/`:
- `data/WatchProtocol.kt`: `WatchEvent`'te artık `workoutId` yok (yalnızca `AddSetEvent`/`DeleteSetEvent`'te);
  yeni `StartWorkoutEvent`, `WatchProgram`, `WatchProgramDay`, `WatchApplied`, `PROGRAM_PATH`, `APPLIED_PATH`.
- `data/WorkoutSyncRepository.kt`: yeni `program`, `pendingStart`, `startWorkout`, `cancelPendingStart`, `PendingStart`.
- `domain/ProgramSchedule.kt`: `suggestedDay` (gövdeyi sen yazarsın).

## Dokunabileceğin dosyalar (`wear/app/src/` altında)

- `main/.../data/PhoneSyncRepository.kt`, `main/.../data/PendingEventStore.kt`
- `main/.../domain/DisplayWorkout.kt` (yalnızca `mergeOptimistic` gövdesi), `main/.../domain/ProgramSchedule.kt` (gövde)
- `main/.../ui/preview/WatchPreviews.kt` (yalnızca sahte repository'yi yeni arayüze uydurmak için)
- `test/java/.../domain/MergeOptimisticTest.kt`, `test/java/.../data/WatchProtocolTest.kt`,
  `test/java/.../domain/ProgramScheduleTest.kt` (yeni)

## İstenenler

1. **Protokol uyarlaması:** `mergeOptimistic` ve budama, `workoutId`'yi yalnızca set olaylarında kullanır;
   `StartWorkoutEvent` iyimser durumu değiştirmez.
2. **Program:** `/program/active` DataItem'ını açılışta oku, dinle (`TYPE_DELETED` → null, bozuk/farklı protokol → öncekini
   koru) → `program: StateFlow<WatchProgram?>`. Anlık durumdaki desenin aynısı.
3. **İşlenmiş olaylar:** `/events/applied` DataItem'ını da oku ve dinle; bekleyen olayları **hem** anlık durumun
   `appliedEventIds`'i **hem** bununla buda. Budama kuralı: id'si uygulanmışlar silinir; set olaylarından anlık durumun
   `workoutId`'sine ait olmayanlar (anlık durum varsa) silinir; `StartWorkoutEvent` yalnızca uygulanınca ya da iptal edilince silinir.
4. **Başlatma:** `startWorkout(dayId)`: kuyrukta bekleyen `StartWorkoutEvent` varsa onu sil; yenisini ekle; `flush()`.
   `pendingStart` = kuyruktaki `StartWorkoutEvent` (en fazla bir) → `PendingStart(eventId, programDayId, dayName)`;
   `dayName` programdaki günün adı (bulunamazsa null; null gün = boş antrenman). `cancelPendingStart()`: kuyruktan siler.
5. `suggestedDay`: telefondaki kuralla aynı (doc yorumunda). JVM testi: pazartesi günü olan, olmayan, `null` weekday'ler, ilk eşleşen.
6. Testler: protokol (`startWorkout` JSON alan adları Dart'la aynı: `type`, `programDayId`; `workoutId` yok; `WatchProgram`
   ve `WatchApplied` gidiş-dönüş); `mergeOptimistic` güncel testleri.

## Doğrulama

`wear/` içinde `.\gradlew.bat testDebugUnitTest --offline --console=plain` ve `assembleDebug --offline`. BD/BE'nin dosyaları yarım
olabilir; derleme hatası yalnızca onların dosyalarındaysa raporda belirt, düzeltme.
