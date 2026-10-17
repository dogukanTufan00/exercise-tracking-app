# Dalga 2 – Ajan E: Geçmiş ekranı

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil).

## Dokunabileceğin dosyalar

- `lib/ui/history/history_screen.dart` (iskeleti değiştir; kurucu imzası aynı kalmalı)
- `lib/ui/history/history_view_model.dart` (yeni)
- `test/ui/history/history_view_model_test.dart` (yeni)
- `test/ui/history/history_screen_test.dart` (yeni)

`WorkoutScreen` ve `SettingsScreen`'i başka ajanlar yazıyor; sadece import edip kurucularını kullan.

## `HistoryViewModel`

```dart
HistoryViewModel(WorkoutRepository repository)
List<WorkoutSummary> get workouts;   // repository'nin döndürdüğü sırayla (en yeni üstte)
bool get isLoading;                  // ilk yüklemede true
String? get errorMessage; void clearError();
Future<void> load();
Future<int?> startWorkout();         // createWorkout() → yeni antrenmanın id'si; hata olursa null
Future<void> deleteWorkout(int id);  // repository'den sil, listeden çıkar
```

## Ekran

- `AppBar`: başlık "Antrenmanlar"; sağda ayarlar `IconButton` (`Icons.settings_outlined`, tooltip "Ayarlar")
  → `SettingsScreen`'e `push`.
- Yüklenirken ortada `CircularProgressIndicator`.
- **Boş durum:** `EmptyState(icon: Icons.fitness_center, title: 'İlk antrenmanını başlat',
  message: 'Yaptığın hareketleri, setleri ve notlarını buraya kaydet.', actionLabel: 'Antrenman başlat',
  onAction: <başlat>)`.
- **Liste:** `ListView.separated`, kenar boşluğu `AppSpacing.screenPadding`, öğeler arası `AppSpacing.md`.
  Her antrenman bir `Card` + `InkWell` (iç boşluk `AppSpacing.lg`):
  - 1. satır: başlık `titleMedium` (`Expanded`, tek satır, taşarsa `…`). Başlık `workout.title`, yoksa
    `formatWorkoutDate(startedAt)`. Başlık varsa sağda kısa tarih `bodySmall`: `DateFormat('d MMM', 'tr')`
    (ör. "17 Eki"). Başlık yoksa sağda tarih gösterme (zaten başlıkta).
  - 2. satır `bodySmall`: "`{exerciseCount}` hareket · `{setCount}` set".
  - 3. satır (kas grubu varsa): `Wrap(spacing: AppSpacing.xs)` içinde dokunulamaz `MuscleGroupChip`'ler.
  - **Dokununca:** `await Navigator.push(... WorkoutScreen(workoutId: id))`, dönünce `load()`.
  - **Uzun basınca:** `AlertDialog` başlık "Antrenman silinsin mi?", içerik "Bu antrenman ve içindeki tüm
    setler kalıcı olarak silinecek.", butonlar "İptal" (`TextButton`) ve "Sil" (`TextButton`, yazı rengi
    `colorScheme.error`). Sil → `deleteWorkout` → `SnackBar('Antrenman silindi')`.
- **Başlat butonu:** `FloatingActionButton` (`Icons.add`, tooltip "Antrenman başlat") → `startWorkout()`;
  id gelirse `await push(WorkoutScreen)` → dönünce `load()`. Bu ekranda başka `FilledButton` yok
  (boş durumdaki buton liste boşken görünür, FAB ile aynı işi yapar; ikisi aynı anda görünebilir).

## Testler

- ViewModel: `load` sonrası `workouts` repository sırasıyla; `isLoading` önce true sonra false;
  `startWorkout` yeni id döner ve repository'de antrenman oluşur; `deleteWorkout` listeden ve repository'den siler.
- Ekran: boşken boş durum metni görünür; başlıklı antrenman kartında başlık, "2 hareket · 3 set" ve kas grubu
  etiketleri görünür; başlıksız antrenmanda `formatWorkoutDate` metni görünür; FAB'a basınca repository'de
  1 antrenman oluşur ve `find.byType(WorkoutScreen)` bulunur; uzun basma → "Sil" → kart kaybolur.

## Bitti sayılması için

- `flutter analyze lib/ui/history test/ui/history` temiz
- `flutter test test/ui/history` tamamen geçiyor
