package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ViewTimeline
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.Progress
import com.patmcgtx.dailyflightplan.model.SectionModel
import com.patmcgtx.dailyflightplan.model.accessibilitySummary
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle

/** One day section: collapsed to a one-line summary, or expanded to its pills and timed rows. */
@Composable
fun SectionCard(
    model: SectionModel,
    expanded: Boolean,
    onToggle: () -> Unit,
    onAddItem: () -> Unit,
    actions: ItemActions,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .paperCard(borderWidth = if (model.isCurrent) 2.5.dp else 1.5.dp)
            .animateContentSize(),
    ) {
        if (expanded) {
            CardHeader(
                title = model.section.displayName,
                subtitle = model.section.timeRangeLabel,
                progress = model.progress,
                isCurrent = model.isCurrent,
                hasOverdue = model.hasOverdue,
                description = model.accessibilitySummary(),
                expanded = true,
                onToggle = onToggle,
            )
            PaperRule(alpha = 1f)
            AddItemLink(onAddItem)
            SectionBody(model, actions)
        } else {
            CollapsedHeader(model, onToggle = onToggle)
        }
    }
}

/** "+ ADD ITEM" at the top of an expanded card. */
@Composable
fun AddItemLink(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    Row(
        modifier
            .clickable(role = Role.Button, onClickLabel = "Add item", onClick = onClick)
            .heightIn(min = 48.dp)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.Outlined.Add, contentDescription = null, tint = colors.ink, modifier = Modifier.size(14.dp))
        Text("ADD ITEM", style = CockpitStyle.mono(CockpitTextStyle.Caption, FontWeight.SemiBold), color = colors.ink)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SectionBody(model: SectionModel, actions: ItemActions) {
    val colors = CockpitStyle.colors
    if (!model.hasContent) {
        // Nothing to draw: either the card is truly empty, or everything in it is done and hidden.
        val allDone = model.progress.isAllDone
        Text(
            text = if (allDone) "All done ✓  Completed items are hidden" else "Nothing scheduled",
            style = CockpitStyle.mono(CockpitTextStyle.Subheadline),
            color = if (allDone) colors.done else colors.muted,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
        )
        return
    }
    Column(Modifier.padding(bottom = 4.dp)) {
        if (model.pills.isNotEmpty()) {
            Row(
                Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    Icons.Outlined.ViewTimeline,
                    contentDescription = null,
                    tint = colors.muted,
                    modifier = Modifier.padding(top = 7.dp).size(16.dp),
                )
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.weight(1f),
                ) {
                    model.pills.forEach { ItemPill(it, actions) }
                }
            }
        }
        if (model.pills.isNotEmpty() && model.deadlines.isNotEmpty()) PaperRule()
        model.deadlines.forEachIndexed { index, item ->
            DeadlineRow(item, actions, isMissed = item.id in model.missedItemIds)
            if (index != model.deadlines.lastIndex) PaperRule(Modifier.padding(start = 56.dp))
        }
    }
}

