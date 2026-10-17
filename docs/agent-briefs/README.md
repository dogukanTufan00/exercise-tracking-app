# Ajan talimatları

Bu klasör, kodun bir kısmını yazan yapay zekâ ajanlarına (Claude Haiku) verilen görev tanımlarını içerir.
Mimar/orkestratör (Claude Opus) işi parçalara böler, her ajana bir talimat verir, çıkan kodu inceler ve birleştirir.

## Ortak kurallar (her ajan için geçerli)

1. **Önce oku:** `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `lib/data/models/` altındaki tüm dosyalar,
   `lib/data/repositories/workout_repository.dart`, `lib/data/repositories/settings_repository.dart`,
   `lib/ui/core/theme/app_spacing.dart`.
2. **Sadece görevinde listelenen dosyaları oluştur/değiştir.** Başka ajanlar aynı anda aynı projede çalışıyor;
   listende olmayan bir dosyaya dokunmak onların işini bozar. Modelleri ve arayüzleri (sözleşmeyi) değiştirme.
3. Sözleşmede bir eksik/hata olduğunu düşünürsen **değiştirme**, raporunda açıkça yaz.
4. **Yasak komutlar:** `flutter pub get/add/upgrade`, `flutter create`, `flutter clean`, her türlü `git` komutu.
   Yeni paket gerekiyorsa kullanma, raporda belirt.
5. **Doğrulama** (PowerShell, proje kökünde):
   - `& 'C:\dev\flutter\bin\flutter.bat' analyze <kendi dosyaların>` → "No issues found!" olmalı
   - `& 'C:\dev\flutter\bin\flutter.bat' test <kendi test dosyaların>` → tüm testler geçmeli
   - Diğer ajanlar da Flutter çalıştırdığı için "Waiting for another flutter command to release the startup lock"
     görebilirsin; bu normal, bekle.
6. **Kod stili:** `flutter_lints` kuralları, `const` kullanılabilen her yerde `const`, kullanıcıya görünen metinler
   Türkçe, sınıf/değişken adları İngilizce, açıklayıcı ama kısa doküman yorumları (`///`), mevcut dosyaların
   biçimine benzer kod.
7. **Bitirdiğinde rapor ver:** oluşturduğun/değiştirdiğin dosyalar, `analyze` ve `test` çıktılarının son satırları
   (aynen), varsa emin olmadığın kararlar ve sözleşmeyle ilgili notlar.

## Dalgalar

| Dalga | Ajan | Görev |
|---|---|---|
| 1 | A | [SQLite repository](wave1-a-sqlite-repository.md) |
| 1 | B | [Sahte (bellek içi) repository](wave1-b-fake-repository.md) |
| 1 | C | [Tema sistemi + ayarlar repository](wave1-c-theme-settings.md) |
| 1 | D | [Ortak bileşenler + biçimlendiriciler](wave1-d-common-widgets.md) |
