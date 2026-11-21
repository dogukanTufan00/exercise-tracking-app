package com.dogukantufan00.exercise_tracking_app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text

/** Saat uygulamasının tek etkinliği. Ajan AD: ekranlar `ui/` altında, burada yalnızca kök çağrılır. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Text("Exercise Tracker")
            }
        }
    }
}
