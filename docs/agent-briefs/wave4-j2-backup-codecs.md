# Dalga 4 – Ajan J2: Yedek dosya biçimleri – JSON ve CSV (issue #1)

Önce [ortak kuralları](README.md) oku. Veri sınıfları: `lib/data/models/backup_data.dart`.

## Dokunabileceğin dosyalar (hepsi yeni)

- `lib/data/backup/backup_json_codec.dart`
- `lib/data/backup/backup_csv_exporter.dart`
- `test/data/backup/backup_json_codec_test.dart`
- `test/data/backup/backup_csv_exporter_test.dart`

Saf Dart: yalnızca `dart:convert` ve projedeki modeller. Flutter, dosya sistemi, yeni paket yok.

## 1. JSON (`backup_json_codec.dart`)

```dart
const String backupFormatId = 'exercise-tracking-app-backup';
String encodeBackupJson(BackupData data);    // JsonEncoder.withIndent('  ')
BackupData decodeBackupJson(String source);  // hata → BackupFormatException
class BackupFormatException implements Exception { const BackupFormatException(this.message); final String message; }
```

Biçim (alan adları **birebir**):
```json
{
  "format": "exercise-tracking-app-backup",
  "format_version": 1,
  "exported_at": "2026-10-18T10:00:00.000",
  "exercises": [ { "name": "Bench Press", "muscle_group": "chest" } ],
  "workouts": [
    {
      "started_at": "2026-10-17T18:30:00.000",
      "title": "Upper",
      "exercises": [
        {
          "exercise": "Bench Press",
          "muscle_group": "chest",
          "note": "2. sette formum bozuldu",
          "sets": [ { "weight_kg": 60.0, "reps": 10 } ]
        }
      ]
    }
  ]
}
```
- Tarihler `DateTime.toIso8601String()` / `DateTime.parse`. `muscle_group` = `MuscleGroup.name`; okurken
  `MuscleGroup.fromName` (bilinmeyen → `other`). `weight_kg` okurken `num` → `toDouble()`. `title` ve `note` null olabilir.
- `decodeBackupJson` şu durumlarda `BackupFormatException` fırlatır (mesajlar Türkçe, kullanıcıya gösterilecek):
  - JSON değil → `'Dosya okunamadı: geçerli bir yedek dosyası değil.'`
  - `format` alanı yok/farklı → `'Bu dosya bu uygulamanın yedek dosyası değil.'`
  - `format_version` > `BackupData.currentFormatVersion` → `'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Uygulamayı güncelleyin.'`
  - Zorunlu alan eksik ya da tipi yanlış (ör. `reps` metin, `sets` liste değil, tarih okunamıyor) →
    `'Yedek dosyası bozuk: <hangi alan>'` (ör. `'Yedek dosyası bozuk: workouts[2].exercises[0].sets[1].reps'`).
  - Değer kontrolü (reps > 0 vb.) burada **yapılmaz**; onu repository yapar.

## 2. CSV (`backup_csv_exporter.dart`)

```dart
String exportBackupCsv(BackupData data);
```
- UTF-8 BOM (`'﻿'`) ile başlar (Excel'in Türkçe karakterleri doğru göstermesi için); satır sonu `\r\n`.
- Başlık satırı: `date,time,workout_title,exercise,muscle_group,set_number,weight_kg,reps,note`
- Her **set** bir satır; antrenmanlar ve setler `data`'daki sırayla.
  - `date`: `yyyy-MM-dd`, `time`: `HH:mm` (startedAt'ten, sıfır dolgulu; `intl` kullanma, elle biçimle)
  - `workout_title`: başlık ya da boş; `muscle_group`: Türkçe etiket (`MuscleGroup.label`, ör. "Göğüs")
  - `set_number`: 1'den; `weight_kg`: nokta ondalık, tam sayıysa ondalıksız ("60", "62.5"); `reps`: tam sayı
  - `note`: hareketin notu; o hareketin her satırında tekrarlanır (tablolarda filtrelemeyi kolaylaştırır)
  - Seti olmayan hareket: set alanları boş tek satır. Hareketi olmayan antrenman: hareket ve set alanları boş tek satır.
- Kaçış (RFC 4180): virgül, çift tırnak, `\r` ya da `\n` içeren alan çift tırnağa alınır, içindeki `"` → `""`.

## 3. Testler

- JSON: dolu bir `BackupData` → encode → decode → tüm alanlar aynı (null başlık/not, ondalıklı ağırlık, Türkçe
  karakterler dahil); her hata durumu doğru mesajla `BackupFormatException`; bilinmeyen kas grubu `other` olur;
  `weight_kg: 60` (int) okunabilir.
- CSV: BOM ve başlık; boş veri → yalnızca başlık; satır sayısı = set sayısı (+ setsiz hareket/hareketsiz antrenman
  satırları); "62.5" ve "60" biçimi; virgüllü/tırnaklı/çok satırlı not doğru kaçışlanır; Türkçe karakterler bozulmaz;
  saat sıfır dolgulu ("09:05").

## Bitti sayılması için

- `flutter analyze lib/data/backup test/data/backup` temiz
- `flutter test test/data/backup` tamamen geçiyor
