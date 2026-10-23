# Dalga 11 – Ajan W1: Program sekmesi (#16)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil), `docs/ARCHITECTURE.md` §14 ve `docs/DESIGN.md`.
Bu dalgada üç ajan daha çalışıyor: W2 gün düzenleme ekranı (`lib/ui/program/day_edit_*`, `lib/ui/program/widgets/`),
X antrenmanı programdan başlatma (`lib/ui/history/`, `lib/ui/workout/`), Y yedekleme (`lib/data/backup/`,
`lib/ui/settings/`). Listende olmayan dosyaya dokunma.

## Hazır olanlar (DEĞİŞTİRME, kullan)

- `ProgramRepository` (`lib/data/repositories/program_repository.dart`, kuralları doc yorumunda) ve modeller
  (`lib/data/models/program.dart`). Ekranlar `context.read<ProgramRepository>()` ile alır.
- `formatWeekday`, `formatTarget` (`lib/ui/core/formatters.dart`).
- `DayEditScreen(dayId:)` (`lib/ui/program/day_edit_screen.dart`) — iskelet; W2 dolduruyor. Sen yalnızca
  `Navigator.push` ile aç, dönünce yenile.
- Testler için `FakeProgramRepository(FakeWorkoutRepository())` (`test/fakes/`).
- `AppTab` enum'u ve seçili sekme bildirimi (`lib/ui/app_tab.dart`, #17): sekmeye dönünce yenileme deseni
  `ExercisesScreen`'deki gibi.

## Dokunabileceğin dosyalar

- `lib/ui/app_tab.dart`, `lib/ui/app_shell.dart`, `test/ui/app_shell_test.dart`
- `lib/ui/program/program_screen.dart`, `lib/ui/program/program_view_model.dart` (yeni)
- `lib/ui/program/programs_screen.dart`, `lib/ui/program/programs_view_model.dart` (yeni)
- `test/ui/program/program_screen_test.dart`, `program_view_model_test.dart`, `programs_screen_test.dart`,
  `programs_view_model_test.dart` (yeni)

## 1. Sekme

`AppTab`'a (`lib/ui/app_tab.dart`) `program` ekle; sıra: **Antrenmanlar, Program, Hareketler, Profil**. İkon `Icons.event_note_outlined`
(seçiliyken `Icons.event_note`), etiket `Program`, kök `ProgramScreen()`. Mevcut app shell testlerini yeni sıraya göre
güncelle (sekmeyi indeksle değil etiketle bul).

## 2. `ProgramScreen` (sekme kökü) — etkin program

- Hiç program yoksa: `EmptyState(icon: Icons.event_note, title: 'Henüz program yok', message: 'Haftalık programını oluştur; antrenman başlatırken günü önerilsin.', actionLabel: 'Program oluştur')` → ad diyaloğu → oluştur.
- Etkin program varsa: AppBar başlığı program adı; `actions`: `IconButton(Icons.list, tooltip: 'Programlar')` →
  `ProgramsScreen`; ⋮ menüsü: `Yeniden adlandır`, `Programı sil` (onay: "Program ve tüm günleri silinecek. Bu programla
  yapılmış antrenmanlar kalır.").
- Program var ama etkin yoksa (etkin olan silindiyse): `ProgramsScreen`'deki listeyi göster ya da "Etkin program yok —
  Programlar'dan birini seç" bilgisi + düğme.
- Gövde: günler sırayla, her biri bir kart: gün adı (`titleMedium`), `formatWeekday(weekday)` (soluk), altında her
  hareket için "Bench Press · 3 × 10 · 40 kg" satırları (`formatTarget`), hareket yoksa soluk "Henüz hareket yok".
  Karta dokununca `DayEditScreen(dayId:)`; dönünce yenile.
- `FloatingActionButton` (tooltip `Gün ekle`) → gün adı diyaloğu (ad alanı; planlanan gün sonra gün ekranında seçilir)
  → `addDay` → yeni günün `DayEditScreen`'i açılır.
- Günleri sıralama: kartlarda ⋮ menüsü `Yukarı taşı` / `Aşağı taşı` (ilk/son günde ilgili seçenek yok) →
  `reorderDays`. Sürükle-bırak gerekmez.
- Sekmeye dönünce (`AppTab.program`) yükleme göstergesi olmadan yenile.

## 3. `ProgramsScreen` — tüm programlar

AppBar `Programlar`. Liste: program adı, etkinse sağda `Icons.check_circle` (birincil renk) ve "Etkin" yazısı;
dokununca `setActiveProgram` ve geri dön. AppBar'da `IconButton(Icons.add, tooltip: 'Yeni program')` → ad diyaloğu →
oluştur (ilk programsa zaten etkin olur).

## 4. Testler

ViewModel'ler `FakeProgramRepository` ile; ekranlarda: boş durum ve program oluşturma; günler ve hedef satırları;
gün ekleme sonrası `DayEditScreen` açılır; sıralama menüsü; yeniden adlandırma ve silme; Programlar'da etkin değiştirme;
app shell'de dört sekme. 360 × 780, yazı 1.3'te taşma yok.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