/**
 * Title, subtitle, and progress ring — the top of an expanded card. [description] is what a screen
 * reader says in place of the visual pieces (the ring and "!" badge are cryptic when read aloud);
 * a non-null [onToggle] makes the header a collapse button.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CardHeader(
    title: String,
    subtitle: String,
    progress: Progress,
    isCurrent: Boolean,
    hasOverdue: Boolean,
    description: String,
    modifier: Modifier = Modifier,
    expanded: Boolean? = null,
    onToggle: (() -> Unit)? = null,
) {
    val colors = CockpitStyle.colors
    Row(
        modifier
            .fillMaxWidth()
            .then(
                if (onToggle != null) {
                    Modifier.clickable(
                        onClickLabel = if (expanded == true) "Collapse" else "Expand",
                        role = Role.Button,
                        onClick = onToggle,
                    )
                } else {
                    Modifier
                },
            )
            .clearAndSetSemantics {
                contentDescription = description
                if (expanded != null) stateDescription = if (expanded) "Expanded" else "Collapsed"
                if (onToggle != null) {
                    role = Role.Button
                    onClick(label = if (expanded == true) "Collapse" else "Expand") { onToggle(); true }
                }
            }
            .padding(16.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = title.uppercase(),
                style = CockpitStyle.mono(CockpitTextStyle.Title2, FontWeight.Bold),
                color = if (isCurrent) CockpitStyle.inkOnHighlighter else colors.ink.copy(alpha = 0.85f),
                modifier = if (isCurrent) Modifier.background(colors.highlighter).padding(horizontal = 4.dp) else Modifier,
            )
            FlowRow(
                itemVerticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                if (isCurrent) {
                    Box(Modifier.size(6.dp).clip(CircleShape).background(colors.now))
                    Text("NOW  ·", style = CockpitStyle.mono(CockpitTextStyle.Caption, FontWeight.Bold), color = colors.now)
                }
                Text(subtitle.uppercase(), style = CockpitStyle.mono(CockpitTextStyle.Caption), color = colors.muted)
            }
        }
        ProgressRing(progress, hasOverdue)
    }
}

/** A donut showing done/total; turns green when everything is done and orange when overdue. */
@Composable
fun ProgressRing(progress: Progress, hasOverdue: Boolean, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    val ringColor = if (progress.isAllDone) colors.done else colors.ink
    val labelColor = when {
        progress.isAllDone -> colors.done
        hasOverdue -> colors.overdue
        else -> colors.muted
    }
    Box(modifier.size(56.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize().padding(3.dp)) {
            val stroke = 6.dp.toPx()
            drawArc(
                color = colors.border.copy(alpha = 0.25f),
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                size = Size(size.width, size.height),
                style = Stroke(stroke),
            )
            if (progress.total > 0) {
                drawArc(
                    color = ringColor,
                    startAngle = -90f,
                    sweepAngle = 360f * progress.fraction,
                    useCenter = false,
                    size = Size(size.width, size.height),
                    style = Stroke(stroke, cap = StrokeCap.Round),
                )
            }
        }
        Text(
            text = (if (hasOverdue) "! " else "") + "${progress.completed}/${progress.total}",
            style = CockpitStyle.mono(CockpitTextStyle.Caption2, FontWeight.Bold),
            color = labelColor,
        )
    }
}

/** The one-line header of a collapsed card. (The iOS AI summary is replaced by a plain status line.) */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CollapsedHeader(model: SectionModel, onToggle: () -> Unit) {
    val colors = CockpitStyle.colors
    val progress = model.progress
    val description = model.accessibilitySummary()
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClickLabel = "Expand", role = Role.Button, onClick = onToggle)
            .clearAndSetSemantics {
                contentDescription = description
                stateDescription = "Collapsed"
                role = Role.Button
                onClick(label = "Expand") { onToggle(); true }
            }
            .padding(16.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            FlowRow(
                itemVerticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = model.section.displayName.uppercase(),
                    style = CockpitStyle.mono(CockpitTextStyle.Headline, FontWeight.Bold),
                    color = if (model.isCurrent) CockpitStyle.inkOnHighlighter else colors.ink,
                    modifier = if (model.isCurrent) Modifier.background(colors.highlighter).padding(horizontal = 4.dp) else Modifier,
                )
                Text("·", style = CockpitStyle.mono(CockpitTextStyle.Caption), color = colors.muted)
                Text(model.section.timeRangeLabel.uppercase(), style = CockpitStyle.mono(CockpitTextStyle.Caption), color = colors.muted)
                if (model.isCurrent) {
                    Box(Modifier.size(5.dp).clip(CircleShape).background(colors.now))
                    Text("NOW", style = CockpitStyle.mono(CockpitTextStyle.Caption, FontWeight.Bold), color = colors.now)
                }
            }
            val (status, statusColor) = when {
                progress.isAllDone -> "All done ✓" to colors.done
                progress.total > 0 -> "${progress.total - progress.completed} remaining" to colors.muted
                else -> "Nothing scheduled" to colors.muted
            }
            Text(status, style = CockpitStyle.mono(CockpitTextStyle.Caption), color = statusColor)
        }
        if (progress.total > 0) {
            val badgeColor = when {
                model.hasFlaggedPending -> CockpitStyle.inkOnHighlighter
                progress.isAllDone -> colors.done
                model.hasOverdue -> colors.overdue
                else -> colors.muted
            }
            val prefix = when {
                progress.isAllDone -> "✓ "
                model.hasOverdue -> "! "
                else -> ""
            }
            Text(
                text = "$prefix${progress.completed}/${progress.total}",
                style = CockpitStyle.mono(CockpitTextStyle.Caption2, FontWeight.Bold),
                color = badgeColor,
                modifier = if (model.hasFlaggedPending) Modifier.background(colors.highlighter).padding(horizontal = 4.dp) else Modifier,
            )
        }
    }
}
