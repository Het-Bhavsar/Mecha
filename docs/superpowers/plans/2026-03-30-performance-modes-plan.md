# Performance Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add user-selectable `Power Savings`, `Balanced`, and `Zero Latency` modes that reduce idle CPU and battery usage while preserving Mecha's typing feel.

**Architecture:** Store the performance mode in `AudioEngineManager`, expose it in Settings, and let it drive engine warm/idle behavior, active player pool size, event tap mode, and low-value UI work. Also reduce background churn by batching stats persistence instead of writing on every keystroke.

**Tech Stack:** SwiftUI, AppKit, AVFoundation, UserDefaults, shell-based Swift tests

---

### Task 1: Lock performance mode behavior with tests

**Files:**
- Create: `Tests/PerformanceModeTests.swift`
- Modify: `Tests/AudioEnginePreferenceTests.swift`

- [ ] **Step 1: Write failing tests for default mode and mode configs**
- [ ] **Step 2: Run the focused tests and confirm they fail**
- [ ] **Step 3: Add the minimal runtime model for performance modes**
- [ ] **Step 4: Re-run the focused tests and confirm they pass**

### Task 2: Make the runtime honor the selected mode

**Files:**
- Modify: `Mecha/Managers/AudioEngineManager.swift`
- Modify: `Mecha/Managers/EventTapManager.swift`
- Modify: `Mecha/Managers/StoreAndStatsManager.swift`

- [ ] **Step 1: Add performance mode persistence to the audio manager**
- [ ] **Step 2: Add warm/idle engine behavior and active pool limits**
- [ ] **Step 3: Switch the event tap to listen-only mode**
- [ ] **Step 4: Batch stats persistence instead of writing every keypress**
- [ ] **Step 5: Run the focused tests and typecheck**

### Task 3: Expose control in the UI

**Files:**
- Modify: `Mecha/Views/SettingsView.swift`
- Modify: `Mecha/Views/MenuView.swift`

- [ ] **Step 1: Add a settings control for the three performance modes**
- [ ] **Step 2: Surface the active mode in the performance summary**
- [ ] **Step 3: Remove random visualizer work and use a cheaper deterministic indicator**
- [ ] **Step 4: Run the relevant typecheck/build commands**

### Task 4: Verify end-to-end behavior

**Files:**
- Modify: `build_mecha.sh`

- [ ] **Step 1: Run the focused Swift tests**
- [ ] **Step 2: Run a full typecheck across the touched files**
- [ ] **Step 3: Build the app and relaunch it**
- [ ] **Step 4: Confirm the user-facing behavior in the final summary**
