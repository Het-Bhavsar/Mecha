# Settings Native Material Refresh Design

**Goal:** Make the settings window behave like a standard macOS window again, fix the clipped top header after minimize/restore, adapt correctly to light mode, and ensure `Today's Keystrokes` truly reflects the current local day.

## Root Cause

The current settings shell still behaves like a custom full-size content window. It paints hardcoded dark gradients under the title bar, ignores the top safe area, and uses white-tinted text across most of the view. That makes the header fragile after minimize/restore and causes controls like the `Sound Packs` radio group to inherit dark-on-dark or dark-on-custom colors in light mode.

The stats issue has two likely contributors:

- legacy values without a stored day stamp are currently preserved as if they belong to today
- the UI does not explicitly reconcile stats when the menu or settings view becomes visible again

## Approved Direction

Rebase the settings shell onto native macOS window materials and semantic colors. Keep the existing sidebar/detail structure, but stop painting under the title bar and stop assuming a permanently dark appearance. Also harden the stats manager so dayless legacy counts reset safely and the UI refreshes the daily snapshot when visible.

## Design Rules

- Let the standard macOS title bar own the top chrome region
- Keep the existing split layout, but position the first sidebar/header content below the title bar instead of under it
- Use semantic colors and materials so light/dark mode follow the system automatically
- Keep the 8pt spacing system, sidebar width, and card structure
- Preserve the current information density, but reduce custom gradients to subtle accents instead of whole-window backgrounds

## Implementation Shape

1. Remove the faux full-size-content behavior from the settings window and use standard window background colors
2. Swap hardcoded white text and graphite backgrounds in `SettingsView` for adaptive semantic colors/materials
3. Keep cards and selected sidebar rows visually distinct with accent-tinted surfaces that still work in light mode
4. Update the stats manager so missing day-stamp legacy values reset to the current day safely
5. Add an explicit `refreshIfNeeded()` path and call it when the menu/settings become visible
6. Verify with focused Swift tests, a typecheck, then a full build and relaunch
