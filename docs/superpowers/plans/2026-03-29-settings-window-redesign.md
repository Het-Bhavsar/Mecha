# Settings Window Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the settings screen so the native macOS title bar, traffic lights, sidebar, and detail header align cleanly and use consistent spacing.

**Architecture:** Introduce a shared window-metrics type plus a small AppKit window configurator, then rewrite the settings shell around a custom split-pane layout that uses those metrics for every top-edge decision. Keep existing settings controls and bindings, but present them inside a refined dark macOS card system.

**Tech Stack:** SwiftUI, AppKit, ServiceManagement, lightweight Swift CLI verification

---

### Task 1: Codify Window Metrics

**Files:**
- Create: `Tests/SettingsWindowMetricsTests.swift`
- Create: `Mecha/Views/SettingsWindowMetrics.swift`

- [ ] **Step 1: Write the failing regression test**

Create a Swift CLI test that expects a shared `SettingsWindowMetrics` type with:
- a clamped `titleBarHeight`
- native traffic-light padding constants
- a derived sidebar header inset
- 8pt-grid content spacing values

- [ ] **Step 2: Run the test and verify it fails**

Run: `swiftc -parse-as-library Tests/SettingsWindowMetricsTests.swift -o /tmp/settings-window-metrics-tests`
Expected: compile failure because `SettingsWindowMetrics` does not exist yet

- [ ] **Step 3: Implement the metrics type**

Add a pure Swift metrics file that can be used both by the SwiftUI view and the CLI regression test.

- [ ] **Step 4: Run the regression test and verify it passes**

Run: `swiftc -parse-as-library Mecha/Views/SettingsWindowMetrics.swift Tests/SettingsWindowMetricsTests.swift -o /tmp/settings-window-metrics-tests && /tmp/settings-window-metrics-tests`
Expected: executable exits successfully with no assertion failures

### Task 2: Add Native Window Chrome Configuration

**Files:**
- Create: `Mecha/Views/SettingsWindowChrome.swift`

- [ ] **Step 1: Add an AppKit window accessor**

Create a small `NSViewRepresentable` helper that exposes the host `NSWindow`.

- [ ] **Step 2: Apply the native chrome configuration**

Set the window to:
- hide the title text
- use a transparent title bar
- keep the native traffic lights
- allow full-size content for custom alignment
- let the background participate in window dragging

### Task 3: Rebuild the Settings Shell

**Files:**
- Modify: `Mecha/Views/SettingsView.swift`

- [ ] **Step 1: Replace the ad-hoc `NavigationSplitView` spacing**

Remove the independent spacer hacks and switch to a custom chrome-aware split layout.

- [ ] **Step 2: Build the sidebar header and navigation**

Use the shared metrics to reserve traffic-light clearance, position branding, and restyle the section list.

- [ ] **Step 3: Build the detail header and content cards**

Align the selected-page title to the chrome row, then restyle the settings controls into balanced cards and rows using the shared spacing system.

- [ ] **Step 4: Keep existing functionality intact**

Retain all current bindings and interactions for toggles, sliders, the sound-pack picker, and store actions.

### Task 4: Verify

**Files:**
- Modify: `Mecha/Views/SettingsView.swift`
- Create: `Mecha/Views/SettingsWindowMetrics.swift`
- Create: `Mecha/Views/SettingsWindowChrome.swift`
- Create: `Tests/SettingsWindowMetricsTests.swift`

- [ ] **Step 1: Re-run the metrics regression test**

Run: `swiftc -parse-as-library Mecha/Views/SettingsWindowMetrics.swift Tests/SettingsWindowMetricsTests.swift -o /tmp/settings-window-metrics-tests && /tmp/settings-window-metrics-tests`
Expected: pass

- [ ] **Step 2: Attempt a project build check**

Run: `xcodebuild -list -project Mecha.xcodeproj`
Expected: either project listing or a clear toolchain limitation that must be reported

- [ ] **Step 3: Review final diff for spacer regressions**

Inspect the updated files and confirm the old fake title-bar spacer logic is gone.
