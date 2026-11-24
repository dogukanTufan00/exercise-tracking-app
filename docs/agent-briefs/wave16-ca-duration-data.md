# Dalga 16a – Ajan CA: Şema 4, bitiş saati, yedek biçimi 4 ve telefonun dinlenme bildirimi (Kotlin) (#22, #18)

Önce [ortak kuralları](README.md) (Kotlin bölümü dahil) oku, sonra `docs/ARCHITECTURE.md` §4, §10 ve **§16**'nın tamamını.
Aynı anda iki ajan daha çalışıyor: CB (`lib/data/rest/`, `lib/data/watch/`, `main.dart`, ayarlar repository'si)
ve CC (`wear/`). Onların dosyalarına dokunma.

## Hazır olan sözleşme (DEĞİŞTİRME, kullan)
- `Workout.finishedAt` (`lib/data/models/workout.dart`; `fromMap`/`toMap` `finished_at` sütununu okur/yazar).
- `WorkoutRepository.setWorkoutFinishedAt(int workoutId, DateTime? finishedAt)`; `FakeWorkoutRepository` uygulaması hazır.
- `lib/data/rest/rest_notifier.dart`: MethodChannel `exercise_tracker/rest` metot adları ve argümanları orada.

## Dokunabileceğin dosyalar
- `lib/data/services/database_service.dart`
- `lib/data/repositories/sqlite_workout_repository.dart`
- `lib/data/models/backup_data.dart`, `lib/data/backup/backup_json_codec.dart`, `lib/data/backup/backup_csv_exporter.dart`
- `test/` altında bunların testleri (yeni dosya ekleyebilirsin; var olan sqlite/backup testlerini güncelleyebilirsin)
- Yeni: `android/app/src/main/kotlin/com/dogukantufan00/exercise_tracking_app/RestNotifications.kt`
- `android/app/src/main/kotlin/com/dogukantufan00/exercise_tracking_app/MainActivity.kt` (yalnızca kanalı kaydetmek için)
- `android/app/src/main/AndroidManifest.xml` (yalnızca izinler)

## 1. Şema 4
- `schemaVersion` 4. `_onCreate` yeni kurulumda `workouts.finished_at TEXT` sütununu içerir; `_onUpgrade` `oldVersion < 4`
  için `ALTER TABLE workouts ADD COLUMN finished_at TEXT` çalıştırır (önceki adımlar aynen kalır, 1→4 de çalışmalı).
- **Geçiş testi zorunlu:** gerçek bir v3 veritabanı oluştur (önceki şemayla, `sqflite_common_ffi`; var olan v2→v3 testinin
  desenine bak), içine antrenman + set koy, `DatabaseService` ile aç; veri aynen duruyor ve `finished_at` `NULL` olmalı.

## 2. `SqliteWorkoutRepository`
- `setWorkoutFinishedAt`: `UPDATE workouts SET finished_at = ? WHERE id = ?` (ISO 8601, `null` → NULL). Antrenman yoksa sessiz.
- Özet ve detay sorguları `finished_at`'i de okumalı (`Workout.fromMap`). `SELECT w.*` değilse sütunu ekle.
- `exportBackup`/`importBackup` `finished_at`'i taşır.
- Testler: yaz/oku/kaldır, olmayan id, özet ve detayda görünme.

## 3. Yedek biçimi 4
- `BackupData.currentFormatVersion` 4. JSON'da her antrenmanda `"finished_at"` (yoksa `null`). Okurken 1–3'te alan yoktur → `null`;
  4'te alan zorunlu değil, varsa ISO metni olmalı (bozuksa mevcut hata deseniyle `FormatException`).
- CSV: son sütun `finished_at` (boşsa boş hücre). Başlık satırını ve testleri güncelle.
- Testler: 4 gidiş-dönüş, 3 biçimli eski yedeğin okunması, CSV başlığı.

## 4. Telefonun dinlenme bildirimi (Kotlin, `RestNotifications.kt`)
- `MainActivity.configureFlutterEngine` içinde MethodChannel `exercise_tracker/rest`'i kaydet; işleyiş `RestNotifications`
  sınıfında olsun (Activity referansı yalnızca izin isteği için).
- Bildirim kanalları (Android 8+ ilk kullanımda oluştur):
  - `rest_countdown`: ad "Dinlenme sayacı", `IMPORTANCE_LOW`, ses ve titreşim yok.
  - `rest_done`: ad "Dinlenme bitti", `IMPORTANCE_HIGH`, titreşim açık (desen: 0,300,150,300), ses yok.
- `showCountdown(endsAtMillis, totalSeconds, title)`: platform `Notification.Builder` (androidx gerekmez), küçük ikon
  `R.mipmap.ic_launcher`, metin "Dinlenme", `setUsesChronometer(true)`, `setChronometerCountDown(true)` (API 24+),
  `setWhen(endsAtMillis)`, `setShowWhen(true)`, `setOngoing(true)`, `setOnlyAlertOnce(true)`,
  `setTimeoutAfter(max(0, endsAtMillis - now))`, dokununca uygulamayı açan `PendingIntent` (`FLAG_IMMUTABLE`). Sabit bildirim id 7001.
- `cancel`: 7001'i kaldırır.
- `notifyFinished(vibrate)`: 7001'i kaldırır; `vibrate` true ise: bildirim izni varsa `rest_done` kanalında "Dinlenme bitti"
  bildirimi (id 7002, `setAutoCancel(true)`, `setTimeoutAfter(15000)`), izin yoksa doğrudan `Vibrator`
  (`VibrationAttributes.USAGE_ALARM` API 33+, öncesinde `AudioAttributes.USAGE_ALARM`) ile aynı desen. `false` ise bir şey yapma.
- `requestPermission`: API < 33 → `true`. API 33+: izin varsa `true`; yoksa `ActivityCompat` KULLANMADAN
  `activity.requestPermissions(arrayOf(POST_NOTIFICATIONS), 7003)` çağır ve hemen `false` dön (sonucu beklemek gerekmez).
- Hatalar `result.success(null)`/`false` ile yutulur; Dart'a exception gitmesin.
- Manifest: `android.permission.POST_NOTIFICATIONS`, `android.permission.VIBRATE`.
- APK derleme (Kotlin doğrulaması) orkestratör tarafından kullanıcının terminalinde yapılır; sen derleme çalıştırma.
  Kodu dikkatle yaz: import'lar tam, API seviyesi kontrolleri (`Build.VERSION.SDK_INT`) eksiksiz.

## Doğrulama
- `flutter analyze` (dosyaların) ve `flutter test --timeout 60s <testlerin>`; ayrıca `test/data` klasörünün tamamı geçmeli.
