package com.dogukantufan00.exercise_tracking_app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dogukantufan00.exercise_tracking_app.data.RestSettingsStore
import com.dogukantufan00.exercise_tracking_app.ui.WatchNavHost
import com.dogukantufan00.exercise_tracking_app.ui.WatchWorkoutViewModel
import com.dogukantufan00.exercise_tracking_app.ui.theme.WatchTheme
import com.dogukantufan00.exercise_tracking_app.ui.watchWorkoutViewModelFactory

/** Saat uygulamasının tek etkinliği. Ekranlar `ui/` altında; burada yalnızca tema, ViewModel ve gezinme kökü kurulur. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val repository = (application as WatchApp).syncRepository
        val restSettings = RestSettingsStore.create(applicationContext)
        setContent {
            WatchTheme {
                val viewModel: WatchWorkoutViewModel = viewModel(
                    factory = watchWorkoutViewModelFactory(repository, restSettings),
                )
                WatchNavHost(viewModel = viewModel)
            }
        }
    }
}
