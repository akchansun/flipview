#pragma once

// Preview-style main-bar breakpoints (macOS Flip 0.6.15+).
struct ToolbarLayout {
    static bool showsRotateRight(int barWidth) { return barWidth >= 620; }
    static bool showsFlip(int barWidth) { return barWidth >= 740; }
    static bool showsMarkupStylesExpanded(int barWidth) { return barWidth >= 780; }
    static bool showsAdjustExtras(int barWidth) { return barWidth >= 900; }
    static bool showsInspectorExtras(int barWidth) { return barWidth >= 1040; }

    static bool hasOverflow(int barWidth)
    {
        return !(showsRotateRight(barWidth) && showsFlip(barWidth) && showsAdjustExtras(barWidth)
                 && showsInspectorExtras(barWidth));
    }
};
