# Dalga 13 – Ajan AA: Telefonda saat eşlemesi, Dart tarafı (#24)

Önce [ortak kuralları](README.md) oku, sonra `docs/ARCHITECTURE.md` §15'in **tamamını** (protokol ve kurallar oradadır).
Bu dalgada aynı anda üç ajan daha çalışıyor (AB: telefonun Kotlin köprüsü, AC/AD: saat uygulaması); onların dosyalarına
(`android/`, `wear/`) dokunma.

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)

- `lib/data/watch/watch_protocol.dart`: protokol modelleri ve JSON (tam yazılı).
- `lib/data/watch/wear_channel.dart`: `WearChannel` arayüzü ve gerçek `MethodChannelWearChannel` (tam yazılı).
- `lib/data/watch/watch_sync_store.dart`: `WatchSyncStore` arayüzü ve `PrefsWatchSyncStore` (tam yazılı).
- `lib/data/watch/watch_sync_service.dart`: `WatchSyncService` iskeleti. Kurucu ve public imzalar sabittir;
  gövdeleri sen yazarsın (private alan/metot ekleyebilirsin).

## Dokunabileceğin dosyalar

- `lib/domain/set_draft.dart` (yeni)
- `lib/data/watch/watch_snapshot_builder.dart` (yeni)
- `lib/data/watch/watch_sync_service.dart` (yalnızca gövdeler + private üyeler)
- `lib/ui/workout/workout_view_model.dart`, `lib/ui/workout/workout_screen.dart`, `lib/ui/workout/widgets/exercise_card.dart` (yalnızca import)
- `lib/main.dart`
- `test/fakes/fake_wear_channel.dart`, `test/fakes/fake_watch_sync_store.dart` (yeni)
- `test/domain/set_draft_test.dart`, `test/data/watch/watch_protocol_test.dart`,
  `test/data/watch/watch_snapshot_builder_test.dart`, `test/data/watch/watch_sync_service_test.dart` (yeni)
- `test/ui/workout/workout_view_model_test.dart` (yalnızca yeni testler ekle), `test/widget_test.dart` (gerekirse)

## 1. Taslak kuralını alana taşı (`lib/domain/set_draft.dart`)

`WorkoutViewModel` içindeki `SetDraft` sınıfını ve `_initialDraftFor` kuralını **davranışı değiştirmeden** saf Dart'a taşı:

```dart
class SetDraft { const SetDraft({required this.weightKg, required this.reps}); final double weightKg; final int reps; }
const SetDraft defaultSetDraft = SetDraft(weightKg: 20, reps: 10);
/// Kural: bu antrenmandaki son set; yoksa hedef (…); yoksa "geçen sefer"in ilk seti; yoksa defaultSetDraft.
SetDraft initialSetDraft(WorkoutExerciseDetail entry, List<ExerciseSet> previousSets);
```

ViewModel bunu kullanır; `SetDraft`'ı kullanan dosyalar import'u günceller. Mevcut tüm testler değişmeden geçmeli.
Kuralın tüm dallarını `test/domain/set_draft_test.dart`'ta sına.

## 2. Anlık durum (`lib/data/watch/watch_snapshot_builder.dart`)

```dart
/// Antrenman yoksa null. exercises position sırasıyla; draft = initialSetDraft(entry, previous);
/// previous = repository.getPreviousSets(exerciseId, beforeWorkoutId: workoutId);
/// title = workout.title ?? fallbackTitle(startedAt).
Future<WatchSnapshot?> buildWatchSnapshot(
  WorkoutRepository repository,
  int workoutId, {
  required List<String> appliedEventIds,
  required String Function(DateTime startedAt) fallbackTitle,
});
```

## 3. `WatchSyncService` gövdeleri

ARCHITECTURE §15.3–15.5'teki kurallar. Ayrıntılar:

- `start()`: `channel.eventsAvailable`'ı dinle (her değerde `processPendingEvents()`), sonra `processPendingEvents()`,
  sonra etkin antrenmanı yeniden yayınla.
