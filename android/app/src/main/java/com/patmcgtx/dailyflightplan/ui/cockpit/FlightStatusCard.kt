package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.Day
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.Progress
import com.patmcgtx.dailyflightplan.model.spokenStatus
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/** Upper-cases while typing without changing the stored text (one-to-one, so offsets are unchanged). */
private val UppercaseTransformation = VisualTransformation { text ->
    TransformedText(AnnotatedString(text.text.map { it.uppercaseChar() }.joinToString("")), OffsetMapping.Identity)
}

/**
 * The masthead of the flight plan: a progress box, the editable flight name and destination,
 * the next deadline, and the route through the day's sections.
 */
@Composable
fun FlightStatusCard(
    state: CockpitUiState,
    onFlightNameChange: (String) -> Unit,
    onIntentionChange: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.paperCard()) {
        Row(
            Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.Top,
        ) {
            ProgressBox(state.progress)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                FlightNameField(state.date, state.displayedFlightNumber, onFlightNameChange)
                DestinationField(state.date, state.day?.intention.orEmpty(), onIntentionChange)
                state.nextUp?.let { time ->
                    Text(
                        text = "Next up at ${time.formatShort()}",
                        style = CockpitStyle.mono(CockpitTextStyle.Caption),
                        color = CockpitStyle.colors.muted,
                    )
                }
            }
        }
        PaperRule()
        RouteLine(state.context.currentSection, Modifier.padding(14.dp))
    }
}

/** A square gauge: the box fills left to right as items get done, with "done/total" in the middle. */
@Composable
private fun ProgressBox(progress: Progress) {
    val colors = CockpitStyle.colors
    // At least 60dp square, but grows with the text so large font sizes never overflow the box.
    Box(
        Modifier
            .defaultMinSize(minWidth = 60.dp, minHeight = 60.dp)
            .clearAndSetSemantics { contentDescription = "Flight progress, ${progress.spokenStatus()}" },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.matchParentSize()) {
            drawRect(colors.border.copy(alpha = 0.25f), size = size)
            drawRect(colors.ink, size = Size(size.width * progress.fraction, size.height))
            val inset = 5.dp.toPx()
            drawRect(colors.surface, topLeft = Offset(inset, inset), size = Size(size.width - 2 * inset, size.height - 2 * inset))
            drawRect(colors.border, size = size, style = Stroke(1.dp.toPx()))
        }
        Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.padding(10.dp)) {
            Text(
                "${progress.completed}",
                style = CockpitStyle.mono(CockpitTextStyle.Title3, FontWeight.Bold),
                color = colors.ink,
            )
            Text(
                "/${progress.total}",
                style = CockpitStyle.mono(CockpitTextStyle.Caption2),
                color = colors.muted,
                modifier = Modifier.padding(bottom = 2.dp),
            )
        }
    }
}

/**
 * The flight name, editable in place. It shows the default "DFP YYYYMMDD" number as real text so
 * the user can tweak it. While focused it holds the raw draft, so the field can be emptied
 * without snapping back; otherwise it mirrors the stored name.
 */
@Composable
private fun FlightNameField(date: LocalDate, displayed: String, onChange: (String) -> Unit) {
    val colors = CockpitStyle.colors
    val focusManager = LocalFocusManager.current
    var focused by remember { mutableStateOf(false) }
    var draft by remember(date) { mutableStateOf(displayed) }
    LaunchedEffect(displayed, focused) { if (!focused) draft = displayed }

    val style = CockpitStyle.mono(CockpitTextStyle.Body, FontWeight.Bold)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text("FLIGHT", style = CockpitStyle.mono(CockpitTextStyle.Caption2, FontWeight.Bold), color = colors.muted)
        BasicTextField(
            value = draft,
            onValueChange = { raw ->
                val capped = Day(date).withFlightName(raw).flightName
                draft = capped
                onChange(capped)
            },
            textStyle = style.copy(color = colors.ink),
            cursorBrush = SolidColor(colors.ink),
            singleLine = true,
            visualTransformation = UppercaseTransformation,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged { focused = it.isFocused }
                .semantics { contentDescription = "Flight name" },
            decorationBox = { field ->
                Box {
                    if (draft.isEmpty()) {
                        Text(Day.defaultFlightNumber(date), style = style, color = colors.muted)
                    }
                    field()
                }
            },
        )
    }
}

/** "DESTINATION": a short note, up to three lines, on what the day is for. */
@Composable
private fun DestinationField(date: LocalDate, displayed: String, onChange: (String) -> Unit) {
    val colors = CockpitStyle.colors
    val focusManager = LocalFocusManager.current
    var focused by remember { mutableStateOf(false) }
    var draft by remember(date) { mutableStateOf(displayed) }
    LaunchedEffect(displayed, focused) { if (!focused) draft = displayed }

    val style = CockpitStyle.mono(CockpitTextStyle.Caption)
    val weekday = date.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text("DESTINATION", style = CockpitStyle.mono(CockpitTextStyle.Caption2, FontWeight.Bold), color = colors.muted)
        BasicTextField(
            value = draft,
            onValueChange = { raw ->
                // Return means "Done", not a new line: keep the note to a single paragraph.
                val text = raw.replace("\n", "")
                draft = text
                onChange(text)
            },
            textStyle = style.copy(color = colors.ink),
            cursorBrush = SolidColor(colors.ink),
            maxLines = 3,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged { focused = it.isFocused }
                .semantics { contentDescription = "Day destination" },
            decorationBox = { field ->
                Box {
                    if (draft.isEmpty()) {
                        Text("What is this $weekday for?", style = style, color = colors.muted)
                    }
                    field()
                }
            },
        )
    }
}

/** "ROUTE: FIRST THING → MORNING → …" with the current section (today only) in bold. */
@Composable
private fun RouteLine(current: DaySection?, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    val text = buildAnnotatedString {
        withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = colors.muted)) { append("ROUTE:  ") }
        DaySection.entries.forEachIndexed { index, section ->
            if (index > 0) withStyle(SpanStyle(color = colors.muted)) { append(" → ") }
            val isCurrent = section == current
            withStyle(
                SpanStyle(
                    fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal,
                    color = if (isCurrent) colors.ink else colors.muted,
                ),
            ) { append(section.displayName.uppercase()) }
        }
    }
    Text(text, style = CockpitStyle.mono(CockpitTextStyle.Caption2), modifier = modifier.fillMaxWidth())
}
