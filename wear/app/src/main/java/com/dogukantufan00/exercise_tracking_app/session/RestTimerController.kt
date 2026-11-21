package com.dogukantufan00.exercise_tracking_app.session

import com.dogukantufan00.exercise_tracking_app.domain.RestProgress
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Dinlenme sayacı (§15.8 madde 5). Ekrandan bağımsızdır: uygulama arka plandayken ya da ekran kapalıyken de
 * süre bitince saat titrer (titreşimi uygulama yapar, ekranlar yapmaz). Tek örnek: `(application as WatchApp).restTimer`.
 */
interface RestTimerController {
    /** Çalışan sayacın anlık durumu (~5 kez/sn güncellenir); sayaç yoksa null. */
    val rest: StateFlow<RestProgress?>

    /** Sayaç kendiliğinden bittiğinde bir kez yayar (atla/iptal yaymaz). Ekran buna göre geri döner. */
    val finished: SharedFlow<Unit>

    /** Yeni sayaç başlatır (çalışan varsa yerine geçer); süre 15 sn – 10 dk aralığına sınırlanır. */
    fun start(totalSeconds: Int)

    /** Çalışan sayacı uzatır/kısaltır; sayaç yoksa bir şey yapmaz. Sonuç bitmişse sayaç biter. */
    fun adjust(deltaSeconds: Int)

    /** Sayacı titreşimsiz durdurur. */
    fun skip()
}