- **Yayınlama** (`_republish`): etkin id yoksa `clearSnapshot()`. Antrenman yoksa ya da `startedAt`, `clock()`'tan
  `activeWorkoutMaxAge`'den daha eskiyse etkin id'yi temizle + `clearSnapshot()`. Değilse `buildWatchSnapshot`
  (`appliedEventIds` = işlenmiş id'lerin son `maxAppliedEventIds` tanesi) → `jsonEncode` → `publishSnapshot`.
- `setActiveWorkout(id)`: saklar, yayınlar. `workoutChanged(id)`: yalnızca etkin antrenmansa yayınlar.
- `processPendingEvents()`: tek seferde bir çalışır (önceki çağrının `Future`'ını zincirle). `drainEvents()` metinlerini
  sırayla işle:
  - `jsonDecode` / `WatchEvent.fromJson` hatası → ham JSON'da `eventId` metni varsa onu onayla (ack), yoksa atla.
  - `protocol != watchProtocolVersion`, zaten işlenmiş id, etkin olmayan antrenman, hareket/set bu antrenmanda yok,
    `weightKg < 0` ya da `reps <= 0`, repository hatası → **işlenmiş say, uygulama**.
  - `AddSetEvent` → `repository.addSet`; `DeleteSetEvent` → `repository.deleteSet` (set bu antrenmana aitse).
  - Sonunda: işlenmiş id listesini sakla (eskiden yeniye, son `maxProcessedEventIds`), `ackEvents` (işlenen + zaten
    işlenmiş olanların hepsi), en az bir olay işlendiyse yeniden yayınla, değişen antrenman id'lerini `workoutUpdates`'e yay.
- `workoutUpdates`: `StreamController<int>.broadcast()`. `dispose()`: aboneliği ve controller'ı kapat.
- Hiçbir public metot hata fırlatmaz (yakala, `debugPrint`). `package:flutter/foundation.dart` dışında Flutter import etme.

## 4. Uygulamaya bağla

- `WorkoutViewModel`: isteğe bağlı isimli parametre `WatchSyncService? watchSync` (mevcut testler kırılmasın).
  `load()` başarılıysa `watchSync?.setActiveWorkout(id)`; değiştirici her işlem (`_run` başarılı bittiğinde)
  `watchSync?.workoutChanged(id)` (beklemeden, `unawaited`). `workoutUpdates`'ten kendi id'si gelince `_reload()`
  (bu yol `workoutChanged` ÇAĞIRMAZ, döngü olmasın). `dispose()`'ta aboneliği iptal et.
- `WorkoutScreen`: servisi sağlayıcıdan al; sağlayıcı yoksa (testler) `null` geç
  (`ProviderNotFoundException`'ı yakalayan küçük bir yardımcı).
- `main.dart`: `WatchSyncService(repository: workoutRepository, channel: MethodChannelWearChannel(),
  store: PrefsWatchSyncStore(), fallbackTitle: formatWorkoutDate)`; `unawaited(start())`;
  `ExerciseTrackerApp`'e isteğe bağlı `WatchSyncService? watchSyncService`; varsa `Provider<WatchSyncService>.value`.

## 5. Testler

- Protokol: örnek JSON'lar (ARCHITECTURE §15.4) okunur ve aynen yazılır; `target: null`, boş listeler; bilinmeyen `type` → `FormatException`.
- Builder: sıra, taslak, previous, başlıksız antrenmanda `fallbackTitle`, olmayan antrenman → null.
- Servis (`FakeWorkoutRepository` + sahte kanal/depo + sabit `clock`): set ekleme/silme; aynı olay iki kez → bir set;
  başka antrenman/olmayan hareket/geçersiz değer/eski protokol/bozuk JSON → uygulanmaz ama ack'lenir; 12 saat kuralı;
  etkin olmayan antrenmanda `workoutChanged` yayınlamaz; `appliedEventIds` en fazla 50; işlenmiş liste en fazla 200;
  `workoutUpdates` doğru id'yi yayar; `eventsAvailable` tetiklenince işler; eşzamanlı iki `processPendingEvents` → set bir kez.
- ViewModel: yükleyince etkin olur; set ekleyince `workoutChanged`; servis güncelleme yayınca detay yenilenir.

## Bitti sayılması için

- `flutter analyze lib test` temiz, `flutter test` (tüm testler) tamamen geçiyor (`--timeout 120s` kullan).
