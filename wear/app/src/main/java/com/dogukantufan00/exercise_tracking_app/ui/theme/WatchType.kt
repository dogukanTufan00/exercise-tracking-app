package com.dogukantufan00.exercise_tracking_app.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.dogukantufan00.exercise_tracking_app.R
import java.util.Locale

/*
 * Saatin yazı ölçeği (telefondaki docs/DESIGN.md §1 ve §3'ün saat karşılığı): başlıklar ve sayılar Oswald,
 * diğer metinler sistem yazı tipi. Oswald telefonun assets/fonts/Oswald-Variable.ttf dosyasıdır (OFL lisansı);
 * değişken yazı tipi olduğu için her ağırlık aynı dosyadan ayarlanır. Renk burada verilmez, ekranlar temadan okur.
 */

private fun oswald(weight: FontWeight) = Font(
    resId = R.font.oswald,
    weight = weight,
    variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)),
)

/** Oswald, telefondaki gibi orta ve kalın ağırlıklarla. */
val Oswald = FontFamily(
    oswald(FontWeight.Normal),
    oswald(FontWeight.Medium),
    oswald(FontWeight.SemiBold),
)

/** Saat ekranlarının Oswald yazı stilleri. */
object WatchType {
    /** Ekran başlığı: "ANTRENMAN", hareket adı (büyük harf, hafif aralıklı). */
    val header = TextStyle(fontFamily = Oswald, fontWeight = FontWeight.Medium, fontSize = 17.sp, letterSpacing = 0.6.sp)

    /** Kart başlığı: program günü, hareket listesindeki ad. */
    val cardTitle = TextStyle(fontFamily = Oswald, fontWeight = FontWeight.Medium, fontSize = 16.sp)

    /** Vurgu düğmesi yazısı: "SET TAMAM", "BUGÜN". */
    val action = TextStyle(fontFamily = Oswald, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, letterSpacing = 0.8.sp)

    /** Hareket ekranındaki büyük ağırlık ve tekrar. */
    val bigNumber = TextStyle(fontFamily = Oswald, fontWeight = FontWeight.Medium, fontSize = 40.sp, lineHeight = 44.sp)

    /** Dinlenme sayacı. */
    val timer = TextStyle(fontFamily = Oswald, fontWeight = FontWeight.Medium, fontSize = 58.sp, lineHeight = 62.sp)

    /** Orta boy sayı: set satırları, dinlenme göstergesi, ayar değeri. */
    val number = TextStyle(fontFamily = Oswald, fontWeight = FontWeight.Medium, fontSize = 20.sp)

    /** Küçük sayı: ilerleme halkasının içi ("2/3"). */
    val smallNumber = TextStyle(fontFamily = Oswald, fontWeight = FontWeight.Medium, fontSize = 12.sp)
}

private val Turkish = Locale.forLanguageTag("tr")

/** Türkçe büyük harf (i → İ); başlıklar büyük harfli Oswald ile yazılır. */
fun String.upperTr(): String = uppercase(Turkish)
