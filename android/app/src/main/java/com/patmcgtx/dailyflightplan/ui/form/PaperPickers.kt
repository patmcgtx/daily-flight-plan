package com.patmcgtx.dailyflightplan.ui.form

import android.text.format.DateFormat
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneOffset

private const val MILLIS_PER_DAY = 86_400_000L

/** Material's date picker dialog, squared off and themed. Reports the chosen day on OK. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaperDatePickerDialog(initial: LocalDate, onConfirm: (LocalDate) -> Unit, onDismiss: () -> Unit) {
    // The picker works in UTC midnights, so convert through epoch days to avoid time-zone drift.
    val state = rememberDatePickerState(initialSelectedDateMillis = initial.toEpochDay() * MILLIS_PER_DAY)
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                state.selectedDateMillis?.let { millis ->
                    onConfirm(Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate())
                } ?: onDismiss()
            }) { Text("OK", style = CockpitStyle.mono(CockpitTextStyle.Subheadline, FontWeight.Bold)) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("CANCEL", style = CockpitStyle.mono(CockpitTextStyle.Subheadline), color = CockpitStyle.colors.muted)
            }
        },
        shape = RectangleShape,
    ) { DatePicker(state = state) }
}

/** Material's time picker in a squared-off dialog; follows the device's 12/24-hour setting. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaperTimePickerDialog(initial: LocalTime, onConfirm: (LocalTime) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val state = rememberTimePickerState(
        initialHour = initial.hour,
        initialMinute = initial.minute,
        is24Hour = DateFormat.is24HourFormat(context),
    )
    AlertDialog(
        onDismissRequest = onDismiss,
        shape = RectangleShape,
        confirmButton = {
            TextButton(onClick = { onConfirm(LocalTime.of(state.hour, state.minute)) }) {
                Text("OK", style = CockpitStyle.mono(CockpitTextStyle.Subheadline, FontWeight.Bold))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("CANCEL", style = CockpitStyle.mono(CockpitTextStyle.Subheadline), color = CockpitStyle.colors.muted)
            }
        },
        text = { TimePicker(state = state) },
    )
}
