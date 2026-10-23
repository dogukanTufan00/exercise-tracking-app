# Değişiklik günlüğü

Bu projedeki önemli değişiklikler bu dosyada tutulur. Biçim
[Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/) yaklaşımına,
sürüm numaraları [Semantic Versioning](https://semver.org/lang/tr/) kurallarına
uyar (bkz. `docs/ARCHITECTURE.md` §11).

## [Yayınlanmamış]

### Eklendi
- Antrenmanlar listesi haftalara bölünür: her haftanın başında "12–18 Ekim · 3 antrenman · 48 set" (#15).
- Vücut ölçümleri için veritabanı (ilk şema geçişi, mevcut veriler korunur) (#14).

## [0.2.0] - 2026-10-23

İlerleme sürümü: #3 (ilerleme grafikleri ve kişisel rekorlar) tamamlandı. 0.2.0-beta sürümlerinin içeriğine ek olarak:

### Eklendi
- Antrenmanda rekor vurgusu: bir set hareketin önceki antrenmanlardaki en ağır ağırlığını ya da tahmini 1RM'ini
  geçerse satırında 🏆 rozeti çıkar, telefon titrer ve "Yeni rekor" bildirimi görünür (#8).
- Hareket düzenleme: yanlış işaretlenmiş bir hareketin adı ve kas grubu, hareket detay ekranındaki ✏️ simgesinden
  ya da antrenman kartının ⋮ menüsünden düzeltilebilir; değişiklik tüm geçmişe yansır (#10).

### Değişti
- Uygulamanın adı "Exercise Tracker" oldu ve yeni bir ikonu var: sarı-lacivert dambıl ve yukarı ok,
  Android'de her telefonun ikon şekline uyan "adaptive icon" olarak (#2).

## [0.2.0-beta.2] - 2026-10-18

### Düzeltildi
- Release APK açılışta takılıyordu (v0.1.0 ve v0.2.0-beta.1). R8 küçültücüsü, Dart'ın JNI ile
  çağırdığı `shared_preferences` metotlarını ve Kotlin sınıflarını siliyor ya da yeniden
  adlandırıyordu; `android/app/proguard-rules.pro` ile korunuyorlar.

## [0.2.0-beta.1] - 2026-10-18

Deneme sürümü: ilerleme ekranı (#3'ün ilk üç adımı). Antrenmanda rekor vurgusu (#8) henüz yok.

### Eklendi
- İlerleme altyapısı: hareket geçmişi sorgusu, tahmini 1RM (Epley) ve kişisel rekor hesapları (#5).
- Hareket detay ekranı: kişisel rekorlar, tahmini 1RM / en ağır / hacim grafiği (`fl_chart`) ve
  antrenman antrenman setler. Ağırlıksız hareketlerde tekrar gösterilir (#6).
- Hareket detayına giriş: hareket kartının ⋮ menüsünde "İlerleme" ve Geçmiş ekranından açılan,
  aranabilir "Hareketler" listesi (#7).

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

[Yayınlanmamış]: https://github.com/dogukanTufan00/exercise-tracking-app/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/dogukanTufan00/exercise-tracking-app/releases/tag/v0.2.0
[0.2.0-beta.2]: https://github.com/dogukanTufan00/exercise-tracking-app/releases/tag/v0.2.0-beta.2
[0.2.0-beta.1]: https://github.com/dogukanTufan00/exercise-tracking-app/releases/tag/v0.2.0-beta.1
[0.1.0]: https://github.com/dogukanTufan00/exercise-tracking-app/releases/tag/v0.1.0
