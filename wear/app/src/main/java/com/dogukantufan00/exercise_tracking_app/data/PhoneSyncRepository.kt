package com.dogukantufan00.exercise_tracking_app.data

import android.content.Context
import android.net.Uri
import android.util.Log
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
import com.dogukantufan00.exercise_tracking_app.domain.REST_DEFAULT_SECONDS
import com.dogukantufan00.exercise_tracking_app.domain.RestTimer
import com.dogukantufan00.exercise_tracking_app.domain.mergeOptimistic
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import java.time.LocalDateTime
import java.util.UUID

/**
 * [WorkoutSyncRepository]'nin Data Layer gerçeklemesi (bkz. docs/ARCHITECTURE.md §15.4, §15.6, §15.8 ve §16.2).
 *
 * Telefonun anlık durumunu, etkin programını, işlenmiş olay id'lerini ve dinlenme süresi ayarını DataItem'lardan
 * okur; saatteki olayları ([PendingEventStore]) telefona MessageClient ile gönderir. Olay, telefon onaylayana kadar
 * kuyrukta kalır; tekrar göndermek güvenlidir.
 */
class PhoneSyncRepository(
    context: Context,
    private val scope: CoroutineScope,
) : WorkoutSyncRepository {

    private val appContext = context.applicationContext
    private val dataClient: DataClient = Wearable.getDataClient(appContext)
    private val capabilityClient: CapabilityClient = Wearable.getCapabilityClient(appContext)
    private val messageClient = Wearable.getMessageClient(appContext)
    private val store = PendingEventStore(appContext)
    private val restCache = RestSettingsStore.create(appContext)
    private val flushMutex = Mutex()

    private val snapshotFlow = MutableStateFlow<WatchSnapshot?>(null)
    private val programFlow = MutableStateFlow<WatchProgram?>(null)
    private val appliedFlow = MutableStateFlow<Set<String>>(emptySet())
    private val reachableFlow = MutableStateFlow(false)

    override val workout: StateFlow<DisplayWorkout?> =
        combine(snapshotFlow, store.events) { snapshot, pending -> mergeOptimistic(snapshot, pending) }
            .stateIn(scope, SharingStarted.Eagerly, null)

    override val phoneReachable: StateFlow<Boolean> = reachableFlow.asStateFlow()

    override val program: StateFlow<WatchProgram?> = programFlow.asStateFlow()

    override val pendingStart: StateFlow<PendingStart?> =
        combine(store.events, programFlow) { events, currentProgram -> pendingStartOf(events, currentProgram) }
            .stateIn(scope, SharingStarted.Eagerly, null)

    /** Son bilinen (telefondan kopyalanmış) dinlenme süresi; hiç yoksa varsayılan. */
    private val cachedRestSeconds: StateFlow<Int> =
        restCache.restSeconds.stateIn(scope, SharingStarted.Eagerly, REST_DEFAULT_SECONDS)

    /** Bekleyen ayar olayı varsa onun değeri (iyimser), yoksa önbellek. */
    override val restSeconds: StateFlow<Int> =
        combine(cachedRestSeconds, store.events) { cached, events ->
            events.filterIsInstance<SetRestSecondsEvent>().lastOrNull()?.seconds ?: cached
        }.stateIn(scope, SharingStarted.Eagerly, REST_DEFAULT_SECONDS)

    init {
        dataClient.addListener(DataClient.OnDataChangedListener { buffer ->
            try {
                buffer.forEach { event ->
                    when (event.dataItem.uri.path) {
                        SNAPSHOT_PATH -> handleSnapshotEvent(event)
                        PROGRAM_PATH -> handleProgramEvent(event)
                        APPLIED_PATH -> handleAppliedEvent(event)
                        REST_SETTINGS_PATH -> handleRestSettingsEvent(event)
                    }
                }
            } finally {
                buffer.release()
            }
        })

        capabilityClient.addListener(
            CapabilityClient.OnCapabilityChangedListener {
                scope.launch {
                    refreshReachable()
                    flush()
                }
            },
            PHONE_CAPABILITY,
        )

        scope.launch { loadCurrentState() }
        scope.launch { refreshReachable() }
        scope.launch {
            while (true) {
                delay(FLUSH_INTERVAL_MS)
                if (store.events.first().isNotEmpty()) flush()
            }
        }
    }

    override suspend fun addSet(workoutExerciseId: Long, weightKg: Double, reps: Int) {
        val workoutId = snapshotFlow.value?.workoutId ?: return
        val seconds = restSeconds.value
        store.update { events ->
            events + AddSetEvent(
                eventId = UUID.randomUUID().toString(),
                workoutId = workoutId,
                createdAt = LocalDateTime.now().toString(),
                workoutExerciseId = workoutExerciseId,
                weightKg = weightKg,
                reps = reps,
                restSeconds = seconds,
            )
        }
        scope.launch { flush() }
    }

    override suspend fun deleteSet(setId: Long) {
        val workoutId = snapshotFlow.value?.workoutId ?: return
        store.update { events ->
            events + DeleteSetEvent(
                eventId = UUID.randomUUID().toString(),
                workoutId = workoutId,
                createdAt = LocalDateTime.now().toString(),
                setId = setId,
            )
        }
        scope.launch { flush() }
    }

    override suspend fun startWorkout(programDayId: Long?) {
        store.update { events ->
            // En fazla bir bekleyen başlatma: önceki (henüz uygulanmamış) istek yerine yeni olay yazılır.
            events.filterNot { it is StartWorkoutEvent } + StartWorkoutEvent(
                eventId = UUID.randomUUID().toString(),
                createdAt = LocalDateTime.now().toString(),
                programDayId = programDayId,
            )
        }
        scope.launch { flush() }
    }

    override suspend fun finishWorkout() {
        val workoutId = snapshotFlow.value?.workoutId ?: return
        store.update { events ->
            events + FinishWorkoutEvent(
                eventId = UUID.randomUUID().toString(),
                workoutId = workoutId,
                createdAt = LocalDateTime.now().toString(),
            )
        }
        scope.launch { flush() }
    }

    override suspend fun cancelPendingStart() {
        store.update { events -> events.filterNot { it is StartWorkoutEvent } }
    }

    override suspend fun adjustRest(deltaSeconds: Int) {
        val display = workout.value ?: return
        val rest = display.rest ?: return
        store.update { events ->
            events + AdjustRestEvent(
                eventId = UUID.randomUUID().toString(),
                workoutId = display.workoutId,
                createdAt = LocalDateTime.now().toString(),
                restId = rest.restId,
                deltaSeconds = deltaSeconds,
            )
        }
        scope.launch { flush() }
    }

    override suspend fun skipRest() {
        val display = workout.value ?: return
        val rest = display.rest ?: return
        store.update { events ->
            events + SkipRestEvent(
                eventId = UUID.randomUUID().toString(),
                workoutId = display.workoutId,
                createdAt = LocalDateTime.now().toString(),
                restId = rest.restId,
            )
        }
        scope.launch { flush() }
    }

    override suspend fun setRestSeconds(seconds: Int) {
        store.update { events ->
            events + SetRestSecondsEvent(
                eventId = UUID.randomUUID().toString(),
                createdAt = LocalDateTime.now().toString(),
                seconds = RestTimer.clampSeconds(seconds),
            )
        }
        scope.launch { flush() }
    }

    /** Anlık durum, program, işlenmiş olaylar ve dinlenme ayarı uygulamanın açılışında okunur. */
    private suspend fun loadCurrentState() {
        readItem(SNAPSHOT_PATH, ::decodeSnapshot)?.let { snapshotFlow.value = it }
        readItem(PROGRAM_PATH, ::decodeProgram)?.let { programFlow.value = it }
        readItem(APPLIED_PATH, ::decodeApplied)?.let { appliedFlow.value = it }
        readItem(REST_SETTINGS_PATH, ::decodeRestSeconds)?.let { restCache.save(it) }
        pruneAsync()
    }

    /** Veri değişikliğini işler; çözülemeyen yeni veri öncekini korur. Silme anlık durumu temizler. */
    private fun handleSnapshotEvent(event: DataEvent) {
        if (event.type == DataEvent.TYPE_DELETED) {
            snapshotFlow.value = null
        } else {
            decodeSnapshot(event.dataItem)?.let { snapshotFlow.value = it }
        }
        pruneAsync()
    }

    /** Program değişince günceller; silinmesi programı kaldırır; bozuk veri öncekini korur. */
    private fun handleProgramEvent(event: DataEvent) {
        if (event.type == DataEvent.TYPE_DELETED) {
            programFlow.value = null
            return
        }
        decodeProgram(event.dataItem)?.let { programFlow.value = it }
    }

    /** Telefonun işlenmiş olay listesi; silinmesi ya da bozuk veri öncekini korur. */
    private fun handleAppliedEvent(event: DataEvent) {
        if (event.type == DataEvent.TYPE_DELETED) return
        decodeApplied(event.dataItem)?.let { applied ->
            appliedFlow.value = applied
            pruneAsync()
        }
    }

    /** Telefonun dinlenme süresi ayarı; önbelleğe yazılır. Silinmesi ya da bozuk veri öncekini korur. */
    private fun handleRestSettingsEvent(event: DataEvent) {
        if (event.type == DataEvent.TYPE_DELETED) return
        decodeRestSeconds(event.dataItem)?.let { seconds ->
            scope.launch { restCache.save(seconds) }
        }
    }

    /**
     * Bekleyen kuyruğu budar (§15.8):
     * - id'si uygulanmış olaylar (anlık durum veya `/events/applied`) silinir;
     * - anlık durum varsa, ona ait olmayan antrenman olayları (set, sayaç, bitirme) silinir;
     * - StartWorkoutEvent yalnızca uygulanınca silinir (iptal [cancelPendingStart] ile).
     */
    private fun pruneAsync() {
        scope.launch {
            store.update { events ->
                val snapshot = snapshotFlow.value
                val applied = appliedFlow.value + (snapshot?.appliedEventIds ?: emptyList())
                events.filterNot { event ->
                    when (event) {
                        is StartWorkoutEvent -> event.eventId in applied
                        is SetRestSecondsEvent -> event.eventId in applied
                        is AddSetEvent ->
                            event.eventId in applied || (snapshot != null && event.workoutId != snapshot.workoutId)
                        is DeleteSetEvent ->
                            event.eventId in applied || (snapshot != null && event.workoutId != snapshot.workoutId)
                        is AdjustRestEvent ->
                            event.eventId in applied || (snapshot != null && event.workoutId != snapshot.workoutId)
                        is SkipRestEvent ->
                            event.eventId in applied || (snapshot != null && event.workoutId != snapshot.workoutId)
                        is FinishWorkoutEvent ->
                            event.eventId in applied || (snapshot != null && event.workoutId != snapshot.workoutId)
                    }
                }
            }
        }
    }

    /** Bekleyen başlatmayı ekran için hazırlar; gün adı programda yoksa null. */
    private fun pendingStartOf(events: List<WatchEvent>, currentProgram: WatchProgram?): PendingStart? {
        val start = events.filterIsInstance<StartWorkoutEvent>().firstOrNull() ?: return null
        val dayName = start.programDayId?.let { dayId ->
            currentProgram?.days?.firstOrNull { it.dayId == dayId }?.name
        }
        return PendingStart(eventId = start.eventId, programDayId = start.programDayId, dayName = dayName)
    }

    /** Bir DataItem'ı yoldan okur; yoksa ya da çözülemezse null. */
    private suspend fun <T> readItem(path: String, decode: (DataItem) -> T?): T? = withContext(Dispatchers.IO) {
        runCatching {
            val buffer = dataClient.getDataItems(itemUri(path)).await()
            try {
                buffer.firstOrNull()?.let(decode)
            } finally {
                buffer.release()
            }
        }.getOrNull()
    }

    private fun decodeSnapshot(item: DataItem): WatchSnapshot? =
        decodeProtocolJson(item, WatchSnapshot.serializer()) { it.protocol }

    private fun decodeProgram(item: DataItem): WatchProgram? =
        decodeProtocolJson(item, WatchProgram.serializer()) { it.protocol }

    private fun decodeApplied(item: DataItem): Set<String>? =
        decodeProtocolJson(item, WatchApplied.serializer()) { it.protocol }?.appliedEventIds?.toSet()

    /** Dinlenme süresi (saniye) DataMap'ten okunur; anahtar yoksa ya da okunamazsa null. */
    private fun decodeRestSeconds(item: DataItem): Int? =
        runCatching {
            val map = DataMapItem.fromDataItem(item).dataMap
            if (map.containsKey(REST_SECONDS_KEY)) map.getInt(REST_SECONDS_KEY) else null
        }.getOrNull()

    /** DataItem'daki JSON'u çözer; bozuk veya farklı protokol sürümü için null. */
    private fun <T> decodeProtocolJson(item: DataItem, serializer: KSerializer<T>, protocolOf: (T) -> Int): T? {
        return runCatching {
            val json = DataMapItem.fromDataItem(item).dataMap.getString(SNAPSHOT_JSON_KEY) ?: return null
            ProtocolJson.decodeFromString(serializer, json)
        }.getOrNull()?.takeIf { protocolOf(it) == WATCH_PROTOCOL_VERSION }
    }

    /** Telefon yeteneğini sorgular ve [reachableFlow]'u günceller. */
    private suspend fun refreshReachable() {
        reachableFlow.value = fetchPhoneNodes().isNotEmpty()
    }

    private suspend fun fetchPhoneNodes(): Set<Node> = withContext(Dispatchers.IO) {
        runCatching {
            capabilityClient.getCapability(PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE).await().nodes
        }.onFailure { Log.w(TAG, "Telefon yeteneği sorgulanamadı", it) }.getOrDefault(emptySet())
    }

    /** Bekleyen olayları telefona gönderir. Aynı anda yalnızca bir gönderim çalışır. */
    private suspend fun flush() {
        flushMutex.withLock {
            val pending = store.events.first()
            if (pending.isEmpty()) return
            val nodes = fetchPhoneNodes()
            Log.i(TAG, "flush: ${pending.size} bekleyen olay, ${nodes.size} telefon düğümü")
            val node = nodes.firstOrNull { it.isNearby } ?: nodes.firstOrNull() ?: return
            sendAll(node.id, pending)
        }
    }

    /** Olayları sırayla gönderir; ilk hatada durur, kalan olaylar kuyrukta kalır. */
    private suspend fun sendAll(nodeId: String, events: List<WatchEvent>) = withContext(Dispatchers.IO) {
        for (event in events) {
            val bytes = ProtocolJson.encodeToString(WatchEvent.serializer(), event).toByteArray(Charsets.UTF_8)
            try {
                messageClient.sendMessage(nodeId, EVENT_PATH, bytes).await()
                Log.i(TAG, "Olay gönderildi: ${event.eventId}")
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.w(TAG, "Olay gönderilemedi: ${event.eventId}", e)
                return@withContext
            }
        }
    }

    private fun itemUri(path: String): Uri = Uri.Builder()
        .scheme(PutDataRequest.WEAR_URI_SCHEME)
        .path(path)
        .build()

    private companion object {
        const val FLUSH_INTERVAL_MS = 15_000L
        const val TAG = "PhoneSync"
    }
}
