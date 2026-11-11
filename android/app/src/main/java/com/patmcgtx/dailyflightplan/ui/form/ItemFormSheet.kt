package com.patmcgtx.dailyflightplan.ui.form

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.listSaver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.DaySection
import com.patmcgtx.dailyflightplan.model.ItemFormState
import com.patmcgtx.dailyflightplan.model.ItemFormTarget
import com.patmcgtx.dailyflightplan.ui.cockpit.PaperRule
import com.patmcgtx.dailyflightplan.ui.cockpit.formatShort
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** Survives rotation and process death by flattening the draft to primitives. */
private val ItemFormStateSaver: Saver<ItemFormState, Any> = listSaver(
    save = {
        listOf(
            it.title, it.notes, it.isFlagged, it.date.toEpochDay(),
            it.hasDeadline, it.deadline.toSecondOfDay(), it.daySection?.name,
        )
    },
    restore = {
        ItemFormState(
            title = it[0] as String,
            notes = it[1] as String,
            isFlagged = it[2] as Boolean,
            date = LocalDate.ofEpochDay(it[3] as Long),
            hasDeadline = it[4] as Boolean,
            deadline = LocalTime.ofSecondOfDay((it[5] as Int).toLong()),
            daySection = (it[6] as String?)?.let(DaySection::valueOf),
        )
    },
)

private val dateFormatter: DateTimeFormatter = DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL)

