package com.patmcgtx.dailyflightplan.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Flight
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.ui.cockpit.CockpitScreen
import com.patmcgtx.dailyflightplan.ui.cockpit.CockpitViewModel
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle

/** The three top-level tabs, named to match the iOS app. Only [Cockpit] is built so far. */
enum class AppTab(val label: String, val icon: ImageVector) {
    Cockpit("Cockpit", Icons.Filled.Flight),
    Maintenance("Maintenance", Icons.Filled.Build),
    NavLog("Nav Log", Icons.Filled.Checklist),
}

@Composable
fun AppShell(cockpitViewModel: CockpitViewModel) {
    val colors = CockpitStyle.colors
    var selectedTab by rememberSaveable { mutableStateOf(AppTab.Cockpit) }

    Scaffold(
        containerColor = colors.background,
        bottomBar = {
            Box {
                NavigationBar(containerColor = colors.surface, contentColor = colors.ink) {
                    AppTab.entries.forEach { tab ->
                        NavigationBarItem(
                            selected = tab == selectedTab,
                            onClick = { selectedTab = tab },
                            icon = { Icon(tab.icon, contentDescription = null) },
                            label = {
                                Text(
                                    tab.label,
                                    style = CockpitStyle.mono(
                                        CockpitTextStyle.Caption2,
                                        if (tab == selectedTab) FontWeight.Bold else FontWeight.Normal,
                                    ),
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = CockpitStyle.inkOnHighlighter,
                                selectedTextColor = colors.ink,
                                unselectedIconColor = colors.muted,
                                unselectedTextColor = colors.muted,
                                indicatorColor = colors.highlighter,
                            ),
                        )
                    }
                }
                // Hairline rule along the top edge, like the paper cards' borders.
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(colors.border.copy(alpha = 0.4f))
                        .align(Alignment.TopCenter),
                )
            }
        },
    ) { innerPadding ->
        Box(Modifier.padding(innerPadding).fillMaxSize()) {
            when (selectedTab) {
                AppTab.Cockpit -> CockpitScreen(cockpitViewModel)
                AppTab.Maintenance -> ComingSoonScreen(AppTab.Maintenance.label)
                AppTab.NavLog -> ComingSoonScreen(AppTab.NavLog.label)
            }
        }
    }
}
