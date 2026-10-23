# Dalga 11 – Ajan Y: Yedekte programlar (yedek biçimi 3, #16)

Önce [ortak kuralları](README.md) oku, `docs/ARCHITECTURE.md` §10 ve §14. Ayrıca önceki biçim değişikliğini yapan
brief'i oku: [wave9-s-backup-v2.md](wave9-s-backup-v2.md) — aynı deseni izle.
Bu dalgada üç ajan daha çalışıyor (program ekranları, antrenmanı programdan başlatma). Listende olmayan dosyaya dokunma.

## Hazır olanlar (DEĞİŞTİRME, kullan)

- `BackupData.currentFormatVersion == 3`, `BackupData.programs` ve `BackupProgram` / `BackupProgramDay` /
  `BackupProgramExercise` (`lib/data/models/backup_data.dart`).
- `ProgramRepository.exportPrograms()` / `importPrograms(programs)` (uygulaması ve testleri hazır).
  Testler için `FakeProgramRepository(FakeWorkoutRepository)`.

## Dokunabileceğin dosyalar

- `lib/data/backup/backup_json_codec.dart`, `test/data/backup/backup_json_codec_test.dart`
- `lib/ui/settings/backup_view_model.dart`, `test/ui/settings/backup_view_model_test.dart`
- `lib/ui/settings/settings_screen.dart` (yalnızca `BackupViewModel` oluşturma), `test/ui/settings/settings_screen_test.dart`
- `docs/ARCHITECTURE.md` §10 (yalnızca biçim 3 notu)

## 1. JSON biçimi 3

Kök nesneye `"programs"`:

```json
"programs": [
  { "name": "Üst/Alt", "is_active": true, "days": [
    { "name": "Göğüs + Sırt", "weekday": 4, "exercises": [
      { "exercise": "Chest press", "muscle_group": "chest", "sets": 3, "reps": 10, "weight_kg": 40 }
    ] }
  ] }
]
```

- `weekday` ve `weight_kg` `null` olabilir. Yazma her zaman `format_version: 3` ve `programs` (boşsa `[]`).
- Okuma: 1 ve 2 → `programs` boş; 3 → anahtar varsa okunur, yoksa boş. Doğrulama mevcut yardımcılarla; hata yolu mesajda
  (`programs[0].days[1].exercises[2].reps`). `weekday` 1–7 dışındaysa hata. Mevcut biçim 2 testleri geçmeye devam etmeli.

## 2. `BackupViewModel`

- Kurucuya `ProgramRepository` ekle (`BackupViewModel(workouts, measurements, programs, files, {clock})`);
  `settings_screen.dart` ve testleri güncelle.
- JSON yedeğe `exportPrograms()` eklenir. "Veri yok" kontrolü programları da sayar.
- Geri yükleme: antrenmanlar → ölçümler → programlar (her biri kendi transaction'ında; mevcut hata mesajı deseni:
  ilk adım hatasında "hiçbir şey değiştirilmedi", sonraki adımlarda hangi kısmın eklendiğini söyleyen mesaj).
  Başarı mesajına program eklendiyse `, {n} program`.

## 3. Testler

Codec: biçim 3 gidiş-dönüş; biçim 1 ve 2 dosyaları okunur, programlar boş; `weekday` 8 → hata yolu. ViewModel: yedekte
programlar; geri yükleme program sayısını söyler; aynı adlı program atlanır.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
