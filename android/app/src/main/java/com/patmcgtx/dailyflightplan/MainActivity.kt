package com.patmcgtx.dailyflightplan

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.patmcgtx.dailyflightplan.ui.AppShell
import com.patmcgtx.dailyflightplan.ui.cockpit.CockpitViewModel
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTheme

class MainActivity : ComponentActivity() {

    private val cockpitViewModel: CockpitViewModel by viewModels {
        viewModelFactory {
            initializer { CockpitViewModel((application as DailyFlightPlanApp).repository) }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CockpitTheme {
                AppShell(cockpitViewModel)
            }
        }
    }
}
