# Tasarım

Uygulamanın görsel kuralları. Tüm değerler `lib/ui/core/theme/` içinde tanımlanır;
ekranlar bu değerleri **sadece temadan okur**, hiçbir yerde sabit renk ya da font yazılmaz.

## 1. Stil

Karışık stil:
- **Başlıklar ve sayılar** (kg, tekrar, set no): Oswald, kalın ve dar → enerjik his
- **Metin ve etiketler:** Inter, sade
- **Kartlar:** ince çerçeveli (1 px, `outline` rengi), dolgu yok, köşe yarıçapı 12
- **Kas grubu etiketleri:** çerçeveli hap (pill), soluk metin rengi
- **Vurgu rengi:** her ekranda yalnızca **tek bir ana butonda** dolu kullanılır; diğer yerlerde
  ince vurgular (onay işareti, ikon, aktif kenarlık)

Fontlar uygulamanın içine gömülür (`assets/fonts/`), internetten indirilmez.

## 2. Temalar

| Anahtar | Ad | background | surface | outline | onSurface | muted | primary | onPrimary |
|---|---|---|---|---|---|---|---|---|
| `darkOrange` | Koyu turuncu (varsayılan) | `#121212` | `#1E1E1E` | `#2C2C2C` | `#F2F2F2` | `#9A9A9A` | `#FF7A1A` | `#1A0E00` |
| `redBlack` | Kırmızı siyah | `#0B0B0B` | `#191919` | `#2A2A2A` | `#F5F5F5` | `#9C9C9C` | `#E5383B` | `#FFFFFF` |
| `yellowNavy` | Sarı lacivert | `#0F1B2D` | `#172A44` | `#24395A` | `#EEF2F8` | `#93A3BC` | `#FFC93C` | `#1E1600` |
| `lightBlue` | Açık mavi | `#F6F6F4` | `#FFFFFF` | `#E2E2DE` | `#1A1A1A` | `#6B6B6B` | `#2F6FEB` | `#FFFFFF` |

- İlk üç tema `Brightness.dark`, sonuncusu `Brightness.light`.
- `muted`, `ColorScheme.onSurfaceVariant` olarak eşlenir.

## 3. Yazı ölçeği

| Kullanım | Font | Boyut | Ağırlık |
|---|---|---|---|
| Ekran başlığı | Oswald | 26 | 500 |
| Kart başlığı / hareket adı | Oswald | 18 | 500 |
| Set değerleri (60 kg × 10) | Oswald | 18 | 500 |
| Gövde metni | Inter | 15 | 400 |
| Yardımcı metin (tarih, sayılar, ipuçları) | Inter | 13 | 400, `muted` |

## 4. Boşluk ve boyut

- Boşluk ölçeği: 4, 8, 12, 16, 24, 32
- Ekran kenar boşluğu: 16
- **Minimum dokunma alanı: 48 × 48** (salonda, terli elle hızlı kullanım)
- Köşe yarıçapı: kart 12, buton 12, etiket 999 (hap)

## 5. Ortak bileşenler (`lib/ui/core/widgets/`)

- `NumberStepper`: − / değer / + (ağırlık adımı 2,5, tekrar adımı 1; değere dokununca klavyeyle giriş)
- `MuscleGroupChip`: kas grubu etiketi
- `EmptyState`: ikon + başlık + tek satır açıklama + buton

## 6. Etkileşim

- Set eklenince hafif titreşim (`HapticFeedback.lightImpact`)
- Liste öğeleri eklenip çıkarken kısa animasyon (200–300 ms)
- Silme işlemlerinde geri alma imkânı (SnackBar + "Geri al")
- Boş geçmişte karşılama: "İlk antrenmanını başlat"
