package com.patmcgtx.dailyflightplan

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.patmcgtx.dailyflightplan.ui.AppShell
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CockpitTheme {
                AppShell()
            }
        }
    }
}
