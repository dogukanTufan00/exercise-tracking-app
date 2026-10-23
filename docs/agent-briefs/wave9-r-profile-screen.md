# Dalga 9 – Ajan R: Profil ve ölçüm ekranları (#14)

Önce [ortak kuralları](README.md) oku (Dalga 2 bölümü dahil), `docs/ARCHITECTURE.md` §13 ve `docs/DESIGN.md`.
Bu dalgada iki ajan daha çalışıyor: biri alt gezinme çubuğu (`lib/ui/app_shell.dart`, `main.dart`, geçmiş ve
hareketler ekranları), diğeri yedekleme (`lib/data/backup/`, `lib/ui/settings/`). Listende olmayan dosyaya dokunma.

## Hazır olanlar (DEĞİŞTİRME, kullan)

- `MeasurementRepository` (`lib/data/repositories/measurement_repository.dart`; her metodun kuralı doc yorumunda),
  modeller `lib/data/models/measurement.dart`. Ekranlar `context.read<MeasurementRepository>()` ile alır.
- Testler için `FakeMeasurementRepository` (`test/fakes/fake_measurement_repository.dart`, yerleşik 10 türle başlar).
- Biçimlendiriciler `lib/ui/core/formatters.dart` (`formatWeight` ondalık virgül için de kullanılabilir,
  `parseDecimal` girdiyi okur). Ortak bileşenler `lib/ui/core/widgets/`.
- Grafik için örnek: `lib/ui/exercise_detail/exercise_detail_screen.dart` içindeki `_ProgressChart` (fl_chart).
  O dosyayı **değiştirme**; aynı yaklaşımla kendi grafiğini yaz.

## Dokunabileceğin dosyalar

- `lib/ui/profile/profile_screen.dart` (iskelet var; doldur, kurucu `const ProfileScreen({super.key})` kalır)
- `lib/ui/profile/profile_view_model.dart` (yeni)
- `lib/ui/profile/measurement_detail_screen.dart` (yeni)
- `lib/ui/profile/measurement_detail_view_model.dart` (yeni)
- `lib/ui/profile/widgets/measurement_dialogs.dart` (yeni)
- `test/ui/profile/` altındaki yeni test dosyaları

## 1. Profil ekranı (`ProfileScreen` + `ProfileViewModel`)

Alt çubuktaki "Profil" sekmesinin kökü (geri oku yok).

- AppBar başlığı `Profil`; `actions`: `IconButton(Icons.add, tooltip: 'Özel ölçüm ekle')` → özel tür diyaloğu.
- Liste: `getMeasurementSummaries()` sırasıyla her tür bir satır (kart ya da `ListTile`):
  - Ad (`titleMedium`).
  - Son değer + birim (`formatWeight(value)` + ` ` + birim; ör. "82,5 cm") ve tarihi (`d MMM y`, soluk).
    Hiç ölçüm yoksa soluk `Henüz ölçüm yok`.
  - Değişim (`summary.change`): `+0,5 cm` / `−1 kg` (soluk renk; artış ya da azalış "iyi/kötü" diye renklendirilmez,
    çünkü hedef kişiden kişiye değişir). Değişim 0 ya da yoksa gösterilmez.
  - Sonda `IconButton(Icons.add, tooltip: 'Ölçüm ekle')` → ölçüm ekleme diyaloğu (bu tür için); kaydedince liste yenilenir.
  - Satıra dokunmak → `MeasurementDetailScreen(type: summary.type)`; dönünce liste yenilenir.
- ViewModel: `summaries`, `isLoading`, `errorMessage`/`clearError` (desen README'de), `load()`,
  `addMeasurement(typeId, value, measuredAt)`, `createType(name, unit)` (çakışmada
  `'Bu adda bir ölçüm zaten var.'`, diğer hata `'Ölçüm eklenemedi.'`).

## 2. Ölçüm detay ekranı (`MeasurementDetailScreen(type:)` + ViewModel)

- AppBar başlığı tür adı. Özel türse `actions`'da ⋮ menüsünde `Ölçümü sil` → onay diyaloğu
  ("Bu ölçüm ve tüm kayıtları silinecek.") → `deleteMeasurementType` → ekran kapanır.
- `FloatingActionButton` (tooltip `Ölçüm ekle`) → ölçüm ekleme diyaloğu.
- Üstte çizgi grafik (en az iki ölçüm varsa; tek ölçümde soluk metin "Grafik için en az iki ölçüm gerekli."),
  x ekseni sırayla ölçümler, alt eksende kısa tarihler, renkler temadan.
- Altta ölçümler en yeni üstte: tarih + değer. Satıra dokununca düzenleme diyaloğu (değer + tarih), satırda
  `IconButton(Icons.delete_outline, tooltip: 'Kaydı sil')` → silinir ve SnackBar'da `Geri al` (DESIGN §6) geri ekler.
- Boş durum: `EmptyState(icon: Icons.straighten, title: 'Henüz ölçüm yok', message: 'İlk ölçümünü eklediğinde burada görünür.')`.

## 3. Diyaloglar (`widgets/measurement_dialogs.dart`)

```dart
/// Ölçüm ekleme/düzenleme. [initial] verilirse düzenleme (değer ve tarih dolu). İptalde null.
Future<({double value, DateTime measuredAt})?> showMeasurementDialog(
  BuildContext context, {required MeasurementType type, BodyMeasurement? initial});

/// Özel ölçüm türü: ad + birim (varsayılan "cm"). İptalde null.
Future<({String name, String unit})?> showMeasurementTypeDialog(BuildContext context);
```

- Ölçüm diyaloğu: başlık tür adı; sayı alanı (sonek olarak birim, ondalık klavye, `parseDecimal`; "82,5" ve "82.5"
  kabul; boş/0/negatif → alan altında hata `0'dan büyük bir değer girin`); tarih satırı (bugün varsayılan;
  dokununca `showDatePicker`, gelecek tarih seçilemez). Saat önemli değil: kaydederken o günün **12:00**'si kullanılır.
- Tür diyaloğu: `Ad` ve `Birim` alanları; ikisi de boş olamaz.

## 4. Testler

- ViewModel'ler `FakeMeasurementRepository` ile: yükleme, ekleme sonrası özet güncellenir, özel tür ekleme ve
  çakışma mesajı, detayda düzenleme/silme/geri alma, özel tür silme.
- Ekranlar: 10 yerleşik tür listelenir; hızlı ekleme ile değer görünür; değişim metni ("+0,5 cm"); özel tür eklenir
  ve listenin sonunda görünür; detayda grafik (iki ölçüm) ve liste; yerleşik türde "Ölçümü sil" yok.
- 360 × 780, yazı 1.3'te profil listesi, detay ekranı ve iki diyalog taşmaz.

## Bitti sayılması için

- `flutter analyze lib test` temiz
- `flutter test` (tüm testler) tamamen geçiyor
