# Settings Window Redesign Design

**Goal:** Rebuild the macOS settings window so the native traffic lights, sidebar, and detail header share one consistent title-bar-safe layout.

## Root Cause

The current settings screen fakes title-bar spacing with independent `Spacer` offsets in the sidebar and detail pane. That creates visual drift instead of a single window geometry system.

## Approved Direction

Use a native macOS full-size content window with the standard traffic lights left in the system title bar. Build the settings UI around explicit layout metrics so the sidebar header, navigation, and detail header all respect the same top inset and spacing rhythm.

## Layout Rules

- Clamp title-bar-safe top spacing to the native macOS range of roughly `28-32pt`
- Reserve explicit leading clearance for the traffic lights before placing sidebar header content
- Keep the sidebar below a shared chrome row so it does not compete with the title bar
- Align the detail header title to the same chrome row as the traffic lights
- Use a consistent 8pt spacing system for content, cards, dividers, and section rhythm

## Visual Direction

- Dark graphite window background with soft blue-steel gradients
- Subtle split-pane separation instead of heavy borders
- Rounded cards with light inner strokes and restrained shadows
- Clean system typography with strong hierarchy and compact utility labels

## Implementation Shape

1. Add a small metrics type for title-bar height, traffic-light clearance, sidebar width, and content spacing
2. Add a window configurator that enables transparent native title-bar chrome without replacing the standard traffic lights
3. Replace the current `NavigationSplitView` layout with a custom split settings shell driven by the shared metrics
4. Restyle the settings sections into consistent cards and rows
5. Verify the metrics through a lightweight Swift regression test and run a syntax-level build check if the environment allows it
