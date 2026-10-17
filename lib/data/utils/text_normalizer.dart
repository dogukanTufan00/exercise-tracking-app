/// Türkçe harfleri sadeleştirmek için eşleme tablosu (küçük harfe çevrildikten sonra uygulanır).
const Map<String, String> _turkishFolding = {
  'ı': 'i',
  'ş': 's',
  'ğ': 'g',
  'ü': 'u',
  'ö': 'o',
  'ç': 'c',
};

final RegExp _whitespace = RegExp(r'\s+');

/// Hareket adlarını karşılaştırmak, aramak ve sıralamak için ortak anahtar üretir.
///
/// - Baştaki/sondaki boşluklar kırpılır, aradaki çoklu boşluklar teke indirilir.
/// - Harf büyüklüğü yok sayılır; Türkçe büyük harfler de doğru küçülür ("İ" → "i", "I" → "i").
/// - Türkçe harfler Latin karşılıklarına sadeleşir: ı→i, ş→s, ğ→g, ü→u, ö→o, ç→c.
///
/// Böylece "Şınav", "şınav", "ŞINAV" ve "sinav" aynı anahtarı ("sinav") üretir.
/// Kullanıcıya gösterilen ad değişmez; bu yalnızca karşılaştırma anahtarıdır.
String normalizeForSearch(String text) {
  // Dart'ın toLowerCase'i "İ"yi "i̇" (i + birleşik nokta) yapar; bu yüzden önce elle çeviriyoruz.
  final lowered = text.trim().replaceAll(_whitespace, ' ').replaceAll('İ', 'i').toLowerCase();
  final buffer = StringBuffer();
  for (final char in lowered.split('')) {
    buffer.write(_turkishFolding[char] ?? char);
  }
  return buffer.toString();
}
