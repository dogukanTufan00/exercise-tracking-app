# Dalga 5 – Ajan L: İlerleme ekranına giriş noktaları (#7)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil). Bu görev mevcut kodu **değiştirir** ve yeni bir
ekran ekler; önce ilgili dosyaları baştan sona oku.

## Bağlam

Hareket detay ekranı hazır ama uygulamadan açılamıyor:
`ExerciseDetailScreen(exercise: Exercise)` (`lib/ui/exercise_detail/exercise_detail_screen.dart`). Bu dosyayı
oku ama **değiştirme**. Ekran `Navigator.push` ile açılır, bir şey döndürmez. Geçmişi kendisi yükler; kapandıktan
sonra çağıranın bir şey yenilemesi gerekmez.

Hareket kartının başlığına dokunmak kartı açıp kapatıyor; bu yüzden giriş noktası başlık **olamaz**.

## Dokunabileceğin dosyalar

- `lib/ui/workout/widgets/exercise_card.dart`
- `lib/ui/workout/workout_screen.dart`
- `lib/ui/history/history_screen.dart`
- `lib/ui/exercises/exercises_view_model.dart` (yeni)
- `lib/ui/exercises/exercises_screen.dart` (yeni)
- `test/ui/workout/workout_screen_test.dart`
- `test/ui/history/history_screen_test.dart`
- `test/ui/exercises/exercises_view_model_test.dart` (yeni)
- `test/ui/exercises/exercises_screen_test.dart` (yeni)

## 1. Hareket kartının ⋮ menüsü

`ExerciseCard`'ın `PopupMenuButton`'ında şu an tek seçenek var ("Hareketi kaldır").

- Yeni parametre: `required VoidCallback onShowProgress`.
- Menüye "Hareketi kaldır"ın **üstüne** yeni bir seçenek ekle: metin `İlerleme`, değer `'progress'`.
  Seçilince `onShowProgress()` çağrılır.
- `workout_screen.dart` bu parametreyi şöyle geçer:
  `onShowProgress: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ExerciseDetailScreen(exercise: entry.exercise)))`.

## 2. "Hareketler" ekranı (yeni)

Katalogdaki tüm hareketleri listeler; birine dokununca o hareketin detay ekranı açılır.

### ViewModel (`ExercisesViewModel`, `lib/ui/exercises/exercises_view_model.dart`)

`ExercisePickerViewModel`'i (`lib/ui/exercise_picker/exercise_picker_view_model.dart`) örnek al; arama mantığı
aynı:
- Kurucu: `ExercisesViewModel(WorkoutRepository repository)`.
- `List<Exercise> exercises`, `String query`, `bool isLoading`, `String? errorMessage`, `void clearError()`.
- `Future<void> load()` → `search('')`.
- `Future<void> search(String query)` → `repository.searchExercises(query)`. Arama Türkçe karakterlere duyarlıdır
  ("sinav" "Şınav"ı bulur) çünkü repository bunu zaten yapıyor. **Yarış durumu:** hızlı yazarken eski bir
  aramanın sonucu yenisinin üstüne yazılmamalı. Picker ViewModel'i bunu nasıl çözüyorsa aynısını yap.
- Hata mesajı: `'Hareketler yüklenemedi.'`
- `_disposed` kuralı geçerli.

Katalogda hiç seti olmayan hareketler de listelenir. Detay ekranı onlar için zaten "Henüz set yok" gösteriyor.

### Ekran (`ExercisesScreen`, `lib/ui/exercises/exercises_screen.dart`)

- Kurucu: `const ExercisesScreen({super.key})`. Desen: README'deki `ChangeNotifierProvider` + `_ExercisesView`.
- `AppBar` başlığı: `Hareketler`.
- Üstte arama kutusu (`TextField`, ipucu metni `Hareket ara`, `Icons.search` önek ikonu). Her değişiklikte
  `search` çağrılır. Hareket seç ekranındaki arama kutusunun görünüşünü örnek al.
- Liste: her hareket için `ListTile`. `title`: hareket adı; `subtitle` ya da `trailing` içinde
  `MuscleGroupChip(group: ...)`; sonda `Icons.chevron_right`. Dokununca
  `Navigator.push` → `ExerciseDetailScreen(exercise: exercise)`.
- Boş durumlar:
  - Katalog tamamen boş (`query` boş ve liste boş): `EmptyState(icon: Icons.fitness_center, title: 'Henüz hareket yok', message: 'Antrenmana hareket eklediğinde burada listelenir.')`.
  - Arama eşleşmiyor (`query` dolu, liste boş): ortada `bodyMedium` metin `Eşleşen hareket yok`.
- Yükleme: ilk yüklemede `CircularProgressIndicator`. Aramada liste kaybolup spinner'a dönmesin; eski liste
  yeni sonuç gelene kadar kalsın.
- Hata: README'deki SnackBar deseni.
- `FilledButton` yok.

## 3. Geçmiş ekranında giriş

`history_screen.dart` `AppBar` `actions` listesine, ayarlar ikonunun **soluna** yeni bir `IconButton` ekle:
`Icons.insights_outlined`, tooltip `Hareketler`. Basılınca `ExercisesScreen` açılır. Dönüşte listeyi yenilemek
gerekmez.

## 4. Testler

- **Hareketler ViewModel:** `load` tüm kataloğu A→Z getirir; `search('sinav')` "Şınav"ı bulur; yavaş ilk arama
  sonraki hızlı aramanın sonucunu ezmez (picker ViewModel testindeki `_SlowFirstSearchRepository` yaklaşımını
  örnek al); repository hata fırlatınca `errorMessage` dolar.
- **Hareketler ekranı:** hareketler ve kas grubu etiketleri görünür; arama listeyi filtreler; eşleşme yoksa
  "Eşleşen hareket yok"; boş katalogda "Henüz hareket yok"; bir harekete dokununca detay ekranı açılır
  (`find.byType(ExerciseDetailScreen)` ve AppBar'da hareketin adı).
- **Antrenman ekranı:** ⋮ menüsünü aç (`find.byTooltip('Seçenekler')`), `İlerleme`'ye dokun, detay ekranı açılır.
  Mevcut "Hareketi kaldır" testleri bozulmamalı.
- **Geçmiş ekranı:** `Hareketler` tooltip'li ikona dokununca `ExercisesScreen` açılır.
- **Telefon boyutu:** Hareketler ekranı 360 × 780'de, yazı ölçeği 1.3'te, uzun bir hareket adıyla
  (ör. `Incline Dumbbell Bench Press`) taşma vermemeli (`expect(tester.takeException(), isNull)`).
  Ölçüyü `test/ui/workout/workout_screen_test.dart`'taki `pumpWorkout` gibi ayarla.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test test/ui` tamamen geçiyor
