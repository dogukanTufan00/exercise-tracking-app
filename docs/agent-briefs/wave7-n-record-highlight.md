# Dalga 7 – Ajan N: Antrenmanda rekor vurgusu (#8)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil) ve `docs/ARCHITECTURE.md` §12'yi (ilerleme ve
rekorlar). Bu görev mevcut kodu **değiştirir**; önce ilgili dosyaları baştan sona oku. Repository arayüzü ve
modeller **değişmez**; gereken her şey mevcut `getExerciseHistory` ve `lib/domain/progress.dart` ile yapılır.

## Amaç

Antrenman sırasında eklenen ya da düzenlenen bir set, o hareketin **önceki antrenmanlardaki** en iyisini geçerse:
setin satırında 🏆 rozeti görünür, hafif titreşim olur ve "Yeni rekor" SnackBar'ı çıkar.

## Dokunabileceğin dosyalar

- `lib/domain/progress.dart` (yalnızca yeni fonksiyon)
- `test/domain/progress_test.dart`
- `lib/ui/workout/workout_view_model.dart`
- `lib/ui/workout/workout_screen.dart`
- `lib/ui/workout/widgets/exercise_card.dart`
- `test/ui/workout/workout_view_model_test.dart`
- `test/ui/workout/workout_screen_test.dart`

## 1. Kural (`lib/domain/progress.dart`)

```dart
/// [set], [previous] rekorlarını (bu antrenmandan **önceki** antrenmanlardan hesaplanmış) geçiyor mu?
///
/// - Önceki kayıt yoksa (`previous` boş) hiçbir set rekor değildir: ilk kez yapılan hareketin
///   her seti "rekor" sayılmasın.
/// - Ağırlıklı set: ağırlık `previous.heaviest`'ı **ya da** tahmini 1RM `previous.bestEstimatedOneRepMax`'i
///   kesin olarak (>) geçerse rekordur.
/// - Ağırlıksız set (0 kg), önceki geçmiş de ağırlıksızsa (`previous.heaviest == null`):
///   tekrar `previous.mostReps`'i kesin olarak geçerse rekordur.
bool isPersonalRecord(ExerciseSet set, PersonalRecords previous);
```

"Boş" = dört rekorun hepsi `null`. Eşit değer rekor değildir.

Testler: geçmiş yok → hayır; daha ağır → evet; aynı ağırlık ama daha yüksek 1RM (daha çok tekrar) → evet;
eşit → hayır; daha hafif ve düşük 1RM → hayır; ağırlıksız geçmişte daha çok tekrar → evet, eşit tekrar → hayır;
ağırlıklı geçmişi olan harekette 0 kg set → hayır.

## 2. ViewModel (`WorkoutViewModel`)

- Her hareket için **bu antrenmandan önce başlamış** antrenmanlardan hesaplanan rekorları tut:
  `Map<int, PersonalRecords> _previousRecords` (anahtar: `exerciseId`). `_reloadAll` içinde, "geçen sefer"
  setleriyle birlikte doldur: `getExerciseHistory(exerciseId)` → `startedAt` bu antrenmanın `startedAt`'inden
  **kesin önce** olan oturumlar → `PersonalRecords.fromHistory(...)`. Bu antrenmanın setleri karşılaştırmaya
  **katılmaz**; böylece aynı antrenmanda birden çok set rekor olabilir ve birbirini "silmez".
  Yeni eklenen hareket için de (`addExercise` → `_reloadAll` zaten çağrılıyorsa) doldurulur; kontrol et.
- Public:
  ```dart
  /// Set, hareketin önceki antrenmanlardaki rekorlarını geçiyor mu?
  bool isRecordSet(int exerciseId, ExerciseSet set);
  ```
- **Tek seferlik olay:** `addSet`, `repeatLastSet` ve `updateSet` başarıyla bittikten sonra, eklenen/düzenlenen set
  rekorsa:
  ```dart
  /// Ekranın bir kez göstermesi gereken rekor bildirimi (ör. "Yeni rekor: 62,5 kg × 8"); yoksa null.
  String? get pendingRecordMessage;
  void clearPendingRecord();
  ```
  Mesaj: `'Yeni rekor: ${formatSet(kg, reps)}'` (`lib/ui/core/formatters.dart`; ViewModel bu dosyayı import
  edebilir, Flutter widget'ı değil). Yükleme (`load`) bildirim üretmez; düzenlenen set rekor değilse de üretmez.
  Eklenen set: `_reload` sonrası ilgili hareketin **son** seti. Düzenlenen set: aynı `id`'li set.

## 3. Ekran ve kart

- `workout_screen.dart`: hata SnackBar'ıyla aynı desende `pendingRecordMessage` gösterilir (post-frame,
  `clearPendingRecord()`, `hideCurrentSnackBar`), ayrıca `HapticFeedback.mediumImpact()`.
  SnackBar içeriği: `Row` içinde `Icon(Icons.emoji_events)` + mesaj; renkler temadan.
- `ExerciseCard`'a yeni parametre: `required bool Function(ExerciseSet set) isRecordSet`. Ekran
  `(set) => vm.isRecordSet(entry.exercise.id, set)` geçer.
- `_SetRow`: rekor setin sağında, silme butonundan önce `Icon(Icons.emoji_events, color: colorScheme.primary)`
  (boyutu metin boyutuna yakın; sabit sayı yerine `IconTheme`/varsayılan kullanılabilir), `Semantics(label: 'Kişisel rekor')`.
  Rozet satırı taşırmamalı (360 dp, yazı 1.3).
- Kapalı kart özetine dokunma.

## 4. Testler (yukarıdakilere ek)

- ViewModel (`FakeWorkoutRepository`, tarihli antrenmanlar):
  - Önceki antrenmanda 60 × 10 varken 62,5 × 8 eklemek → `pendingRecordMessage == 'Yeni rekor: 62,5 kg × 8'`,
    `isRecordSet` true.
  - 50 × 10 eklemek → mesaj yok, `isRecordSet` false.
  - İlk kez yapılan hareket → hiçbir set rekor değil.
  - Aynı antrenmanda iki rekor set → ikisi de `isRecordSet` true.
  - **Sonraki** tarihli bir antrenmandaki daha ağır set, bu antrenmandaki seti rekor olmaktan çıkarmaz
    (yalnızca öncekiler sayılır).
  - `updateSet` ile rekor değerine çıkarmak → mesaj; `load` → mesaj yok; `clearPendingRecord` temizler.
- Ekran: rekor set eklenince "Yeni rekor" SnackBar'ı ve `find.bySemanticsLabel('Kişisel rekor')`
  (semantics için `tester.ensureSemantics()` kullan ve testin sonunda `dispose()` et — `addTearDown` değil);
  rekor olmayan sette rozet yok; 360 × 780, yazı 1.3'te rozetli satır taşmıyor.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
