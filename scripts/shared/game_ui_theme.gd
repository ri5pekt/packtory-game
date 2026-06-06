class_name GameUITheme
extends RefCounted

## Shared UI colors and touch-friendly sizing for programmatic panels.
## Reference via preload in consumers: `GameUIThemeScript.ACCENT` (not `const` aliases).

const ACCENT := Color(0.26, 0.62, 0.92)
const ACCENT_ONLINE := Color(0.28, 0.72, 0.48)
const ACCENT_IN_PERSON := Color(0.26, 0.62, 0.92)

const DIM_TEXT := Color(0.62, 0.70, 0.80)
const DIM_TEXT_LIGHT := Color(0.78, 0.83, 0.90)

const PANEL_BG := Color(0.12, 0.14, 0.18, 0.65)
const SLOT_FILLED_BG := Color(0.16, 0.19, 0.25, 0.9)
const OVERLAY_DIM := Color(0.0, 0.0, 0.0, 0.45)

const BTN_MIN_HEIGHT_TOUCH := 52.0
const BTN_MIN_HEIGHT_COMPACT := 48.0
const CONTEXT_MENU_ROW_HEIGHT := 44.0