/**
 * The add/edit item form, as a bottom sheet. The draft lives here (not in the view model) so
 * typing stays instant; [onSave] receives the finished draft and the sheet's owner closes it.
 * [defaultTime] seeds the time picker when the item has no time yet.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ItemFormSheet(
    target: ItemFormTarget,
    defaultTime: LocalTime,
    onSave: (ItemFormState) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = CockpitStyle.colors
    val isNew = target is ItemFormTarget.New
    var form by rememberSaveable(target, stateSaver = ItemFormStateSaver) {
        mutableStateOf(
            when (target) {
                is ItemFormTarget.New -> ItemFormState.forNew(target.date, target.section, defaultTime)
                is ItemFormTarget.Edit -> ItemFormState.from(target.item, defaultTime)
            },
        )
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        shape = RectangleShape,
        containerColor = colors.surface,
        dragHandle = null,
    ) {
        Column(
            Modifier
                .border(1.5.dp, colors.border)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            FormHeader(
                title = if (isNew) "New Item" else "Edit Item",
                canSave = form.isValid,
                onCancel = onDismiss,
                onSave = { onSave(form) },
            )
            TitleAndNotes(form, isNew) { form = it }
            PaperRule()
            DetailsSection(form) { form = it }
            PaperRule()
            ScheduleSection(form) { form = it }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun FormHeader(title: String, canSave: Boolean, onCancel: () -> Unit, onSave: () -> Unit) {
    val colors = CockpitStyle.colors
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = onCancel) {
            Text("CANCEL", style = CockpitStyle.mono(CockpitTextStyle.Subheadline, FontWeight.SemiBold), color = colors.muted)
        }
        Text(
            text = title.uppercase(),
            style = CockpitStyle.mono(CockpitTextStyle.Headline, FontWeight.Bold),
            color = colors.ink,
            modifier = Modifier.weight(1f),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        TextButton(onClick = onSave, enabled = canSave) {
            Text(
                "SAVE",
                style = CockpitStyle.mono(CockpitTextStyle.Subheadline, FontWeight.Bold),
                color = if (canSave) colors.ink else colors.muted.copy(alpha = 0.5f),
                modifier = if (canSave) Modifier.background(colors.highlighter).padding(horizontal = 6.dp, vertical = 2.dp) else Modifier,
            )
        }
    }
}

@Composable
private fun TitleAndNotes(form: ItemFormState, isNew: Boolean, onChange: (ItemFormState) -> Unit) {
    val focusRequester = remember { FocusRequester() }
    // A new item is usually typed straight away, so start in the title field.
    LaunchedEffect(Unit) { if (isNew) focusRequester.requestFocus() }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        FormTextField(
            label = "Title",
            value = form.title,
            onValueChange = { onChange(form.copy(title = it)) },
            singleLine = true,
            capitalization = KeyboardCapitalization.Sentences,
            modifier = Modifier.focusRequester(focusRequester),
            description = "Item title",
        )
        FormTextField(
            label = "Notes",
            value = form.notes,
            onValueChange = { onChange(form.copy(notes = it)) },
            minLines = 3,
            capitalization = KeyboardCapitalization.Sentences,
            description = "Item notes",
        )
    }
}

@Composable
private fun DetailsSection(form: ItemFormState, onChange: (ItemFormState) -> Unit) {
    var showDatePicker by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionLabel("Details")
        PickerRow(
            icon = { Icon(Icons.Outlined.CalendarToday, contentDescription = null, tint = CockpitStyle.colors.ink) },
            label = "Date",
            value = form.date.format(dateFormatter),
            onClick = { showDatePicker = true },
        )
        ToggleRow(
            label = "Flagged",
            description = "Flagged",
            checked = form.isFlagged,
            onCheckedChange = { onChange(form.copy(isFlagged = it)) },
        )
    }

    if (showDatePicker) {
        PaperDatePickerDialog(
            initial = form.date,
            onConfirm = { onChange(form.copy(date = it)); showDatePicker = false },
            onDismiss = { showDatePicker = false },
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ScheduleSection(form: ItemFormState, onChange: (ItemFormState) -> Unit) {
    var showTimePicker by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionLabel("Schedule")
        ToggleRow(
            label = "Specific time",
            description = "Specific time",
            checked = form.hasDeadline,
            onCheckedChange = { onChange(form.copy(hasDeadline = it)) },
        )
        if (form.hasDeadline) {
            PickerRow(
                icon = { Icon(Icons.Outlined.Schedule, contentDescription = null, tint = CockpitStyle.colors.ink) },
                label = "Time",
                value = form.deadline.formatShort(),
                onClick = { showTimePicker = true },
            )
        } else {
            Text("SEGMENT", style = CockpitStyle.mono(CockpitTextStyle.Caption2, FontWeight.Bold), color = CockpitStyle.colors.muted)
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                PaperChip("Open", selected = form.daySection == null) { onChange(form.copy(daySection = null)) }
                DaySection.entries.forEach { section ->
                    PaperChip(section.displayName, selected = form.daySection == section) {
                        onChange(form.copy(daySection = section))
                    }
                }
            }
        }
    }

    if (showTimePicker) {
        PaperTimePickerDialog(
            initial = form.deadline,
            onConfirm = { onChange(form.copy(deadline = it)); showTimePicker = false },
            onDismiss = { showTimePicker = false },
        )
    }
}

// region Building blocks

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text.uppercase(),
        style = CockpitStyle.mono(CockpitTextStyle.Caption, FontWeight.Bold),
        color = CockpitStyle.colors.muted,
    )
}

@Composable
private fun FormTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    description: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = false,
    minLines: Int = 1,
    capitalization: KeyboardCapitalization = KeyboardCapitalization.None,
) {
    val colors = CockpitStyle.colors
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label.uppercase(), style = CockpitStyle.mono(CockpitTextStyle.Caption2, FontWeight.Bold), color = colors.muted)
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = CockpitStyle.mono(CockpitTextStyle.Body).copy(color = colors.ink),
            cursorBrush = SolidColor(colors.ink),
            singleLine = singleLine,
            minLines = minLines,
            keyboardOptions = KeyboardOptions(capitalization = capitalization),
            modifier = modifier
                .fillMaxWidth()
                .border(1.dp, colors.border)
                .padding(12.dp)
                .semantics { contentDescription = description },
        )
    }
}

@Composable
private fun PickerRow(
    icon: @Composable () -> Unit,
    label: String,
    value: String,
    onClick: () -> Unit,
) {
    val colors = CockpitStyle.colors
    Row(
        Modifier
            .fillMaxWidth()
            .border(1.dp, colors.border)
            .clickable(role = Role.Button, onClickLabel = "Change ${label.lowercase()}", onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        icon()
        Text(label.uppercase(), style = CockpitStyle.mono(CockpitTextStyle.Caption, FontWeight.Bold), color = colors.muted)
        Text(
            value,
            style = CockpitStyle.mono(CockpitTextStyle.Subheadline, FontWeight.SemiBold),
            color = colors.ink,
            modifier = Modifier.weight(1f),
            textAlign = androidx.compose.ui.text.style.TextAlign.End,
        )
    }
}

@Composable
private fun ToggleRow(label: String, description: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    val colors = CockpitStyle.colors
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            label.uppercase(),
            style = CockpitStyle.mono(CockpitTextStyle.Subheadline, FontWeight.SemiBold),
            color = colors.ink,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.semantics { contentDescription = description },
            colors = SwitchDefaults.colors(
                checkedThumbColor = CockpitStyle.inkOnHighlighter,
                checkedTrackColor = colors.highlighter,
                checkedBorderColor = colors.border,
                uncheckedThumbColor = colors.muted,
                uncheckedTrackColor = colors.background,
                uncheckedBorderColor = colors.border,
            ),
        )
    }
}

/** A square, bordered choice chip that fills with the highlighter when selected. */
@Composable
private fun PaperChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val colors = CockpitStyle.colors
    Box(
        Modifier
            .border(1.dp, colors.border)
            .background(if (selected) colors.highlighter else androidx.compose.ui.graphics.Color.Transparent)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
            .heightIn(min = 44.dp)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label.uppercase(),
            style = CockpitStyle.mono(CockpitTextStyle.Caption, if (selected) FontWeight.Bold else FontWeight.Normal),
            color = if (selected) CockpitStyle.inkOnHighlighter else colors.ink,
        )
    }
}

// endregion
