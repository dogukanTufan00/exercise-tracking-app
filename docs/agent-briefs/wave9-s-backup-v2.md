# Dalga 9 – Ajan S: Yedekte ölçümler (yedek biçimi 2, #14)

Önce [ortak kuralları](README.md) oku ve `docs/ARCHITECTURE.md` §10 (yedekleme) ile §13.
Bu dalgada iki ajan daha çalışıyor: alt gezinme çubuğu ve profil ekranları. Listende olmayan dosyaya dokunma.

## Hazır olanlar (DEĞİŞTİRME, kullan)

- `BackupData.currentFormatVersion == 2`; `BackupData.measurementTypes` ve `BackupData.measurements`
  (`lib/data/models/backup_data.dart`: `BackupMeasurementType`, `BackupMeasurement`).
- `MeasurementRepository.exportMeasurements()` / `importMeasurements(types:, measurements:)` (kuralları doc
  yorumunda; uygulaması ve testleri hazır). Testler için `FakeMeasurementRepository`.

## Dokunabileceğin dosyalar

- `lib/data/backup/backup_json_codec.dart`
- `test/data/backup/backup_json_codec_test.dart`
- `lib/ui/settings/backup_view_model.dart`
- `test/ui/settings/backup_view_model_test.dart`
- `lib/ui/settings/settings_screen.dart` (yalnızca `BackupViewModel` oluşturma satırı)
- `test/ui/settings/settings_screen_test.dart`
- `docs/ARCHITECTURE.md` §10 (yalnızca biçim 2 notu)

## 1. JSON biçimi 2 (`backup_json_codec.dart`)

Kök nesneye iki yeni anahtar:

```json
"measurement_types": [ { "name": "Ön kol", "unit": "cm" } ],
"measurements": [ { "type": "Bel", "unit": "cm", "measured_at": "2026-10-20T12:00:00.000", "value": 82.5 } ]
```

- Yazma: her zaman `format_version: 2` ve iki anahtar (boşsa `[]`).
- Okuma: `format_version` 1 → iki liste boş (anahtarlar yoksa da hata değil). 2 → anahtarlar varsa okunur, yoksa boş
  liste. Bilinmeyen (daha yeni) sürüm için mevcut hata davranışı korunur. Alan doğrulaması mevcut yardımcılarla
  (`_requireString`, `_requireNum`, `_requireDate`…), hatalı alanın yolu mesajda (`measurements[3].value` gibi).
- CSV dışa aktarma **değişmez** (yalnızca antrenmanlar).

## 2. `BackupViewModel`

- Kurucuya `MeasurementRepository` ekle: `BackupViewModel(this._repository, this._measurements, this._files, {clock})`.
  `settings_screen.dart`'taki oluşturmayı ve testleri buna göre güncelle.
- **JSON yedek:** `exportBackup()` sonucuna `exportMeasurements()` eklenerek tek `BackupData` yazılır
  (yeni bir `BackupData` oluştur; `copyWith` yok). "Veri yok" kontrolü ölçümleri de sayar: hareket, antrenman ve
  ölçüm türü/ölçüm hepsi boşsa `Henüz kaydedilmiş veri yok.`
- **CSV:** değişmez (ölçümler CSV'ye girmez; ölçüm var ama antrenman yoksa "veri yok" mesajı doğru).
- **Geri yükleme:** önce `importBackup(data)` (antrenmanlar), sonra `importMeasurements(...)`. Her biri kendi içinde
  ya hep ya hiç; dosya bütünüyle `decodeBackupJson` ile önceden doğrulandığı için ikincisinin değer hatası pratikte
  beklenmez, yine de `ArgumentError`'u mevcut mesajla karşıla. Başarı mesajına ölçüm eklendiyse
  `, {n} ölçüm` ekle (ör. "3 antrenman eklendi, 0 antrenman atlandı, 12 ölçüm").

## 3. Testler

- Codec: biçim 2 gidiş-dönüş (ölçümler dahil); biçim 1 dosyası okunur ve listeler boş; biçim 2 dosyasında anahtarlar
  eksikse boş liste; geçersiz ölçüm alanında hata yolu mesajda.
- ViewModel (`FakeWorkoutRepository` + `FakeMeasurementRepository` + mevcut sahte dosya servisi): JSON yedeğinde
  ölçümler var; yalnız ölçüm varken JSON yedeği alınır ama CSV "veri yok" der; geri yükleme ölçümleri ekler ve
  mesajda sayı görünür; biçim 1 yedeği hâlâ geri yüklenir.

## 4. Doküman

`docs/ARCHITECTURE.md` §10'a kısa not: biçim 2 ölçüm türlerini ve ölçümleri içerir; biçim 1 okunmaya devam eder;
geri yüklemede önce antrenmanlar sonra ölçümler (her biri kendi transaction'ında).

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
