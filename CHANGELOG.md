# Değişiklik günlüğü

Bu projedeki önemli değişiklikler bu dosyada tutulur. Biçim
[Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/) yaklaşımına,
sürüm numaraları [Semantic Versioning](https://semver.org/lang/tr/) kurallarına
uyar (bkz. `docs/ARCHITECTURE.md` §11).

## [Yayınlanmamış]

### Eklendi
- İlerleme altyapısı: hareket geçmişi sorgusu, tahmini 1RM (Epley) ve kişisel rekor hesapları (#5).
- Hareket detay ekranı: kişisel rekorlar, tahmini 1RM / en ağır / hacim grafiği (`fl_chart`) ve
  antrenman antrenman setler. Ağırlıksız hareketlerde tekrar gösterilir (#6).

### Değişti
- Release APK artık yayın anahtarıyla imzalanır; GitHub Release'lere APK eklenir.

## [0.1.0] - 2026-10-18

İlk sürüm (alfa): uygulamanın temel akışı uçtan uca çalışıyor.

### Eklendi
- Antrenman başlatma, hareket ekleme, set (ağırlık × tekrar) girme ve not yazma.
- Hareket kartlarında "geçen sefer" bilgisi, seti tekrarlama ve set düzenleme sayfası.
- Açılıp kapanabilen hareket kartları; kapalıyken tek satır özet.
- Geçmiş, hareket seçici ve ayarlar ekranları.
- Türkçe karakterleri doğru eşleyen hareket arama ve aynı ad kontrolü.
- Dört tema (`Theme.of(context)` ile; sabit renk ve boyut yok).
- CSV dışa aktarma ve JSON yedekle/geri yükle ("Farklı kaydet" diyaloğu ile).
- README, MIT lisansı ve CI iş akışı.

### Düzeltildi
- Dar ekranda adımlayıcı taşması.
- Dar ekranda ya da büyük sistem yazısında ağırlık/tekrar adımlayıcıları
  artık alt alta dizilir; sayılar küçülmez (#4).

[Yayınlanmamış]: https://github.com/dogukanTufan00/exercise-tracking-app/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dogukanTufan00/exercise-tracking-app/releases/tag/v0.1.0
