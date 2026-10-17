# Dalga 3 – Ajan I: Katlanabilir hareket kartları + stepper taşma düzeltmesi

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil); bu görev mevcut kodu **değiştirir**, önce ilgili
dosyaları baştan sona oku.

## Dokunabileceğin dosyalar

- `lib/ui/workout/workout_view_model.dart`
- `lib/ui/workout/workout_screen.dart`
- `lib/ui/workout/widgets/exercise_card.dart`
- `lib/ui/core/widgets/number_stepper.dart`
- `test/ui/workout/workout_view_model_test.dart`
- `test/ui/workout/workout_screen_test.dart`
- `test/ui/core/widgets/number_stepper_test.dart`

## 1. Hata: `NumberStepper` dar ekranda taşıyor

Gerçek telefonda (≈ 411 dp genişlik, büyük yazı) antrenman kartındaki yan yana iki stepper'ın sağ tarafı
"RenderFlex overflowed" veriyor ve **+** butonu kesiliyor. Sebep: iç `Row` sabit genişlikli
(`IconButton` 48 + değer alanı `minWidth: 72` + `IconButton` 48 + metin).

Düzeltme (`number_stepper.dart`):
- Dış `Row` verilen genişliği doldursun (`mainAxisSize: MainAxisSize.max`).
- Değer alanı (`InkWell` + değer + birim) `Expanded` içinde olsun; `minWidth: 72` kaldırılsın.
- Değer ve birim metni sığmazsa küçülsün: `FittedBox(fit: BoxFit.scaleDown)`.
- − ve + butonları en az 48×48 kalsın (dokunma alanı küçülmez).
- Mevcut davranış ve testler korunur.

## 2. Özellik: kartlar açılıp kapanabilsin

Her hareket kartı **bağımsız** olarak açılır/kapanır (aynı anda istenen sayıda kart açık olabilir).

### ViewModel (`WorkoutViewModel`)

```dart
bool isExpanded(int workoutExerciseId);
void toggleExpanded(int workoutExerciseId);   // notifyListeners
```
- Durum `Set<int>` olarak ViewModel'de tutulur (kart her yeniden çizildiğinde kaybolmasın, test edilebilsin).
- **İlk yüklemede** (`load()` ilk kez başarıyla bittiğinde) yalnızca **son** hareket (en büyük `position`) açık olur;
  sonraki yeniden yüklemeler açık/kapalı durumunu değiştirmez.
- `addExercise` ile eklenen hareket otomatik **açık** olur (diğerlerinin durumu değişmez). `addExerciseToWorkout`'un
  döndürdüğü `WorkoutExercise.id`'yi kullan.
- `removeExercise` o id'yi kümeden çıkarır.

### Kart (`ExerciseCard`)

Yeni parametreler: `required bool expanded`, `required VoidCallback onToggleExpanded`.

- **Başlık satırı her zaman görünür:** ad (`titleMedium`, `Expanded`) · `MuscleGroupChip` · açma/kapama oku ·
  `PopupMenuButton` (mevcut). Ok: `Icons.expand_more`, açıkken 180° döner (`AnimatedRotation`, 200 ms);
  `IconButton` tooltip açıkken "Daralt", kapalıyken "Genişlet". Ad + etiket alanına dokunmak da aç/kapa yapar
  (`InkWell`, en az 48 yükseklik). Menü butonu aç/kapa tetiklemez.
- **Kapalıyken** başlığın altında tek satır özet (`bodySmall`, `onSurfaceVariant`):
  - Set varsa: `"{n} set · {formatSet(en ağır set)}"` (ör. "3 set · 15 kg × 10"). En ağır set: en büyük
    `weightKg`; eşitse en çok `reps`; o da eşitse ilk set.
  - Set yoksa: `"Henüz set yok"`.
  - Not doluysa (not alanındaki **güncel** metin, kırpılmış hali boş değilse) satırın sonunda
    `Icon(Icons.sticky_note_2_outlined, size: 18)`, `Semantics(label: 'Not var')`.
- **Açıkken** bugünkü içeriğin tamamı (geçen sefer, setler, sıradaki set, butonlar, not) başlığın altında.
  Özet satırı açıkken gösterilmez.
- Açılma/kapanma animasyonlu: `AnimatedSize` (200 ms, `Curves.easeInOut`) içinde içerik.
- Not alanının `TextEditingController`'ı kart kapalıyken de yaşamaya devam etmeli (State'te kalır); kapatıp açınca
  yazılan not kaybolmamalı.

### Ekran (`workout_screen.dart`)

`ExerciseCard`'a `expanded: vm.isExpanded(id)` ve `onToggleExpanded: () => vm.toggleExpanded(id)` geç.

## 3. Testler

- **Telefon boyutu kuralı:** `workout_screen_test.dart` ve `number_stepper_test.dart` içine, ekranı
  **360 × 780** mantıksal piksele ve yazı ölçeğini **1.3**'e ayarlayan testler ekle:
  ```dart
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  ```
  Bu boyutta antrenman kartı (açık hali, stepper'larla) ve tek başına iki yan yana stepper taşma hatası
  **vermemeli** (Flutter taşmada testi otomatik düşürür; ek olarak `expect(tester.takeException(), isNull)`).
- ViewModel: ilk yüklemede yalnızca son hareket açık; `toggleExpanded` aç/kapa yapar; yeniden yükleme (ör. set
  ekleme) durumu değiştirmez; `addExercise` yeni hareketi açar, diğerlerini değiştirmez; `removeExercise` sonrası
  id kümede kalmaz.
- Ekran: kapalı kartta özet ("3 set · 15 kg × 10" / "Henüz set yok") görünür ve "Set ekle" görünmez;
  başlığa dokununca açılır ve "Set ekle" görünür; not yazılmış kapalı kartta not ikonu görünür.
- Mevcut testler, yeni varsayılan (yalnızca son kart açık) yüzünden kırılırsa testi yeni davranışa göre güncelle
  (kartı önce aç), davranışı geri alma.

## Bitti sayılması için

- `flutter analyze lib/ui test/ui` temiz
- `flutter test test/ui` tamamen geçiyor
