# Mimari

Bu belge uygulamanın teknik planıdır. Kod yazan herkes (insan ya da ajan) buradaki kurallara uyar.
Tasarım kuralları için bkz. [DESIGN.md](DESIGN.md).

## 1. Kapsam (MVP)

- Antrenman başlatma; başlık isteğe bağlı, boşsa tarih + saat gösterilir
- Antrenmana serbestçe hareket ekleme (katalogdan seç ya da yeni oluştur)
- Her harekete set ekleme: ağırlık (kg) + tekrar
- Her hareket için tek bir not alanı
- Geçmiş antrenmanları listeleme, görüntüleme, düzenleme, silme
- "Geçen sefer" ipucu: bir hareketin bir önceki antrenmandaki setleri
- 4 renk teması, seçim kalıcı olarak saklanır

**MVP sonrası eklenenler:** katlanabilir hareket kartları; CSV dışa aktarma ve JSON yedek/geri yükleme
(issue #1, bkz. §10).

**v0.2.0 ile eklenenler:** ilerleme grafikleri, kişisel rekorlar ve antrenmanda rekor vurgusu (#3, bkz. §12),
hareket düzenleme (#10).

**v0.3.0 ile eklenenler:** alt gezinme çubuğu (#13), profil ve vücut ölçümleri (#14, şema 2), haftalık gruplama (#15).

**v0.4.0 ile eklenenler:** programlar (#16, şema 3; bkz. §14).

**Henüz yok:** giriş sistemi, backend, kas grubu yüzde analizi
(yapılacaklar GitHub Issues'ta).

## 2. Teknoloji

| Konu | Seçim |
|---|---|
| Dil / framework | Dart + Flutter (Android öncelikli, iOS uyumlu) |
| Veritabanı | `sqflite` (SQLite, SQL elle yazılır) + `path` |
| Durum yönetimi | `ChangeNotifier` + `provider` |
| Basit ayarlar | `shared_preferences` (seçili tema) |
| Tarih biçimi | `intl` (tr_TR) |
| Navigasyon | Flutter'ın yerleşik `Navigator` (`push` / `pop`) |
| Grafik | `fl_chart` (bkz. §12) |

## 3. Katmanlar

```
UI katmanı      View (Widget)  →  ViewModel (ChangeNotifier)
                                        │ sadece Repository arayüzünü tanır
Veri katmanı    Repository (abstract)  →  SqliteWorkoutRepository  →  DatabaseService (sqflite)

Alan (domain)   lib/domain/ — saf Dart hesaplamalar (ilerleme, rekorlar); ViewModel'ler kullanır
```

Kurallar:
1. **View** sadece çizer ve kullanıcı olaylarını ViewModel'e iletir. View içinde veritabanı ya da iş mantığı olmaz.
2. **ViewModel** ekranın durumunu tutar, Repository'yi çağırır, `notifyListeners()` ile ekranı yeniler.
3. **ViewModel'ler somut sınıfı değil, `WorkoutRepository` arayüzünü** kullanır. Böylece ileride backend gelirse sadece yeni bir Repository yazılır.
4. **SQL yalnızca `DatabaseService` ve `SqliteWorkoutRepository` içinde** bulunur.
5. Modeller değişmezdir (`final` alanlar, `copyWith`), `toMap()` / `fromMap()` içerir.
6. **`lib/domain/`** Flutter'ı ve veritabanını import etmez; yalnızca modelleri alır, sonuç döner.

## 4. Veri modeli

```
workouts 1 ──< N workout_exercises N >── 1 exercises
                        │
                        1
                        │
                        N
                  exercise_sets
```

```sql
CREATE TABLE exercises (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL UNIQUE COLLATE NOCASE,  -- "Bench Press" = "bench press"
  muscle_group  TEXT    NOT NULL                         -- MuscleGroup enum adı
);

CREATE TABLE workouts (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  started_at  TEXT    NOT NULL,   -- ISO 8601, yerel saat
  title       TEXT                -- NULL ise UI tarih + saat gösterir
);

CREATE TABLE workout_exercises (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  workout_id   INTEGER NOT NULL REFERENCES workouts(id)  ON DELETE CASCADE,
  exercise_id  INTEGER NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
  position     INTEGER NOT NULL,  -- antrenman içindeki sıra (0'dan başlar)
  note         TEXT
);
CREATE INDEX idx_we_workout  ON workout_exercises(workout_id);
CREATE INDEX idx_we_exercise ON workout_exercises(exercise_id);

CREATE TABLE exercise_sets (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  workout_exercise_id  INTEGER NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
  set_number           INTEGER NOT NULL,  -- 1'den başlar
  weight_kg            REAL    NOT NULL CHECK (weight_kg >= 0),
  reps                 INTEGER NOT NULL CHECK (reps > 0)
);
CREATE INDEX idx_sets_we ON exercise_sets(workout_exercise_id);
```

**Şema 2 (v0.3.0, #14): vücut ölçümleri.** Mevcut tablolara dokunulmaz; yalnızca şunlar eklenir:

```sql
CREATE TABLE measurement_types (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  unit         TEXT    NOT NULL,
  position     INTEGER NOT NULL,          -- listedeki sıra
  builtin_key  TEXT    UNIQUE             -- 'weight', 'right_arm'…; kullanıcı türlerinde NULL
);

CREATE TABLE body_measurements (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  type_id      INTEGER NOT NULL REFERENCES measurement_types(id) ON DELETE CASCADE,
  measured_at  TEXT    NOT NULL,          -- ISO 8601, yerel saat
  value        REAL    NOT NULL CHECK (value > 0)
);
CREATE INDEX idx_measurements_type ON body_measurements(type_id, measured_at);
```

**Şema 3 (v0.4.0, #16): programlar.** Yeni tablolar ve mevcut iki tabloya yalnızca **boş (NULL) sütun** eklenir;
mevcut satırların değerleri değişmez:

```sql
CREATE TABLE programs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  is_active   INTEGER NOT NULL DEFAULT 0 CHECK (is_active IN (0, 1)),
  created_at  TEXT    NOT NULL           -- ISO 8601; sıralama için
);

CREATE TABLE program_days (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  program_id  INTEGER NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL,
  weekday     INTEGER CHECK (weekday BETWEEN 1 AND 7),   -- 1 = Pazartesi; NULL = güne bağlı değil
  position    INTEGER NOT NULL
);
CREATE INDEX idx_program_days_program ON program_days(program_id);

CREATE TABLE program_day_exercises (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  program_day_id    INTEGER NOT NULL REFERENCES program_days(id) ON DELETE CASCADE,
  exercise_id       INTEGER NOT NULL REFERENCES exercises(id)    ON DELETE RESTRICT,
  position          INTEGER NOT NULL,
  target_sets       INTEGER NOT NULL CHECK (target_sets > 0),
  target_reps       INTEGER NOT NULL CHECK (target_reps > 0),
  target_weight_kg  REAL    CHECK (target_weight_kg >= 0)
);
CREATE INDEX idx_program_day_exercises_day ON program_day_exercises(program_day_id);

ALTER TABLE workouts          ADD COLUMN program_day_id   INTEGER REFERENCES program_days(id) ON DELETE SET NULL;
ALTER TABLE workout_exercises ADD COLUMN target_sets      INTEGER;
ALTER TABLE workout_exercises ADD COLUMN target_reps      INTEGER;
ALTER TABLE workout_exercises ADD COLUMN target_weight_kg REAL;
```

Yerleşik türler (`builtinMeasurementTypes`, `lib/data/models/measurement.dart`) hem yeni kurulumda (`onCreate`)
hem de 1 → 2 geçişinde (`onUpgrade`) aynı sırayla eklenir. Ölçümler `MeasurementRepository` üzerinden okunur/yazılır.

- SQLite'ta yabancı anahtarlar varsayılan olarak kapalıdır: `onConfigure` içinde `PRAGMA foreign_keys = ON` çalıştırılmalıdır.
- Şema değişikliklerinde `version` artırılır ve `onUpgrade` yazılır; mevcut tablolar silinmez.

**Kas grupları (`MuscleGroup` enum):** `chest` (Göğüs), `back` (Sırt), `legs` (Bacak), `shoulders` (Omuz), `arms` (Kol), `core` (Karın), `other` (Diğer).

**Dart'ta isim çakışması:** set sınıfının adı `ExerciseSet`'tir (`Set` Dart'ın yerleşik tipidir).

## 5. Modeller (`lib/data/models/`)

| Sınıf | Alanlar |
|---|---|
| `MuscleGroup` (enum) | yukarıdaki değerler + Türkçe `label` |
| `Exercise` | `id`, `name`, `muscleGroup` |
| `Workout` | `id`, `startedAt` (`DateTime`), `title` (`String?`) |
| `WorkoutExercise` | `id`, `workoutId`, `exerciseId`, `position`, `note` (`String?`) |
| `ExerciseSet` | `id`, `workoutExerciseId`, `setNumber`, `weightKg` (`double`), `reps` (`int`) |
| `WorkoutSummary` | `workout`, `exerciseCount`, `setCount`, `muscleGroups` (geçmiş listesi için) |
| `WorkoutExerciseDetail` | `workoutExercise`, `exercise`, `sets` (`List<ExerciseSet>`) |
| `WorkoutDetail` | `workout`, `exercises` (`List<WorkoutExerciseDetail>`) |
| `ExerciseSession` | `workout`, `sets` (bir hareketin tek antrenmandaki setleri; ilerleme için) |

## 6. Repository sözleşmesi

`lib/data/repositories/workout_repository.dart` içindeki `abstract interface class WorkoutRepository`
uygulamanın veriye tek giriş kapısıdır. Metotların kesin imzaları o dosyadadır; özetle:

- Antrenman: listele (özet), detay getir, oluştur, başlık güncelle, sil
- Katalog: hareket ara (isim içinde, büyük/küçük harf duyarsız), hareket oluştur
- Antrenmandaki hareket: ekle, notu güncelle, kaldır
- Set: ekle, güncelle, sil
- "Geçen sefer": bir hareketin, verilen antrenmandan önceki son antrenmandaki setleri
- İlerleme: bir hareketin yapıldığı tüm antrenmanlar ve setleri (`getExerciseHistory`, en eskiden en yeniye)

Tema seçimi ayrı tutulur: `SettingsRepository` (`shared_preferences`).

## 7. Klasör yapısı

```
lib/
├── main.dart                     # Provider kurulumu, MaterialApp, tema
├── data/
│   ├── models/                   # sadece veri sınıfları
│   ├── services/
│   │   └── database_service.dart # açma, şema, migration
│   └── repositories/
│       ├── workout_repository.dart          # arayüz (sözleşme)
│       ├── sqlite_workout_repository.dart   # SQLite uygulaması
│       └── settings_repository.dart
├── domain/
│   └── progress.dart             # tahmini 1RM, antrenman başına değerler, kişisel rekorlar
└── ui/
    ├── core/
    │   ├── theme/                # AppTheme, 4 tema, renk/yazı tanımları
    │   └── widgets/              # ortak bileşenler (stepper, kas grubu etiketi…)
    ├── history/                  # Geçmiş ekranı + ViewModel
    ├── workout/                  # Antrenman ekranı + ViewModel
    ├── exercise_picker/          # Hareket seç ekranı + ViewModel
    ├── exercise_detail/          # Hareket detay (rekorlar, grafik) ekranı + ViewModel
    ├── exercises/                # Hareketler listesi ekranı + ViewModel
    └── settings/                 # Ayarlar (tema) ekranı + ViewModel
test/                             # lib/ ile aynı klasör yapısı
```

## 8. Ekranlar ve akış

```
Geçmiş ──(+)──► Antrenman ──(Hareket ekle)──► Hareket seç
   │  ◄──geri──┘    ▲                              │
   │                └──────(seçilen hareket)───────┘
   ├──(ayarlar simgesi)──► Ayarlar
   └──(Hareketler simgesi)──► Hareketler ──► Hareket detayı
                                                ▲
Antrenman ──(kart ⋮ > İlerleme)─────────────────┘
```

- **Geçmiş:** antrenman kartları (başlık ya da tarih, hareket/set sayısı, kas grubu etiketleri), boş durum, ekle butonu.
- **Antrenman:** yeni ve mevcut antrenman için aynı ekran. Hareketler, setler, ±'li ağırlık/tekrar girişi
  (ağırlık adımı 2,5 kg, tekrar adımı 1), "Seti tekrarla", "geçen sefer" ipucu, hareket notu.
  Değişiklikler anında veritabanına yazılır, ayrı bir "Kaydet" adımı yoktur.
- **Hareket seç:** arama kutusu, eşleşen hareketler, eşleşme yoksa kas grubu seçerek yeni hareket oluşturma.
- **Ayarlar:** 4 tema seçeneği.
- **Hareket detayı:** kişisel rekorlar kartı, metrik seçimi + çizgi grafik (en az iki antrenman gerekir),
  antrenman antrenman setler (en yeni üstte).
- **Hareketler:** katalogdaki tüm hareketler (Türkçe duyarlı arama, kas grubu etiketi); dokununca hareket detayı.

## 9. Kod kuralları

- `flutter analyze` uyarısız geçmelidir; `flutter_lints` kuralları geçerlidir.
- Her ViewModel ve Repository için `test/` altında birim testi yazılır.
- Renk, yazı tipi, boşluk değerleri **asla** sabit yazılmaz; `Theme.of(context)` ve
  `ui/core/theme` içindeki sabitler kullanılır (bkz. DESIGN.md).
- Kullanıcıya görünen metinler Türkçedir; kod, sınıf ve değişken adları İngilizcedir.
- Bir dosya yalnızca kendi katmanının dosyalarını import eder (UI → data serbest, data → UI yasak).
- Widget testleri gerçek telefon boyutunda da çalıştırılır (360 × 780, yazı ölçeği 1.3); taşma olmamalı.

## 10. Yedekleme (dışa/içe aktarma)

```
Ayarlar > Veriler ──► BackupViewModel ──► WorkoutRepository.exportBackup / importBackup
                            │                 (BackupData: id'siz, hareketlere adla başvurur)
                            ├──► backup_json_codec   (JSON ⇄ BackupData, format_version'lı)
                            ├──► backup_csv_exporter (BackupData → CSV, yalnızca dışa aktarma)
                            └──► BackupFileService   (share_plus ile paylaş, file_picker ile seç)
```

- **CSV** paylaşım ve tablo programları içindir; **JSON** eksiksiz yedektir ve içe aktarma yalnızca JSON ile yapılır.
- İçe aktarma **birleştirir**: aynı başlangıç zamanlı antrenman atlanır, hareketler `normalizeForSearch` ile
  eşleştirilir, mevcut veri silinmez. Doğrulama yazmadan önce yapılır; SQLite tarafı tek transaction'dır
  (ya hep ya hiç).
- `BackupFileService` platforma bağlı tek parçadır; testlerde sahtesi kullanılır, mantığın tamamı ViewModel'dedir.
- JSON biçimi değişirse `BackupData.currentFormatVersion` artırılır ve eski sürümleri okuma desteği korunur.
- Biçim 2 (#14): JSON, kullanıcının eklediği ölçüm türlerini (`measurement_types`) ve tüm ölçümleri (`measurements`)
  içerir. Biçim 1 yedekler okunmaya devam eder (ölçüm listeleri boş). Geri yüklemede önce antrenmanlar, sonra
  ölçümler içe aktarılır; her biri kendi transaction'ında (ya hep ya hiç). CSV yalnızca antrenmanları yazar.
- Biçim 3 (#16): JSON, `programs` listesini içerir (programlar, günler ve hedefler; hareketlere adla başvurulur,
  `weekday` ve `weight_kg` `null` olabilir). Biçim 1 ve 2 yedekler okunmaya devam eder (programlar boş). Geri
  yüklemede sıra antrenmanlar → ölçümler → programlar; her biri kendi transaction'ında.

## 11. Sürümleme ve yayın

Sürüm `pubspec.yaml` içindeki `version: X.Y.Z+N` satırındadır:

- **`X.Y.Z` (sürüm adı, kullanıcının gördüğü):** [Semantic Versioning](https://semver.org/lang/tr/).
  - `Z` (yama): yalnızca hata düzeltmesi.
  - `Y` (küçük): yeni özellik; eski veri ve yedekler çalışmaya devam eder.
  - `X` (büyük): uyumsuz değişiklik. `0.x` dönemindeyiz: uygulama alfa/beta aşamasında, her şey değişebilir.
    `1.0.0` mağazaya çıkan ilk kararlı sürüm olacak.
- **`+N` (yapı numarası):** her yayında 1 artar, **hiç geri dönmez ve sıfırlanmaz** (Play Store / App Store
  aynı numarayı ikinci kez kabul etmez).

Aşamalar sürüm adına ek olarak yazılmaz; Git etiketi ve GitHub Release ile gösterilir:
`v0.2.0-beta.1` gibi bir etiket ve GitHub'da "Pre-release" işareti.

**Yayın adımları:**

1. `CHANGELOG.md` içindeki `[Yayınlanmamış]` başlığı altındakileri yeni sürüm başlığına taşı.
2. `pubspec.yaml` sürümünü güncelle (`X.Y.Z` kurala göre, `+N` bir artır).
3. `flutter analyze` ve `flutter test` temiz olmalı.
   **Release APK'yı gerçek telefonda aç** (`adb install -r` + uygulamayı başlat, Ayarlar'ı aç):
   testler küçültülmemiş kodla çalışır, R8'in yol açtığı hataları yakalayamaz (bkz. 0.2.0-beta.2).
4. Commit: `Release vX.Y.Z`.
5. Açıklamalı etiket at ve gönder: `git tag -a vX.Y.Z -m "vX.Y.Z"` → `git push origin main --tags`.
6. APK'yı derle (`flutter build apk --release`) ve GitHub Release oluştur:
   `gh release create vX.Y.Z exercise-tracking-app-vX.Y.Z.apk --title vX.Y.Z --notes "<CHANGELOG bölümü>"`
   (beta için `--prerelease`).

**İmzalama:** Release APK, `android/key.properties` dosyasında adı geçen yayın anahtarıyla imzalanır
(keystore: `C:\Users\user\keystores\exercise_tracking_app.jks`). İkisi de repo'ya girmez ve **yedeklenmelidir**:
anahtar kaybolursa yeni sürümler eskinin üstüne kurulamaz, uygulamayı silip yeniden kurmak gerekir.
`key.properties` yoksa (ör. CI'da) release derlemesi debug anahtarıyla imzalanır; o APK yayınlanmaz.

**Küçültme (R8):** Release derlemesi kodu küçültür ve adları kısaltır. Dart'tan JNI ile adıyla çağrılan
sınıflar `android/app/proguard-rules.pro` ile korunur. JNI kullanan yeni bir eklenti eklenirse
(`package:jni`'ye bağımlı) paket adı bu dosyaya eklenir.

Eski sürümler silinmez: her etiket o andaki kodun kalıcı adresidir (`git checkout vX.Y.Z` ile geri dönülür,
GitHub'da etiket sayfasından indirilir).

Gündelik commit'lerde sürüm değişmez; yalnızca `CHANGELOG.md` → `[Yayınlanmamış]` başlığına satır eklenir.

## 12. İlerleme ve kişisel rekorlar (issue #3)

Yeni tablo yoktur; her şey `exercise_sets` verisinden hesaplanır (`lib/domain/progress.dart`).

- **Ana metrik: tahmini 1RM**, Epley formülüyle `ağırlık × (1 + tekrar / 30)`; tek tekrarda ağırlığın kendisi.
  Farklı tekrar sayılarındaki setleri karşılaştırılabilir kılar; ~12 tekrarın üstünde isabeti düşer.
  Grafikte seçilebilen diğer metrikler: **en ağır set** ve **toplam hacim** (Σ ağırlık × tekrar).
- **Grafikte bir nokta = bir antrenman** (`SessionStats`: o antrenmandaki en iyi değer).
  Ağırlıksız hareketlerde (hep 0 kg) grafik en çok tekrarı gösterir.
- **Kişisel rekorlar:** en ağır ağırlık, en iyi tahmini 1RM, tek antrenmandaki en yüksek hacim.
  Eşitlikte rekor ilk ulaşılan antrenmanda kalır; değeri 0 olan rekor yoktur (null).
- **Grafik paketi:** `fl_chart`; renkler `Theme.of(context)`'ten verilir. (`CustomPaint` ile elle çizim
  ileride öğrenme alıştırması olarak denenecek, #9.)
- **Giriş noktası:** hareket kartının ⋮ menüsü ve Geçmiş'ten açılan "Hareketler" ekranı
  (karta dokunmak kartı açıp kapatır).
- Adımlar: #5 veri ve hesaplama → #6 detay ekranı → #7 giriş noktaları → #8 antrenmanda rekor vurgusu.
  Hepsi v0.2.0 ile yayınlanır.

## 13. Yol haritası ve kararlar (2026-10-23)

Sıra (her madde bir GitHub issue'su):

1. **#10 Hareket düzenleme:** katalogdaki hareketin adı ve kas grubu düzeltilebilir; değişiklik tüm geçmişe
   yansır (setler harekete id ile bağlı). Şema değişmez.
2. **#8 Antrenmanda rekor vurgusu** → **v0.2.0**.
3. **#13 Alt gezinme çubuğu**, **#14 Profil ve ölçümler**, **#15 Haftalık gruplama** → **v0.3.0**.
   - Ölçümler: Kilo, Boy, Sağ/Sol kol, Sağ/Sol bacak, Bel, Göğüs, Kalça, Boyun + kullanıcının eklediği
     sınırsız özel ölçüm (ad + birim). Her ölçüm tarihli kayıttır.
   - #14 uygulamanın **ilk şema geçişi** (v1 → v2): yalnızca yeni tablolar, mevcut veri değişmez;
     bir v1 veritabanını yükselten migration testi zorunlu. Yedek biçimi `format_version` 2 olur, 1 okunmaya devam eder.
   - Haftalık gruplama tarihten hesaplanır (Pazartesi–Pazar), veri değişmez. Kullanıcının kendi grupları şimdilik yok.
4. **#16 Program** → **v0.4.0**. **Karma model:** günler haftanın günlerine göre planlanır, antrenman başlatırken
   bugünün günü önerilir ama programdaki herhangi bir gün seçilebilir. "Kaçırıldı" işareti, seri ya da uyarı yok;
   gün kaçırmak cezalandırılmaz.
5. Sonra: **#11** antrenmanda hareketi değiştirme, **#12** aynı hareketin iki kaydını birleştirme, kullanıcı grupları.

## 14. Programlar (#16)

- **Karma model:** program günleri isteğe bağlı olarak haftanın bir gününe bağlanır (`weekday`). Antrenman
  başlatırken etkin programın bugüne denk gelen günü önerilir (`suggestedDay`, `lib/domain/program_schedule.dart`),
  ama programın **herhangi bir günü** başlatılabilir. Kaçırılan gün, seri ya da uyarı tutulmaz.
- Birden çok program olabilir; **en fazla biri etkin**. İlk oluşturulan program kendiliğinden etkin olur.
- Programdan başlatılan antrenman: başlık = gün adı, `workouts.program_day_id` ile güne bağlı, hareketler sırayla
  eklenir ve her birinin hedefi `workout_exercises.target_*` sütunlarına **kopyalanır**. Program sonradan
  değişse ya da silinse de eski antrenmanın hedefleri değişmez.
- Antrenmanda hareket kartı hedefi gösterir ("Hedef: 3 × 10 · 40 kg"); ilk setin taslağı hedeften gelir
  (ağırlık hedefi yoksa "geçen sefer"den).
- Veriye `ProgramRepository` ile erişilir (`lib/data/repositories/program_repository.dart`).
- Yedek biçimi 3 programları içerir (hareketlere adla başvurarak); antrenmanların program bağlantısı ve kopyalanmış
  hedefleri yedeğe girmez.

## 15. Saat uygulaması (Wear OS)

Galaxy Watch (Wear OS 3+) için telefon uygulamasıyla birlikte çalışan bir eşlikçi uygulama. Kararlar (2026-11-21):

- **Telefondaki SQLite tek doğru kaynaktır.** Saatin veritabanı yoktur; saat bir "uzaktan kumanda + sensör"dür.
  Saat olay gönderir ("set eklendi"), kaydı telefon yazar. Böylece iki veritabanını eşitleme (çakışma çözümü) gerekmez.
- **Saat tarafı Kotlin + Compose for Wear OS** ile yazılır (`wear/`, bağımsız Gradle projesi). Flutter'ın Wear OS
  desteği (Tile, ortam modu, Health Services) yetersiz.
- **İletişim: Wearable Data Layer API** (`play-services-wearable`). Hazır Flutter paketi kullanılmaz; telefonda küçük
  bir Kotlin köprüsü ile Dart arasında `MethodChannel` + `EventChannel` vardır.
- **Aynı kimlik ve imza:** Data Layer yalnızca aynı paket adı ve aynı imza anahtarıyla derlenmiş uygulamaları eşler.
  Saat uygulamasının `applicationId`'si de `com.dogukantufan00.exercise_tracking_app`'tir (genel `io.github…`
  kuralının istisnası: telefon uygulaması bu kimlikle yayında) ve release'i aynı keystore ile imzalanır (§11).
  Saatin `versionCode`'u telefonla çakışmasın diye `2000000 + N` aralığındadır. Telefonun yapı numarası
  2026-11-22'de 7'den 1002'ye atladı: saat APK'sı (1001) yanlışlıkla telefona kurulmuştu ve veriyi silmeden geri
  dönmenin tek yolu daha büyük numaraydı. Numara yalnızca artar (§11).

### 15.1 Fazlar

| Faz | Kapsam | Issue |
|---|---|---|
| 1 | Antrenman kumandası: telefonda açık antrenman saatte görünür; saatte ağırlık/tekrar girip set ekleme ve silme; saatte dinlenme sayacı + titreşim | #24 |
| 2 | Saatten antrenman başlatma (program günü seçerek), bugünün programını gösteren Tile, Ongoing Activity ve ekran kapalıyken de güvenilir dinlenme sayacı | #25 |
| 3 | Health Services: nabız, kalori, antrenman süresi (#22 ile birlikte); saklamak için şema 4 | #26 |
| Sonra | Telefonsuz çalışan saat (iki yönlü eşitleme gerektirir) | — |

### 15.2 Bileşenler

```
Telefon (Flutter)
  WorkoutViewModel ──(antrenman değişti)──► WatchSyncService ◄── WearChannel (abstract, Dart)
  WatchSyncService ── WorkoutRepository (set ekle/sil) + buildWatchSnapshot (anlık durum)
                                                   │ MethodChannel "exercise_tracker/wear"
                                                   │ EventChannel  "exercise_tracker/wear/events"
  WearBridge (Kotlin) ── PhoneWearListenerService (mesajları alır, yerel kuyruğa yazar)
                                                   │ Data Layer (Bluetooth / Wi-Fi)
Saat (Kotlin)
  PhoneSyncRepository (DataItem dinler, olay kuyruğu, gönderim) ──► WatchUiState (StateFlow)
  Ekranlar ── WatchWorkoutViewModel ── dinlenme sayacı + titreşim
```

### 15.3 Etkin antrenman

Telefonda bilinçli bir "antrenmanı bitir" adımı yoktur; bu yüzden:

- **Etkin antrenman = Antrenman ekranında en son açılan antrenman.** Ekran açılınca `WatchSyncService.setActiveWorkout(id)`
  çağrılır; id `shared_preferences`'ta saklanır (uygulama yeniden başlarsa da bilinir).
- Ekrandan çıkmak etkinliği bitirmez (telefon cepteyken yanlışlıkla geri tuşu saati boşaltmasın).
- Antrenman silinirse ya da başlangıcının üzerinden **12 saat** geçmişse etkin antrenman temizlenir ve saat boş durumu
  gösterir. Bu kontrol her yayından önce ve uygulama açılışında yapılır.

### 15.4 Protokol (sürüm 1)

Tüm yükler UTF-8 JSON'dur; alan adları camelCase. Dart tarafı `lib/data/watch/watch_protocol.dart`, Kotlin tarafı
`wear/app/src/main/java/com/dogukantufan00/exercise_tracking_app/data/WatchProtocol.kt`; ikisi **birebir aynı** olmalıdır.
Tarihler saat dilimsiz ISO 8601 yerel saattir (`DateTime.toIso8601String()`).

**Telefon → saat: anlık durum (DataItem, yol `/workout/active`).** Telefon her değişiklikte tamamını yeniden yazar
(`setUrgent`). Etkin antrenman yoksa DataItem silinir. DataItem kalıcıdır: saat bağlantı koptuktan sonra
geri geldiğinde son durumu kendiliğinden alır. JSON, DataMap'te `json` anahtarında tek metin olarak durur.

```json
{
  "protocol": 1,
  "workoutId": 42,
  "title": "Push A",
  "startedAt": "2026-11-21T18:30:00.000",
  "appliedEventIds": ["5b0e…", "…"],
  "exercises": [
    {
      "workoutExerciseId": 101,
      "name": "Bench Press",
      "target": { "sets": 3, "reps": 10, "weightKg": 40.0 },
      "sets": [ { "id": 900, "setNumber": 1, "weightKg": 40.0, "reps": 10 } ],
      "draft": { "weightKg": 40.0, "reps": 10 },
      "previous": [ { "weightKg": 37.5, "reps": 10 } ]
    }
  ]
}
```

- `title`: antrenman başlığı, yoksa telefonun gösterdiği tarih metni (saat biçimlendirme yapmaz).
- `target`, `target.weightKg`: yoksa `null`. `previous`: "geçen sefer" setleri (boş olabilir). `exercises` sıralıdır (`position`).
- `draft`: telefondaki taslak kuralıyla (`lib/domain/set_draft.dart`) hesaplanan bir sonraki set önerisi.
- `appliedEventIds`: telefonun işlediği son en fazla 50 olayın id'si (saat bekleyen olaylarını bununla temizler).

**Saat → telefon: olaylar (MessageClient, yol `/event`).** Her olayın saatte üretilen bir UUID'si vardır.

```json
{ "protocol": 1, "eventId": "uuid", "type": "addSet", "workoutId": 42,
  "workoutExerciseId": 101, "weightKg": 40.0, "reps": 10, "createdAt": "2026-11-21T18:41:05.000" }
{ "protocol": 1, "eventId": "uuid", "type": "deleteSet", "workoutId": 42, "setId": 900,
  "createdAt": "2026-11-21T18:42:00.000" }
{ "protocol": 1, "eventId": "uuid", "type": "finishWorkout", "workoutId": 42,
  "createdAt": "2026-11-22T19:30:00.000" }
```

- `finishWorkout` (2026-11-22, kullanıcı kararı): saatte "Antrenmanı bitir" + onay. Telefon, `workoutId` etkin
  antrenmansa etkinliği kaldırır (anlık durum silinir); antrenman kaydı ve setler değişmez, bitiş saati saklanmaz
  (süre #22'nin işi). Aynı turda bitirmeden sonra gelen set olayları yok sayılır. Saat, bekleyen bitirme olayı varken
  o antrenmanı hemen gizler (iyimser durum `null`); servis, sayaç ve Ongoing Activity böylece kapanır.
  Telefonda antrenman yeniden açılırsa yine etkin olur.

Kurallar:
- **Etkisi tam bir kez:** telefon işlediği olay id'lerini (son 200) saklar; aynı id ikinci kez gelirse yok sayar.
  Saat bu yüzden bir olayı onay görene kadar gönül rahatlığıyla tekrar gönderebilir.
- Olay etkin olmayan bir antrenmana ya da artık var olmayan bir harekete/sete aitse, ya da değerleri geçersizse
  (`weightKg < 0`, `reps <= 0`) **işlenmiş sayılır ve yok sayılır** (saat bekleyen olayı böylece düşürür).
- Telefon olayları işledikten sonra anlık durumu yeniden yayınlar; açık olan Antrenman ekranı da yenilenir.
- `protocol` farklı olan olay ve anlık durum yok sayılır.

**Yetenekler (capability):** telefon `exercise_tracker_phone`, saat `exercise_tracker_watch` yeteneğini
`res/values/wear.xml` içinde duyurur. Saat olayları `exercise_tracker_phone` yeteneğine sahip düğüme gönderir.

### 15.5 Telefon tarafı (Flutter + Kotlin)

- **Uygulama kapalıyken de olay kaybolmaz:** `PhoneWearListenerService` (WearableListenerService) her olayı önce
  yerel bir kuyruğa (SharedPreferences'ta JSON dizisi) yazar; Flutter çalışıyorsa `EventChannel` ile "yeni olay var"
  der. Dart `drainEvents()` ile kuyruğu okur, işler, `ackEvents(ids)` ile siler. Uygulama açılışında da kuyruk boşaltılır.
  Telefon cepte ve ekran kilitliyken Flutter süreci genelde canlıdır; değilse olaylar bir sonraki açılışta işlenir
  (saat bu arada kendi iyimser durumunu gösterir).
- **Uygulama kapalıyken arka planda işleme (2026-11-22, kullanıcı kararı):** olay kuyruğa yazılınca uygulamanın
  Flutter'ı dinlemiyorsa (`WearEventNotifier.sink == null`) `WearBackgroundRunner` ekransız bir `FlutterEngine`
  başlatır ve `main.dart`'taki `@pragma('vm:entry-point') wearBackgroundMain`'i çalıştırır. Bu, aynı
  `WatchSyncService` ile `processPendingEvents()` yapar (anlık durum ve `/events/applied` yayınlanır),
  veritabanını kapatır ve `backgroundDone` der; motor kapatılır (en geç 30 sn). İş mantığı tek yerde (Dart) kalır;
  saat uygulaması değişmez. Motor çalışırken yeni olay gelirse bitince bir tur daha çalışır.
  Çakışma önlemi: motor çalışırken uygulamanın `drainEvents` çağrısı boş döner, motor bitince kuyruk yeniden
  bildirilir; `PrefsWatchSyncStore` her okumada `reload()` ile diski okur (iki motorun önbelleği ayrışmasın).
  Köprü kodu `WearBridge.kt`'tedir (`MainActivity` ve ekransız motor ortak kullanır). Android pil kısıtları
  servisi geciktirirse olay yine uygulama açılınca işlenir; saatin "Telefonda uygulamayı aç" ekranı bu durum için
  yedek olarak kalır.
- `WearChannel` (Dart, abstract, `lib/data/watch/wear_channel.dart`): gerçeği `MethodChannelWearChannel`, testlerde
  `FakeWearChannel`. `BackupFileService` deseninde olduğu gibi mantığın tamamı `WatchSyncService`'tedir ve test edilir.
- `WatchSyncService` (`lib/data/watch/watch_sync_service.dart`): `setActiveWorkout`, `workoutChanged(workoutId)`,
  `processPendingEvents()`, `Stream<int> workoutUpdates` (olaylarla değişen antrenman id'si). `WorkoutViewModel`
  kendi antrenmanının id'si gelince yeniden yüklenir.
- Eşli saat ya da Play Services yoksa platform çağrıları sessizce hiçbir şey yapmaz; telefon uygulaması saat olmadan
  aynen çalışır. Saat tarafındaki hatalar telefonda kullanıcıya hata olarak gösterilmez.

### 15.6 Saat tarafı (Kotlin)

- Katmanlar telefondakine benzer: `data/` (protokol, `PhoneSyncRepository`, olay kuyruğu), `ui/` (ekranlar + ViewModel),
  `domain/` (saf Kotlin: iyimser durum birleştirme). JSON için `kotlinx.serialization`.
- **İyimser durum:** saatte görünen = telefonun son anlık durumu + henüz `appliedEventIds`'te görünmeyen bekleyen olaylar.
  Bekleyen set "bekliyor" simgesiyle gösterilir. Bekleyen olaylar DataStore'da saklanır (saat uygulaması kapansa da kalır)
  ve telefon erişilebilir olunca yeniden gönderilir. Yalnızca telefonun onayladığı (id'si olan) setler silinebilir.
- **Ekranlar (Faz 1):** Boş durum ("Telefonda bir antrenman aç") → Hareket listesi (ilerleme "2/3 set") → Hareket ekranı
  (hedef, geçen sefer, ağırlık ± 2,5 kg ve tekrar ± 1; döner çerçeve odaktaki değeri değiştirir; "Set tamam") →
  Dinlenme sayacı (dairesel ilerleme, ±15 sn, "Atla"; bitince titreşim).
- **Dinlenme süresi** saatte ayarlanır ve saatte saklanır (varsayılan 90 sn). Faz 1'de sayaç çalışırken ekran açık tutulur;
  ekran kapalıyken güvenilir çalışma (foreground service + Ongoing Activity) Faz 2'dedir.
- Saat teması telefonda seçili temayı izler (§15.7). Yazılar Türkçe.
- **Görünüm (2026-11-22, kullanıcı seçimi "A + B"):** DESIGN.md'nin saat karşılığı. Başlık ve sayılar Oswald
  (`res/font/oswald.ttf`, `ui/theme/WatchType.kt`); kartlar dolgusuz ve ince çerçeveli (`CardButton`), ekranda tek dolu
  vurgu düğmesi (bugünün günü / "SET TAMAM" / "ATLA"). Hareket listesinde set halkası, hareket ekranında tek satırda büyük
  "ağırlık × tekrar" (`SetInput`; dokunulan sayı seçilir, döner çerçeve seçili sayıyı değiştirir), dinlenmede kalın
  halka ve büyük sayaç. Dokunma alanları ≥ 48 dp.
- **Test:** `domain/` ve protokol için JVM birim testleri (`gradlew test`); ekranlar gerçek saatte denenir
  (Wi-Fi üzerinden `adb`).

### 15.7 Tema eşleme

Saat, telefonda seçili temayı kullanır (kullanıcı kararı, 2026-11-22).

- **Telefon → saat: DataItem `/settings/theme`**, DataMap'te `themeId` anahtarında `AppThemeId.name`
  (`darkOrange`, `redBlack`, `yellowNavy`, `lightBlue`). Telefon bunu uygulama açılışında ve tema her değiştiğinde
  yazar (`WatchSyncService.publishTheme`, `setUrgent`). Değer aynıysa Data Layer değişiklik bildirmez; ek yük yoktur.
- **Saat:** son temayı kendi SharedPreferences'ına da yazar; açılışta önce bunu kullanır (ilk karede doğru renk),
  sonra DataItem'ı okur ve değişiklikleri dinler. Bilinmeyen ya da eksik değer → `darkOrange`.
- **Renkler telefonun paletinden** (`lib/ui/core/theme/app_palette.dart`) gelir. Saat ekranı OLED'dir; açık zemin
  pil harcar ve gözü yorar. Bu yüzden **açık mavi temada saat koyu zemin kullanır**, vurgu mavidir:

| Tema | background | surface (kart/düğme) | outline | onSurface | muted | primary | onPrimary |
|---|---|---|---|---|---|---|---|
| darkOrange | #121212 | #1E1E1E | #2C2C2C | #F2F2F2 | #9A9A9A | #FF7A1A | #1A0E00 |
| redBlack | #0B0B0B | #191919 | #2A2A2A | #F5F5F5 | #9C9C9C | #E5383B | #FFFFFF |
| yellowNavy | #0F1B2D | #172A44 | #24395A | #EEF2F8 | #93A3BC | #FFC93C | #1E1600 |
| lightBlue (saatte koyu) | #10151D | #1B2430 | #2A3646 | #EEF2F8 | #93A0B2 | #5B8DEF | #FFFFFF |

  Wear Material 3 eşlemesi: `background`/`surfaceContainerLow` = background, `surfaceContainer` = surface,
  `surfaceContainerHigh` = outline, `onBackground`/`onSurface` = onSurface, `onSurfaceVariant` = muted,
  `outline`/`outlineVariant` = outline, `primary`/`onPrimary` aynen, `primaryContainer` = primary'nin %30'u background
  üzerine karıştırılmış, `onPrimaryContainer` = onSurface. Ekranlar renkleri yalnızca `MaterialTheme.colorScheme`'den okur.


### 15.8 Faz 2: saatten başlatma, Tile, arka planda sayaç (#25)

Kararlar (2026-11-22):

**1. Program saatte.** Telefon etkin programı DataItem `/program/active` olarak yayınlar (etkin program yoksa siler):

```json
{ "protocol": 1, "programId": 3, "name": "PPL",
  "days": [ { "dayId": 11, "name": "Push A", "weekday": 1, "exercises": ["Bench Press", "Incline DB Press"] } ] }
```

`weekday` 1 = Pazartesi, `null` = güne bağlı değil. "Bugünün günü" saatte telefonla aynı kuralla hesaplanır
(`suggestedDay`: `weekday`'i bugün olan ilk gün; yoksa öneri yok). Gece yarısı geçince saat kendisi günceller.

**2. Değişiklikleri kaçırmamak için repository sarmalayıcıları.** `WatchAwareWorkoutRepository` ve
`WatchAwareProgramRepository` gerçek repository'leri sarar; her değiştirici çağrıdan sonra `WatchSyncService`'e haber
verir (antrenman → anlık durum, program → `/program/active`). Böylece Geçmiş'ten silme, hareket adı değiştirme,
birleştirme, yedekten geri yükleme ve program düzenleme saate kendiliğinden yansır; ViewModel'lerdeki elle çağrılar
kaldırılır. `WatchSyncService` döngü olmasın diye sarılmamış repository'leri kullanır.

**3. Saatten başlatma: yeni olay `startWorkout`.**

```json
{ "protocol": 1, "eventId": "uuid", "type": "startWorkout", "programDayId": 11, "createdAt": "2026-11-22T18:30:00" }
```

- `programDayId` `null` → boş antrenman. Olayda `workoutId` yoktur; `workoutId` artık yalnızca `addSet`/`deleteSet`'te
  bulunur (protokol 1 içinde geriye uyumlu: eski olay türleri aynı kalır).
- Telefon: gün varsa `startWorkoutFromDay(dayId, startedAt: createdAt)`, `null` ise `createWorkout(startedAt: createdAt)`;
  yeni antrenman etkin olur ve yayınlanır. Gün silinmişse ya da olay 12 saatten eskiyse yok sayılır.
- **Telefon uygulaması kapalıysa olay bekler** (kullanıcı kararı): telefon uygulaması açılınca işlenir. Saat bu arada
  "Telefonda uygulamayı aç" bekleme ekranını gösterir; bekleyen başlatma iptal edilebilir.
- **İşlenen olaylar her zaman yayınlanır:** telefon her olay işleme turundan sonra DataItem `/events/applied`'e
  `{"protocol": 1, "appliedEventIds": [...]}` (son 50) yazar. Böylece yok sayılan bir başlatma (etkin antrenman
  oluşmadığı için anlık durum yokken) de saatin kuyruğundan düşer. Başlatma olayı onaylanınca
  (`appliedEventIds`) saat yeni antrenmanın hareket listesine geçer.

**4. Tile** (`androidx.wear.tiles` + `protolayout`):
- Antrenman sürüyorsa: başlık + "N set" + **Devam et**.
- Değilse ve bugüne planlı gün varsa: "Bugün: Push A · 5 hareket" + **Başla** (doğrudan başlatır).
- Bugüne gün yoksa ya da program yoksa: **Antrenman başlat** (uygulamada gün seçimi / boş antrenman açılır).
- Tile verisi saatteki son anlık durum ve programdan gelir; veri değişince Tile güncellenmesi istenir.

**5. Arka planda güvenilir sayaç: antrenman servisi.** Saatte etkin antrenman varken `WorkoutSessionService`
(foreground service, tür `health`) çalışır; **Ongoing Activity** ile kadranda ve son uygulamalarda simge gösterir.
Dinlenme sayacı bu servise taşınır; ekran kapalıyken de süre bitince titrer. Android 14 `health` türü için ilk
antrenmanda bir kez **Fiziksel aktivite** (`ACTIVITY_RECOGNITION`) ve **bildirim** (`POST_NOTIFICATIONS`) izni istenir
(kullanıcı kararı). İzin verilmezse sayaç Faz 1'deki gibi ekran açıkken çalışır.
