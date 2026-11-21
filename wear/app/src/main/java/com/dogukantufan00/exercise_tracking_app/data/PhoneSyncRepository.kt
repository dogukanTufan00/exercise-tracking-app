package com.dogukantufan00.exercise_tracking_app.data

import android.content.Context
import android.net.Uri
import android.util.Log
import com.dogukantufan00.exercise_tracking_app.domain.DisplayWorkout
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
import java.time.LocalDateTime
import java.util.UUID

/**
 * [WorkoutSyncRepository]'nin Data Layer gerçeklemesi (bkz. docs/ARCHITECTURE.md §15.4 ve §15.6).
 *
 * Telefonun anlık durumunu DataItem'dan okur; saatteki olayları ([PendingEventStore]) telefona MessageClient ile gönderir.
 * Olay, telefon onaylayana kadar kuyrukta kalır; tekrar göndermek güvenlidir.
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
    private val flushMutex = Mutex()

    private val snapshotFlow = MutableStateFlow<WatchSnapshot?>(null)
    private val reachableFlow = MutableStateFlow(false)

    override val workout: StateFlow<DisplayWorkout?> =
        combine(snapshotFlow, store.events) { snapshot, pending -> mergeOptimistic(snapshot, pending) }
            .stateIn(scope, SharingStarted.Eagerly, null)

    override val phoneReachable: StateFlow<Boolean> = reachableFlow.asStateFlow()

    init {
        dataClient.addListener(DataClient.OnDataChangedListener { buffer ->
            try {
                buffer.forEach { event ->
                    if (event.dataItem.uri.path == SNAPSHOT_PATH) {
                        handleSnapshotEvent(event)
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

        scope.launch { loadCurrentSnapshot() }
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
        store.update { events ->
            events + AddSetEvent(
                eventId = UUID.randomUUID().toString(),
                workoutId = workoutId,
                createdAt = LocalDateTime.now().toString(),
                workoutExerciseId = workoutExerciseId,
                weightKg = weightKg,
                reps = reps,
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

    /** Anlık durum DataItem'ını uygulamanın açılışında okur. */
    private suspend fun loadCurrentSnapshot() {
        val snapshot = withContext(Dispatchers.IO) {
            runCatching {
                val buffer = dataClient.getDataItems(snapshotUri()).await()
                try {
                    buffer.firstOrNull()?.let { decodeSnapshot(it) }
                } finally {
                    buffer.release()
                }
            }.getOrNull()
        }
        if (snapshot != null) applySnapshot(snapshot)
    }

    /** Veri değişikliğini işler; çözülemeyen yeni veri öncekini korur. Liste Data Layer tamponu serbest bırakılmadan önce okunur. */
    private fun handleSnapshotEvent(event: DataEvent) {
        if (event.type == DataEvent.TYPE_DELETED) {
            snapshotFlow.value = null
            return
        }
        decodeSnapshot(event.dataItem)?.let { applySnapshot(it) }
    }

    private fun applySnapshot(snapshot: WatchSnapshot) {
        snapshotFlow.value = snapshot
        // Telefonun işlediği olaylar kuyruktan çıkarılır; aksi halde telefon bunları zamanla unutup tekrar uygulayabilir.
        val applied = snapshot.appliedEventIds.toSet()
        scope.launch {
            // Başka antrenmana ait olaylar da düşer: telefon onları zaten uygulamaz.
            store.update { events ->
                events.filterNot { it.eventId in applied || it.workoutId != snapshot.workoutId }
            }
        }
    }

    /** DataItem'ı çözer; bozuk veya farklı protokol sürümü için null. */
    private fun decodeSnapshot(item: DataItem): WatchSnapshot? {
        return runCatching {
            val json = DataMapItem.fromDataItem(item).dataMap.getString(SNAPSHOT_JSON_KEY) ?: return null
            ProtocolJson.decodeFromString(WatchSnapshot.serializer(), json)
        }.getOrNull()?.takeIf { it.protocol == WATCH_PROTOCOL_VERSION }
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

    private fun snapshotUri(): Uri = Uri.Builder()
        .scheme(PutDataRequest.WEAR_URI_SCHEME)
        .path(SNAPSHOT_PATH)
        .build()

    private companion object {
        const val FLUSH_INTERVAL_MS = 15_000L
        const val TAG = "PhoneSync"
    }
}
