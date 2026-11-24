package com.dogukantufan00.exercise_tracking_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dogukantufan00.exercise_tracking_app.session.SessionController
import com.dogukantufan00.exercise_tracking_app.ui.LaunchRequest
import com.dogukantufan00.exercise_tracking_app.ui.WatchNavHost
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchTheme
import com.dogukantufan00.exercise_tracking_app.ui.watchWorkoutViewModelFactory
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow

/**
 * Saat uygulamasının tek etkinliği. Ekranlar `ui/` altında; burada tema, ViewModel, gezinme kökü, Tile açılış
 * isteklerinin okunması ve antrenman servisi/izinler (§15.8) kurulur.
 */
class MainActivity : ComponentActivity() {

    /** Tile/telefon açılış istekleri; ekran toplamaya başlayana kadar tamponda bekler. */
    private val launchChannel = Channel<LaunchRequest>(Channel.UNLIMITED)
    private val launchFlow: Flow<LaunchRequest> = launchChannel.receiveAsFlow()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Döndürmede aynı Intent yeniden verilmez; yine de ekstralar okunduktan sonra silinir.
        if (savedInstanceState == null) consumeLaunchIntent(intent)

        val repository = (application as WatchApp).syncRepository
        val restTimer = (application as WatchApp).restTimer
        val themeSource = (application as WatchApp).themeSource
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        setContent {
            val themeId by themeSource.themeId.collectAsStateWithLifecycle()
            WatchTheme(themeId) {
                val viewModel: WatchWorkoutViewModel = viewModel(
                    factory = watchWorkoutViewModelFactory(repository, restTimer),
                )
                val workout by viewModel.workout.collectAsStateWithLifecycle()
                val active = workout != null
                val required = SessionController.requiredPermissions()
                var granted by remember { mutableStateOf(hasAllPermissions(this@MainActivity, required)) }

                val permissionLauncher = rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestMultiplePermissions(),
                ) {
                    granted = hasAllPermissions(this@MainActivity, required)
                }

                // İzinler yalnızca ilk etkin antrenmanda bir kez istenir; reddedilirse bir daha sorulmaz.
                LaunchedEffect(active) {
                    granted = hasAllPermissions(this@MainActivity, required)
                    val asked = prefs.getBoolean(KEY_PERMISSIONS_ASKED, false)
                    if (active && !granted && !asked) {
                        prefs.edit().putBoolean(KEY_PERMISSIONS_ASKED, true).apply()
                        permissionLauncher.launch(required)
                    }
                }

                // Etkin antrenman ya da izin değiştikçe antrenman servisini başlat/durdur (ön plandan).
                LaunchedEffect(active, granted) {
                    SessionController.sync(this@MainActivity, active)
                }

                WatchNavHost(viewModel = viewModel, launches = launchFlow)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeLaunchIntent(intent)
    }

    /** Tile Intent ekstralarını okur, her birini bir kez işler ve ekstraları Intent'ten siler. */
    private fun consumeLaunchIntent(intent: Intent?) {
        if (intent == null) return
        val request = when {
            intent.hasExtra(LaunchActions.EXTRA_START_DAY_ID) -> {
                val dayId = intent.getLongExtra(LaunchActions.EXTRA_START_DAY_ID, NO_ID)
                if (dayId != NO_ID) LaunchRequest.StartDay(dayId) else null
            }
            intent.getBooleanExtra(LaunchActions.EXTRA_START_EMPTY, false) -> LaunchRequest.StartEmpty
            intent.getBooleanExtra(LaunchActions.EXTRA_OPEN_START, false) -> LaunchRequest.OpenStart
            else -> null
        }
        intent.removeExtra(LaunchActions.EXTRA_START_DAY_ID)
        intent.removeExtra(LaunchActions.EXTRA_START_EMPTY)
        intent.removeExtra(LaunchActions.EXTRA_OPEN_START)
        request?.let { launchChannel.trySend(it) }
    }

    private companion object {
        const val PREFS_NAME = "watch_prefs"
        const val KEY_PERMISSIONS_ASKED = "permissions_asked"
        const val NO_ID = -1L
    }
}

/** Verilen izinlerin hepsi verilmiş mi (boş listede true). */
fun hasAllPermissions(context: Context, permissions: Array<String>): Boolean =
    permissions.all { ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED }
