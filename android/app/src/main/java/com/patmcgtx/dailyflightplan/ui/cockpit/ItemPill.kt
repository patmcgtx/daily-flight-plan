package com.patmcgtx.dailyflightplan.ui.cockpit

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Cancel
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.automirrored.outlined.NextPlan
import androidx.compose.material.icons.automirrored.outlined.StickyNote2
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.patmcgtx.dailyflightplan.model.ItemStatus
import com.patmcgtx.dailyflightplan.model.PlanItem
import com.patmcgtx.dailyflightplan.ui.theme.CockpitStyle
import com.patmcgtx.dailyflightplan.ui.theme.CockpitTextStyle

/** What the user can do to an item from the Cockpit. All callbacks receive the item they came from. */
data class ItemActions(
    /** Opens the item for editing (wired up with the item form in plan phase 5). */
    val onOpen: (PlanItem) -> Unit = {},
    val onComplete: (PlanItem) -> Unit = {},
    val onToggleCompleted: (PlanItem) -> Unit = {},
    val onToggleFlag: (PlanItem) -> Unit = {},
    val onCancel: (PlanItem) -> Unit = {},
    val onDefer: (PlanItem) -> Unit = {},
)

/** A flagged item is called out with a highlighter-yellow rectangle behind its title, not a flag icon. */
@Composable
fun itemTitleColors(item: PlanItem): Pair<Color, Modifier> {
    val colors = CockpitStyle.colors
    val textColor = when {
        item.isFlagged -> CockpitStyle.inkOnHighlighter
        item.status == ItemStatus.Pending -> colors.ink
        else -> colors.muted
    }
    val highlight = if (item.isFlagged) {
        Modifier.background(colors.highlighter.copy(alpha = 0.8f)).padding(horizontal = 3.dp)
    } else {
        Modifier
    }
    return textColor to highlight
}

/** An untimed item: a bordered chip with a complete circle, a flag highlight, and a long-press menu. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ItemPill(item: PlanItem, actions: ItemActions, modifier: Modifier = Modifier) {
    val colors = CockpitStyle.colors
    var menuOpen by remember { mutableStateOf(false) }
    val (titleColor, titleHighlight) = itemTitleColors(item)

    Box(modifier) {
        Row(
            modifier = Modifier
                .border(1.dp, colors.border)
                .combinedClickable(
                    onClick = { actions.onOpen(item) },
                    onLongClick = { menuOpen = true },
                )
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            if (item.status == ItemStatus.Pending) {
                Icon(
                    imageVector = Icons.Outlined.RadioButtonUnchecked,
                    contentDescription = "Complete ${item.title}",
                    tint = colors.muted,
                    modifier = Modifier
                        .size(24.dp)
                        .clip(CircleShape)
                        .clickable(role = Role.Button) { actions.onComplete(item) }
                        .padding(2.dp),
                )
            }
            Text(
                text = item.title.uppercase(),
                style = CockpitStyle.mono(CockpitTextStyle.Subheadline, FontWeight.SemiBold),
                color = titleColor,
                textDecoration = if (item.status != ItemStatus.Pending) TextDecoration.LineThrough else null,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = titleHighlight,
            )
            if (item.notes.isNotEmpty()) {
                Icon(
                    imageVector = Icons.AutoMirrored.Outlined.StickyNote2,
                    contentDescription = "Has notes",
                    tint = colors.muted,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
        ItemContextMenu(menuOpen, { menuOpen = false }, item, actions, allowDefer = true)
    }
}

/** The long-press menu shared by pills and timed rows. */
@Composable
fun ItemContextMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    item: PlanItem,
    actions: ItemActions,
    allowDefer: Boolean,
) {
    val colors = CockpitStyle.colors
    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismiss,
        shape = RectangleShape,
        containerColor = colors.surface,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp,
        border = BorderStroke(1.5.dp, colors.border),
    ) {
        MenuEntry(
            text = if (item.isFlagged) "Remove Flag" else "Flag Item",
            icon = Icons.Outlined.Flag,
        ) { onDismiss(); actions.onToggleFlag(item) }
        if (item.status != ItemStatus.Canceled) {
            MenuEntry(text = "Cancel Item", icon = Icons.Outlined.Cancel) { onDismiss(); actions.onCancel(item) }
        }
        if (allowDefer) {
            MenuEntry(text = "Defer to Tomorrow", icon = Icons.AutoMirrored.Outlined.NextPlan) { onDismiss(); actions.onDefer(item) }
        }
    }
}

@Composable
private fun MenuEntry(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(text, style = CockpitStyle.mono(CockpitTextStyle.Subheadline)) },
        leadingIcon = { Icon(icon, contentDescription = null) },
        onClick = onClick,
    )
}
