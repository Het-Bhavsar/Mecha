# Settings Native Material Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the settings restore/layout regression, make the settings UI follow macOS light/dark appearance automatically, and make `Today's Keystrokes` reset reliably at local midnight.

**Architecture:** Keep the existing settings information architecture, but replace the custom dark shell with semantic macOS backgrounds and colors so the standard title bar and content geometry stay stable. Harden `StatsManager` with a safer legacy migration and an explicit refresh hook that the UI can call when views appear.

**Tech Stack:** SwiftUI, AppKit, UserDefaults, shell-based Swift tests

---

### Task 1: Lock the stats rollover behavior with tests

**Files:**
- Modify: `Tests/StatsManagerTests.swift`
- Modify: `Mecha/Managers/StoreAndStatsManager.swift`

- [ ] **Step 1: Add a failing test for legacy counts without a stored day stamp**
- [ ] **Step 2: Add a failing test for explicit day refresh behavior**
- [ ] **Step 3: Run the focused stats test and confirm it fails**
- [ ] **Step 4: Implement the minimal stats migration/refresh changes**
- [ ] **Step 5: Re-run the stats test and confirm it passes**

### Task 2: Rebase the settings shell onto native materials

**Files:**
- Modify: `Mecha/Views/SettingsWindowChrome.swift`
- Modify: `Mecha/Views/SettingsWindowMetrics.swift`
- Modify: `Mecha/Views/SettingsView.swift`

- [ ] **Step 1: Remove the title-bar-underlap behavior from the window configurator**
- [ ] **Step 2: Replace hardcoded dark backgrounds with semantic macOS colors/materials**
- [ ] **Step 3: Update text, dividers, badges, and cards to use adaptive colors**
- [ ] **Step 4: Keep sidebar selection and status elements visually clear in both light and dark mode**
- [ ] **Step 5: Run a focused typecheck across the settings files**

### Task 3: Refresh visible stats surfaces

**Files:**
- Modify: `Mecha/Views/MenuView.swift`
- Modify: `Mecha/Views/SettingsView.swift`

- [ ] **Step 1: Trigger a stats refresh when the menu becomes visible**
- [ ] **Step 2: Trigger a stats refresh when settings appears**
- [ ] **Step 3: Verify the affected views still compile cleanly**

### Task 4: Verify end-to-end behavior

**Files:**
- Modify: `build_mecha.sh`

- [ ] **Step 1: Run the focused stats and settings verification commands**
- [ ] **Step 2: Run a full typecheck across touched files**
- [ ] **Step 3: Build the app and relaunch it**
- [ ] **Step 4: Summarize the actual verified behavior**
