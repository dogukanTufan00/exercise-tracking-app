package com.dogukantufan00.exercise_tracking_app.session

import com.dogukantufan00.exercise_tracking_app.domain.DisplayRest
import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Dinlenme sayacı (§15.8, §16.2). Sayaç, telefon ve saatin ortak hedefini ([DisplayRest]) izler: hedef iyimser
 * durumdan gelir. Ekrandan bağımsızdır: uygulama arka plandayken ya da ekran kapalıyken de süre bitince saat
 * titrer (titreşimi uygulama yapar, ekranlar yapmaz). Tek örnek: `(application as WatchApp).restTimer`.
 */
interface RestTimerController {
    /** Çalışan sayacın anlık durumu (~5 kez/sn güncellenir); sayaç yoksa null. */
    val rest: StateFlow<RestProgress?>

    /** Sayaç kendiliğinden bittiğinde bir kez yayar (atla/iptal yaymaz). Ekran buna göre geri döner. */
    val finished: SharedFlow<Unit>

    /**
     * Sayaç hedefini izler. Aynı hedef tekrar verilirse bir şey yapmaz; yeni ya da değişmiş hedefte bitiş anı
     * yeniden hesaplanır. Hedef null ise sayaç titreşimsiz durur.
     */
    fun follow(target: DisplayRest?)
}
