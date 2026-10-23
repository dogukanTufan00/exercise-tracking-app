# Dalga 11 – Ajan X: Antrenmanı programdan başlatma ve hedefler (#16)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil), `docs/ARCHITECTURE.md` §14 ve `docs/DESIGN.md`.
Bu dalgada üç ajan daha çalışıyor: W1/W2 program ekranları (`lib/ui/app_shell.dart`, `lib/ui/program/`), Y yedekleme.
Listende olmayan dosyaya dokunma.

## Hazır olanlar (DEĞİŞTİRME, kullan)

- `ProgramRepository.getActiveProgramDetail()` ve `startWorkoutFromDay(dayId)`; `suggestedDay(program, today)`
  (`lib/domain/program_schedule.dart`); `WorkoutExercise.target` (`ExerciseTarget?`); `formatWeekday`, `formatTarget`.
- Testler için `FakeProgramRepository(FakeWorkoutRepository)` — **aynı** `FakeWorkoutRepository` örneğini iki
  repository'ye ver ki programdan başlatılan antrenman antrenman listesinde görünsün.

## Dokunabileceğin dosyalar

- `lib/ui/history/history_screen.dart`, `lib/ui/history/history_view_model.dart`
- `test/ui/history/history_screen_test.dart`, `test/ui/history/history_view_model_test.dart`
- `lib/ui/workout/workout_view_model.dart`, `lib/ui/workout/widgets/exercise_card.dart`
- `test/ui/workout/workout_view_model_test.dart`, `test/ui/workout/workout_screen_test.dart`

## 1. Antrenman başlatma (Antrenmanlar sekmesi)

- `HistoryViewModel(WorkoutRepository, ProgramRepository)` (kurucu değişir; ekranı ve testleri güncelle). Yeni:
  `Future<ProgramDetail?> loadActiveProgram()` ve `Future<int?> startFromProgramDay(int dayId)` (hata mesajı
  `'Antrenman başlatılamadı.'`).
- FAB ve boş durumdaki "Antrenman başlat":
  - Etkin program yoksa ya da hiç günü yoksa: **bugünkü gibi** boş antrenman başlatır (davranış değişmez).
  - Varsa alttan bir sayfa (`showModalBottomSheet`) açılır, başlık `Antrenman başlat`:
    1. Önerilen gün varsa (`suggestedDay(program, DateTime.now())`) en üstte, vurgulu: `Bugün · {gün adı}` ve altında
       hareket sayısı. Bu sayfadaki tek dolu (birincil) seçim budur.
    2. Programın tüm günleri sırayla: gün adı, `formatWeekday`, hareket sayısı ("5 hareket"). Önerilen gün burada da
       listelenir (tekrar edebilir).
    3. En altta `Boş antrenman` (ikonlu `ListTile`).
  - Gün seçilince `startFromProgramDay` → antrenman ekranı açılır (mevcut `_openWorkout`; tam ekran açılış korunur).
- **Kaçırılan gün cezası yok:** hiçbir yerde "kaçırıldı", seri ya da uyarı gösterme.

## 2. Antrenmanda hedefler

- `ExerciseCard`: `entry.workoutExercise.target` varsa başlığın altında (açık ve kapalı kartta) soluk satır:
  `Hedef: {formatTarget(target)} · {yapılan}/{hedef} set` (ör. "Hedef: 3 × 10 · 40 kg · 1/3 set"). Hedef set sayısına
  ulaşınca bu satırın sonunda `Icons.check` (birincil renk, `Semantics(label: 'Hedef tamamlandı')`). Hedef yoksa satır yok.
- `WorkoutViewModel`'de ilk taslak (`_initialDraftFor`): hareketin seti yoksa ve hedef varsa → tekrar = hedef tekrar;
  ağırlık = hedef ağırlık, yoksa "geçen sefer"in ilk setinin ağırlığı, o da yoksa varsayılan. Seti varsa mevcut kural
  (son set) aynen.

## 3. Testler

- ViewModel'ler: etkin program yok → `loadActiveProgram` null; programdan başlatma antrenman oluşturur (başlık = gün adı);
  hedefli harekette ilk taslak hedeften (ağırlık hedefi yoksa geçen seferden).
- Ekran: etkin program yoksa FAB doğrudan antrenman açar (eski testler geçmeli); varsa sayfa açılır, `Bugün · …`
  önerisi doğru gün için görünür (testte bugünün `weekday`'ini kullanarak gün oluştur), bir güne dokununca antrenman
  ekranı başlığı gün adı; `Boş antrenman` çalışır. Kartta hedef satırı ve tamamlanınca onay ikonu.
- 360 × 780, yazı 1.3'te sayfa ve hedef satırı taşmaz.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
