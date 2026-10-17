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

**Henüz yok:** giriş sistemi, backend, grafikler, kişisel rekorlar, kas grubu yüzde analizi
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

## 3. Katmanlar

```
UI katmanı      View (Widget)  →  ViewModel (ChangeNotifier)
                                        │ sadece Repository arayüzünü tanır
Veri katmanı    Repository (abstract)  →  SqliteWorkoutRepository  →  DatabaseService (sqflite)
```

Kurallar:
1. **View** sadece çizer ve kullanıcı olaylarını ViewModel'e iletir. View içinde veritabanı ya da iş mantığı olmaz.
2. **ViewModel** ekranın durumunu tutar, Repository'yi çağırır, `notifyListeners()` ile ekranı yeniler.
3. **ViewModel'ler somut sınıfı değil, `WorkoutRepository` arayüzünü** kullanır. Böylece ileride backend gelirse sadece yeni bir Repository yazılır.
4. **SQL yalnızca `DatabaseService` ve `SqliteWorkoutRepository` içinde** bulunur.
5. Modeller değişmezdir (`final` alanlar, `copyWith`), `toMap()` / `fromMap()` içerir.

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

## 6. Repository sözleşmesi

`lib/data/repositories/workout_repository.dart` içindeki `abstract interface class WorkoutRepository`
uygulamanın veriye tek giriş kapısıdır. Metotların kesin imzaları o dosyadadır; özetle:

- Antrenman: listele (özet), detay getir, oluştur, başlık güncelle, sil
- Katalog: hareket ara (isim içinde, büyük/küçük harf duyarsız), hareket oluştur
- Antrenmandaki hareket: ekle, notu güncelle, kaldır
- Set: ekle, güncelle, sil
- "Geçen sefer": bir hareketin, verilen antrenmandan önceki son antrenmandaki setleri

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
└── ui/
    ├── core/
    │   ├── theme/                # AppTheme, 4 tema, renk/yazı tanımları
    │   └── widgets/              # ortak bileşenler (stepper, kas grubu etiketi…)
    ├── history/                  # Geçmiş ekranı + ViewModel
    ├── workout/                  # Antrenman ekranı + ViewModel
    ├── exercise_picker/          # Hareket seç ekranı + ViewModel
    └── settings/                 # Ayarlar (tema) ekranı + ViewModel
test/                             # lib/ ile aynı klasör yapısı
```

## 8. Ekranlar ve akış

```
Geçmiş ──(+)──► Antrenman ──(Hareket ekle)──► Hareket seç
   │  ◄──geri──┘    ▲                              │
   │                └──────(seçilen hareket)───────┘
   └──(ayarlar simgesi)──► Ayarlar
```

- **Geçmiş:** antrenman kartları (başlık ya da tarih, hareket/set sayısı, kas grubu etiketleri), boş durum, ekle butonu.
- **Antrenman:** yeni ve mevcut antrenman için aynı ekran. Hareketler, setler, ±'li ağırlık/tekrar girişi
  (ağırlık adımı 2,5 kg, tekrar adımı 1), "Seti tekrarla", "geçen sefer" ipucu, hareket notu.
  Değişiklikler anında veritabanına yazılır, ayrı bir "Kaydet" adımı yoktur.
- **Hareket seç:** arama kutusu, eşleşen hareketler, eşleşme yoksa kas grubu seçerek yeni hareket oluşturma.
- **Ayarlar:** 4 tema seçeneği.

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
4. Commit: `Release vX.Y.Z`.
5. Açıklamalı etiket at ve gönder: `git tag -a vX.Y.Z -m "vX.Y.Z"` → `git push origin main --tags`.
6. APK'yı derle (`flutter build apk --release`) ve GitHub Release oluştur:
   `gh release create vX.Y.Z exercise-tracking-app-vX.Y.Z.apk --title vX.Y.Z --notes "<CHANGELOG bölümü>"`
   (beta için `--prerelease`).

**İmzalama:** Release APK, `android/key.properties` dosyasında adı geçen yayın anahtarıyla imzalanır
(keystore: `C:\Users\user\keystores\exercise_tracking_app.jks`). İkisi de repo'ya girmez ve **yedeklenmelidir**:
anahtar kaybolursa yeni sürümler eskinin üstüne kurulamaz, uygulamayı silip yeniden kurmak gerekir.
`key.properties` yoksa (ör. CI'da) release derlemesi debug anahtarıyla imzalanır; o APK yayınlanmaz.

Eski sürümler silinmez: her etiket o andaki kodun kalıcı adresidir (`git checkout vX.Y.Z` ile geri dönülür,
GitHub'da etiket sayfasından indirilir).

Gündelik commit'lerde sürüm değişmez; yalnızca `CHANGELOG.md` → `[Yayınlanmamış]` başlığına satır eklenir.
