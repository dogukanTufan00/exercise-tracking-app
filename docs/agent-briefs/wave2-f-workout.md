# Dalga 2 – Ajan F: Antrenman ekranı

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil). Uygulamanın en önemli ekranı bu; salonda,
setler arasında, tek elle ve hızlı kullanılacak.

## Dokunabileceğin dosyalar

- `lib/ui/workout/workout_screen.dart` (iskeleti değiştir; kurucu `WorkoutScreen({super.key, required int workoutId})` aynı kalmalı)
- `lib/ui/workout/workout_view_model.dart` (yeni)
- `lib/ui/workout/widgets/` altında yeni dosyalar (ör. `exercise_card.dart`)
- `test/ui/workout/workout_view_model_test.dart` (yeni)
- `test/ui/workout/workout_screen_test.dart` (yeni)

`ExercisePickerScreen`'i başka bir ajan yazıyor; sadece import edip README'deki sözleşmeyle kullan.

## `WorkoutViewModel`

```dart
WorkoutViewModel(WorkoutRepository repository, int workoutId)
WorkoutDetail? get detail;           // yüklenene kadar null; antrenman silinmişse de null
bool get isLoading;
String? get errorMessage; void clearError();
String get title;                    // detail.workout.title ?? formatWorkoutDate(startedAt); detail yoksa ''
List<ExerciseSet> previousSetsFor(int exerciseId);   // "geçen sefer"; yoksa boş liste
SetDraft draftFor(int workoutExerciseId);            // bir sonraki setin ağırlık/tekrar taslağı

Future<void> load();                 // detayı ve her hareketin previousSets'ini yükler
Future<void> updateTitle(String? title);
Future<void> addExercise(Exercise exercise);
Future<void> removeExercise(int workoutExerciseId);
void setDraftWeight(int workoutExerciseId, double kg);
void setDraftReps(int workoutExerciseId, int reps);
Future<void> addSet(int workoutExerciseId);          // taslak değerleriyle
Future<void> repeatLastSet(int workoutExerciseId);   // son setin değerleriyle; set yoksa hiçbir şey yapma
Future<void> updateSet(ExerciseSet set);
Future<void> deleteSet(int setId);
void updateNote(int workoutExerciseId, String note); // 500 ms debounce ile kaydeder
Future<void> flushNotes();                           // bekleyen not kayıtlarını hemen yapar
Future<void> discardIfEmpty();                       // hiç hareket yoksa antrenmanı siler
```

- `SetDraft`: aynı dosyada, değişmez sınıf `{double weightKg; int reps}`.
- **Taslak kuralı** (hareket için taslak henüz yoksa): bu antrenmanda o hareketin seti varsa **son setin**
  değerleri; yoksa "geçen sefer"in **ilk setinin** değerleri; o da yoksa 20 kg × 10. Taslak bir kez oluşunca
  kullanıcı değiştirene kadar korunur (set eklemek taslağı değiştirmez).
- Her değiştirici işlemden sonra detayı repository'den yeniden yükle (taslaklar korunur). `addExercise`
  sonrası yeni hareketin "geçen sefer"ini de yükle (`getPreviousSets(exercise.id, beforeWorkoutId: workoutId)`).
- `dispose()`: bekleyen not zamanlayıcılarını iptal et (kaydetme işini ekran `flushNotes` ile yapar).

## Ekran

- **Geri çıkış:** `PopScope(canPop: false)`; `onPopInvokedWithResult` içinde `didPop` false ise
  `await vm.flushNotes(); await vm.discardIfEmpty();` sonra `Navigator.of(context).pop()`. (Böylece Geçmiş ekranı
  listeyi yenilediğinde boş antrenman çoktan silinmiş olur.)
- `AppBar`: başlık `vm.title` (dokunulabilir; tek satır). Dokununca `AlertDialog` "Antrenman adı":
  `TextField` (mevcut başlıkla dolu, ipucu "ör. Upper, Göğüs günü, Pazartesi"), "İptal" / "Kaydet".
  Kaydet → `updateTitle` (boş bırakılırsa başlık kalkar, tarih görünür). Başlık varsa liste başında
  `bodySmall` ile `formatWorkoutDate(startedAt)` göster.
