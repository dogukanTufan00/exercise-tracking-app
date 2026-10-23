# Dalga 12b – Ajan Z3: Aynı hareketin iki kaydını birleştirme (#12)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil). Bu dalgada Ajan Z2 aynı anda `lib/ui/workout/`
üzerinde çalışıyor; listende olmayan dosyaya dokunma.

## Amaç

Aynı hareket iki farklı adla kaydedilmişse (ör. "Pecdec" ve "Pec deck") geçmişi ve rekorları ikiye bölünür.
Kullanıcı birini diğerine birleştirebilsin.

## Hazır olanlar

- `WorkoutRepository.mergeExercises(sourceId:, targetId:)` (uygulaması ve testleri hazır): kaynağın tüm kayıtları
  hedefe taşınır, kaynak katalogdan silinir.
- `ExercisePickerScreen()` (`Navigator.push<Exercise>`; seçilen hareketle döner).

## Dokunabileceğin dosyalar

- `lib/ui/exercise_detail/exercise_detail_screen.dart`, `lib/ui/exercise_detail/exercise_detail_view_model.dart`
- `test/ui/exercise_detail/exercise_detail_screen_test.dart`, `test/ui/exercise_detail/exercise_detail_view_model_test.dart`
- `lib/ui/exercises/exercises_screen.dart`, `test/ui/exercises/exercises_screen_test.dart`

## Yapılacaklar

- Hareket detay ekranı AppBar'ı: mevcut ✏️ düğmesinin yanına ⋮ menüsü; seçenek `Başka bir hareketle birleştir`.
- Seçilince `ExercisePickerScreen` açılır. Seçilen hareket bu hareketin kendisiyse SnackBar `'Aynı hareket seçildi.'`.
- Onay diyaloğu: başlık `Hareketler birleştirilsin mi?`, metin
  `"{kaynak}" hareketinin tüm antrenmanları ve program kayıtları "{hedef}" altına taşınacak ve "{kaynak}" silinecek. Bu işlem geri alınamaz.`,
  düğmeler `Vazgeç` / `Birleştir` (hata rengiyle, `FilledButton` değil — mevcut silme diyaloglarının deseni).
- `ExerciseDetailViewModel.mergeInto(Exercise target)` → `Future<bool>`; hata `'Hareketler birleştirilemedi.'`.
- Başarıda bu ekran **hedef hareketin** detayıyla değiştirilir (`Navigator.pushReplacement` → `ExerciseDetailScreen(exercise: target)`)
  ve SnackBar `'Hareketler birleştirildi'`.
- `ExercisesScreen`: detaydan dönünce zaten listeyi yeniliyor; birleştirilen (silinen) hareketin listeden kalktığını test et.

## Testler

ViewModel: birleştirme repository'yi doğru id'lerle çağırır, başarı/başarısızlık. Ekran: ⋮ → birleştir → picker'da hedefe
dokun → onay → hedefin detay ekranı açılır ve geçmişinde kaynağın antrenmanları da görünür; `Vazgeç` hiçbir şey değiştirmez;
kendisi seçilirse mesaj. Hareketler listesi: birleştirme sonrası kaynak listede yok.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
