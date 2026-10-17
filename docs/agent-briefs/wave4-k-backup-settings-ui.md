# Dalga 4 – Ajan K: Ayarlar > Veriler bölümü (issue #1)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil). Bu görev Dalga 4'ün J1 (repository) ve J2 (JSON/CSV)
işleri **bittikten sonra** yapılır; onların kodunu kullanırsın, değiştirmezsin.

## Dokunabileceğin dosyalar

- `lib/data/services/backup_file_service.dart` (yeni)
- `lib/ui/settings/backup_view_model.dart` (yeni)
- `lib/ui/settings/settings_screen.dart`
- `lib/main.dart`
- `test/fakes/fake_backup_file_service.dart` (yeni)
- `test/ui/settings/backup_view_model_test.dart` (yeni)
- `test/ui/settings/settings_screen_test.dart`
- `test/widget_test.dart`

Kullanacağın hazır kod: `WorkoutRepository.exportBackup/importBackup`, `encodeBackupJson`, `decodeBackupJson`,
`BackupFormatException` (`lib/data/backup/backup_json_codec.dart`), `exportBackupCsv`
(`lib/data/backup/backup_csv_exporter.dart`), `FakeWorkoutRepository`. Önce bu dosyaları oku.

## 1. `BackupFileService` (platforma bağlı kısım, testte sahtesi kullanılır)

```dart
abstract interface class BackupFileService {
  /// Metni geçici bir dosyaya yazar ve Android paylaşım menüsünü açar.
  Future<void> shareTextFile({required String fileName, required String content, required String mimeType});
  /// Dosya seçiciyi açar; seçilen dosyanın metnini (UTF-8) döndürür. Kullanıcı vazgeçerse null.
  Future<String?> pickTextFile();
}
class DeviceBackupFileService implements BackupFileService { ... }
```

Gerçek uygulama (paketler `pubspec.yaml`'da hazır; **API'leri tahmin etme**, gerekirse
`C:\Users\user\AppData\Local\Pub\Cache\hosted\pub.dev\` altındaki kaynaklarını oku):
- Geçici klasör: `getTemporaryDirectory()` (`package:path_provider/path_provider.dart`), dosyayı
  `File(...).writeAsString(content, encoding: utf8)` ile yaz.
- Paylaşım (`share_plus` 13): `SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: mimeType)]))`.
- Seçme (`file_picker` 13 — **statik API**): `final file = await FilePicker.pickFile();` (vazgeçilirse `null`);
  içerik `utf8.decode(await file.readAsBytes())`. UTF-8 olmayan dosyada `FormatException` fırlar; bunu
  `BackupFormatException('Dosya okunamadı: geçerli bir yedek dosyası değil.')`'a çevir.
- Bu sınıf için birim testi gerekmez (platform kanalı); tüm mantık ViewModel'de, o test edilir.

## 2. `BackupViewModel extends ChangeNotifier`

```dart
BackupViewModel(WorkoutRepository repository, BackupFileService files, {DateTime Function()? clock});
bool get isBusy;
String? get message;        // başarı bilgisi (SnackBar); clearMessage()
String? get errorMessage;   // hata (SnackBar); clearError()
Future<void> exportCsv();
Future<void> exportJson();
Future<void> importJson();
```
- `isBusy` iken yeni işlem başlatılmaz (çağrı hiçbir şey yapmaz).
- **Dışa aktarma:** `exportBackup()` → hem katalog hem antrenmanlar boşsa `errorMessage = 'Henüz kaydedilmiş veri yok.'`.
  Değilse:
  - CSV: `antrenmanlar-YYYY-MM-DD.csv`, `text/csv`, içerik `exportBackupCsv(data)`
  - JSON: `antrenman-yedegi-YYYY-MM-DD.json`, `application/json`, içerik `encodeBackupJson(data)`
  - Tarih `clock()` (varsayılan `DateTime.now`) ile, sıfır dolgulu. Başarıda mesaj gösterme (paylaşım menüsü yeterli).
- **İçe aktarma:** `pickTextFile()` → `null` ise hiçbir şey yapma. → `decodeBackupJson` →
  `importBackup` → `message = '{added} antrenman eklendi, {skipped} antrenman atlandı'`, `addedExercises > 0` ise
  sonuna `', {n} yeni hareket'`. Hatalar:
  - `BackupFormatException` → `errorMessage = e.message`
  - `ArgumentError` → `'Yedek dosyasında geçersiz değerler var; hiçbir şey değiştirilmedi.'`
  - diğer → `'İşlem tamamlanamadı.'` (dışa aktarmada da)
- `await` sonrası dispose kontrolü (ortak kurallardaki gibi).

## 3. Ayarlar ekranı

Mevcut "Tema" bölümünün altına, `AppSpacing.xl` boşlukla **"Veriler"** bölümü (`bodySmall` başlık). Ekran
`BackupViewModel`'i kendi `ChangeNotifierProvider`'ıyla oluşturur
(`context.read<WorkoutRepository>()`, `context.read<BackupFileService>()`). Üç satır (`InkWell`, en az 56 yükseklik,
solda 24'lük ikon `onSurfaceVariant`, başlık `bodyLarge`, altında açıklama `bodySmall` `onSurfaceVariant`):

| İkon | Başlık | Açıklama | Eylem |
|---|---|---|---|
| `Icons.table_chart_outlined` | CSV olarak dışa aktar | Excel ve Google Sheets ile açılır | `exportCsv` |
| `Icons.save_alt` | Yedek al | Tüm verilerini tek dosyaya kaydet | `exportJson` |
| `Icons.settings_backup_restore` | Yedekten geri yükle | Mevcut verilerin korunur, yedektekiler eklenir | `importJson` |

- `isBusy` iken bölüm başlığının altında `LinearProgressIndicator` ve satırlar devre dışı (`onTap: null`).
- `message` / `errorMessage` → `SnackBar` + temizle (diğer ekranlardaki desenle).

## 4. `main.dart`

`ExerciseTrackerApp`'e `required BackupFileService backupFileService` ekle; `MultiProvider`'a
`Provider<BackupFileService>.value` ekle; `main()` `DeviceBackupFileService()` geçsin.

## 5. Testler

- `FakeBackupFileService`: paylaşılan dosyaları (`fileName`, `content`, `mimeType`) listede tutar; `pickTextFile`
  için dönecek metin ayarlanabilir (null = vazgeçti).
- ViewModel: boş veride hata mesajı; CSV/JSON dosya adı (sabit `clock` ile), mime ve içerik (CSV BOM ile başlar,
  JSON `decodeBackupJson` ile geri okunur); içe aktarma başarı mesajı (yeni hareket sayılı ve sayısız iki durum);
  vazgeçmede hiçbir şey olmaz; bozuk dosyada format mesajı; geçersiz değerde ArgumentError mesajı ve veri değişmez;
  `isBusy` iken ikinci çağrı yok sayılır.
- Ekran: "Veriler" ve üç satır görünür; "Yedek al"a dokununca sahte serviste bir JSON dosyası paylaşılmış olur;
  geri yükleme sonrası başarı SnackBar'ı görünür. Mevcut tema testleri yeni provider ile çalışmaya devam etmeli.
- `widget_test.dart`: yeni parametreyle güncelle.

## Bitti sayılması için

- `flutter analyze` (tüm proje) temiz
- `flutter test` (tüm proje) tamamen geçiyor
