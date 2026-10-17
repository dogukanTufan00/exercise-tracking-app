# Dalga 2 – Ajan G: Hareket seç ekranı

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil).

## Dokunabileceğin dosyalar

- `lib/ui/exercise_picker/exercise_picker_screen.dart` (iskeleti değiştir; kurucu ve dönüş sözleşmesi aynı kalmalı)
- `lib/ui/exercise_picker/exercise_picker_view_model.dart` (yeni)
- `test/ui/exercise_picker/exercise_picker_view_model_test.dart` (yeni)
- `test/ui/exercise_picker/exercise_picker_screen_test.dart` (yeni)

## `ExercisePickerViewModel`

```dart
ExercisePickerViewModel(WorkoutRepository repository)
String get query;
List<Exercise> get results;
bool get isLoading;
String? get errorMessage; void clearError();
MuscleGroup? get selectedGroup;       // yeni hareket için seçilen kas grubu
bool get canCreate;                   // sorgu boş değil VE sonuçlarda normalizeForSearch'e göre birebir aynı adlı hareket yok
Future<void> load();                  // search('') ile aynı
Future<void> search(String query);    // sorguyu günceller, sonuçları getirir
void selectGroup(MuscleGroup group);
Future<Exercise?> createExercise();   // ad = query.trim(), grup = selectedGroup; grup seçili değilse null
```

- **Eski yanıt koruması:** hızlı yazarken önceki aramanın yanıtı sonrakinden geç gelebilir. Her aramaya artan bir
  sıra numarası ver; gelen yanıt en son aramaya ait değilse yok say.
- `createExercise`: `DuplicateExerciseException` → `errorMessage = 'Bu hareket zaten katalogda var'`, `null` döner.
  Diğer hatalar → `'Hareket eklenemedi'`, `null`.

## Ekran

- `AppBar` başlığı "Hareket seç".
- Üstte arama alanı (`TextField`, `autofocus: true`, `prefixIcon: Icon(Icons.search)`, ipucu "Hareket ara",
  `textInputAction: TextInputAction.search`), `onChanged` → `search`. Kenar boşluğu `AppSpacing.screenPadding`.
- **Yeni hareket kutusu** (`canCreate` iken, listenin **üstünde**): çerçeveli kutu (`colorScheme.outline`,
  yarıçap `AppSpacing.cardRadius`, iç boşluk `AppSpacing.lg`):
  - `"{query}" adıyla yeni hareket` (`titleMedium`)
  - `bodySmall` "Kas grubu"
  - `Wrap` içinde **dokunulabilir** `MuscleGroupChip`'ler (tüm `MuscleGroup.values`), seçili olan `selected: true`
  - Tam genişlik `FilledButton` "Ekle" (grup seçilmediyse devre dışı) → `createExercise` → sonuç varsa
    `Navigator.pop(context, sonuç)`.
- **Sonuç listesi:** her hareket bir satır (`InkWell`, en az 56 yükseklik): ad `titleMedium` (`Expanded`) +
  `MuscleGroupChip` (dokunulamaz). Dokununca `Navigator.pop(context, exercise)`. Satırlar arası `Divider`.
- **Katalog tamamen boşsa ve sorgu boşsa:** `EmptyState(icon: Icons.search, title: 'Kataloğun boş',
  message: 'Yukarıya bir hareket adı yazarak ilk hareketini ekle.')` (butonsuz).
- **Sorgu dolu ama sonuç yoksa:** sadece yeni hareket kutusu görünür.
- `errorMessage` → `SnackBar` + `clearError()`.

## Testler

- ViewModel: `load` tüm katalogu sıralı getirir; `search('sin')` "Şınav"ı bulur; `canCreate` sorgu boşken false,
  "Şınav" varken `'şınav'` sorgusunda false, yeni adda true; `createExercise` grup seçilmeden null, seçilince
  hareketi oluşturur; aynı ad için `errorMessage` dolar; eski yanıt koruması (ilk aramayı geciktiren küçük bir
  `FakeWorkoutRepository` alt sınıfı ile).
- Ekran: listedeki harekete dokununca ekran o hareketle kapanır (testte bir "aç" butonuyla `push` edip dönen
  değeri yakala); yeni ad yazıp kas grubu seçip "Ekle" → yeni hareketle kapanır; boş katalogda boş durum görünür.

## Bitti sayılması için

- `flutter analyze lib/ui/exercise_picker test/ui/exercise_picker` temiz
- `flutter test test/ui/exercise_picker` tamamen geçiyor