- **Hareket yoksa:** `EmptyState(icon: Icons.fitness_center, title: 'İlk hareketini ekle',
  message: 'Yaptığın hareketi seç, setlerini kaydet.', actionLabel: 'Hareket ekle', onAction: <hareket ekle>)`.
- **Hareket varsa:** `ListView` (kenar `AppSpacing.screenPadding`), her hareket bir **hareket kartı**
  (`Card`, iç boşluk `AppSpacing.lg`, kartlar arası `AppSpacing.md`), listenin sonunda tam genişlik
  **tek `FilledButton.icon`** (`Icons.add`, "Hareket ekle").
- **Hareket ekle:** `final ex = await Navigator.push<Exercise>(..., ExercisePickerScreen())`; `ex != null` ise
  `addExercise(ex)`.

### Hareket kartı (`StatefulWidget`, not alanının `TextEditingController`'ı burada yaşar)

1. Üst satır: hareket adı `titleMedium` (`Expanded`) · `MuscleGroupChip` (dokunulamaz) ·
   `PopupMenuButton` (`Icons.more_vert`, tooltip "Seçenekler") içinde "Hareketi kaldır" → onay
   `AlertDialog` ("Hareket kaldırılsın mı?", "Bu hareketin setleri de silinecek.", "İptal" / "Kaldır"
   (`colorScheme.error`)) → `removeExercise`.
2. "Geçen sefer" (varsa): `bodySmall` "Geçen sefer: 60 kg × 10, 65 kg × 8" (`formatSet` ile, virgülle).
3. Setler: her set bir satır, yükseklik en az 48: solda set no (`bodySmall`, sabit genişlik 28), ortada
   `formatSet` (`titleLarge`), sağda `IconButton(Icons.close, tooltip: 'Seti sil')` → `deleteSet`.
   Satıra dokununca alttan `showModalBottomSheet`: başlık "{n}. set", ağırlık ve tekrar `NumberStepper`'ları,
   tam genişlik "Kaydet" butonu → `updateSet`.
4. Sıradaki set: `bodySmall` "{setSayısı + 1}. set"; altında yan yana iki `Expanded` `NumberStepper`:
   ağırlık (`step: 2.5`, `unit: 'kg'`, `label: 'Ağırlık'`), tekrar (`step: 1`, `min: 1`, `allowDecimal: false`,
   `label: 'Tekrar'`). Değerler `draftFor`'dan; değişince `setDraftWeight`/`setDraftReps`.
5. Butonlar, yan yana iki `Expanded`: `OutlinedButton.icon(Icons.replay, 'Seti tekrarla')` (set yoksa
   devre dışı) ve **vurgulu** `OutlinedButton.icon(Icons.add, 'Set ekle')` (`foregroundColor` ve kenarlık
   `colorScheme.primary`). Set ekle → `HapticFeedback.lightImpact()` + `addSet`.
6. Not: `TextField` (çok satırlı, `minLines: 1`, `maxLines: 4`, ipucu "Not ekle (ör. 2. sette formum bozuldu)",
   başta mevcut not), `onChanged` → `updateNote`.

## Testler

- ViewModel (`FakeWorkoutRepository` ile): `load`; üç taslak kuralı; `addSet` taslakla set ekler ve numara artar;
  `repeatLastSet` son seti kopyalar, set yoksa bir şey yapmaz; `deleteSet`; `addExercise` sonrası
  `previousSetsFor` dolu; `updateNote` 500 ms sonra kaydeder ve `flushNotes` hemen kaydeder;
  `discardIfEmpty` yalnızca hareket yoksa siler; `updateTitle('')` başlığı kaldırır.
- Ekran: hareket ve setleri görünür; "Set ekle" → yeni set satırı ("60 kg × 10" gibi) görünür;
  "Geçen sefer" metni görünür; hareketsiz antrenmanda boş durum görünür.

## Bitti sayılması için

- `flutter analyze lib/ui/workout test/ui/workout` temiz
- `flutter test test/ui/workout` tamamen geçiyor
