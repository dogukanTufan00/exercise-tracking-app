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

**Henüz yok:** giriş sistemi, backend, program (#16), kas grubu yüzde analizi
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
