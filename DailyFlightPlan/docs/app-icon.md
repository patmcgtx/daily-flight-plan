# App Icon

Design reference for the Daily Flight Plan app icon — useful for future theming work, marketing assets, or regenerating sizes after a redesign.

## Design description

**Composition & Layout**
- Asymmetric structure: bold, off-center layout with the sun anchored in the lower-right corner.
- Sunburst pattern: an array of stylized rays radiates outward from the sun's core, extending fully across the canvas edge-to-edge.
- Hero element: a large white paper airplane is the focal point, soaring up and to the left toward the top-left quadrant.
- Motion indicator: a minimalist dotted flight path trails behind the airplane, curving down toward the sun to visually connect the two elements and imply motion.

**Color & contrast**
- Morning palette: warm, soft pastel creams, gentle yellows, and muted peach/orange tones.
- Low-contrast backdrop: the alternating sunburst rays use subtle variations of the warm palette — textured but not visually overwhelming.
- High-contrast focal point: the paper airplane's crisp white body and deep navy outline stand out sharply against the warm background, keeping it readable at small icon sizes.

**Style & framing**
- Minimalist, flat vector illustration — no gradients, textures, or drop shadows on the artwork itself.
- Full-bleed square canvas with no baked-in rounded corners or border, so iOS/macOS can mask it to the native shape.

## Implementation notes

- Asset catalog: [`Assets.xcassets/AppIcon.appiconset`](../DailyFlightPlan/Assets.xcassets/AppIcon.appiconset)
- Source artwork is supplied as a flat 1024×1024 PNG and reused as-is for all three iOS appearance slots (`icon-light-1024.png`, `icon-dark-1024.png`, `icon-tinted-1024.png`) — there's currently no dedicated dark or monochrome-template variant; tinted mode just applies the system tint over the full-color art.
- The same 1024 master is downsampled (via `sips`) to populate the mac idiom sizes (16–512pt at 1x/2x) in the same asset catalog.
- When supplying a new design, crop out any mat/border/shadow around the artwork first — the source should be full-bleed with sharp corners before scaling to 1024×1024, since the OS applies its own corner mask on top.

## History

- First pass: a solid-color runway-and-horizon glyph (simplified runway receding to a horizon, later with a rising sun and low mountain range), in the visual language of the MapsPlus reference app.
- Current: replaced with the sunrise/paper-airplane illustration described above.
