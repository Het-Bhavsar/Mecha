# GitHub Release Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Sparkle-based updater that consumes GitHub Releases through a GitHub Pages appcast while preserving the current DMG install path.

**Architecture:** Vendor Sparkle's prebuilt framework and tools into the repo, wrap Sparkle in a focused `UpdateManager`, add updater controls to the menu/settings surfaces, and extend the release scripts to produce a ZIP archive plus `appcast.xml` that points at GitHub Release assets.

**Tech Stack:** SwiftUI, AppKit, Sparkle 2, shell scripts, GitHub CLI, GitHub Pages, shell-based Swift tests

---

### Task 1: Lock updater configuration with tests

**Files:**
- Create: `Tests/UpdateConfigurationTests.swift`
- Modify: `Tests/test_release_pipeline.sh`

- [ ] **Step 1: Write failing tests for GitHub release URLs, appcast URLs, and updater metadata defaults**
- [ ] **Step 2: Run the focused tests and confirm they fail**
- [ ] **Step 3: Add the minimal configuration helpers needed by the tests**
- [ ] **Step 4: Re-run the focused tests and confirm they pass**

### Task 2: Add a Sparkle wrapper to the app

**Files:**
- Create: `Mecha/Managers/UpdateManager.swift`
- Modify: `Mecha/MechaApp.swift`
- Modify: `Mecha/Info.plist`

- [ ] **Step 1: Vendor Sparkle's framework/tools into the repo**
- [ ] **Step 2: Add a testable update-configuration surface**
- [ ] **Step 3: Implement the Sparkle-backed update manager**
- [ ] **Step 4: Wire the update manager into app startup and bundle metadata**
- [ ] **Step 5: Run the focused Swift tests and typecheck**

### Task 3: Expose updater controls in the UI

**Files:**
- Modify: `Mecha/Views/MenuView.swift`
- Modify: `Mecha/Views/SettingsView.swift`

- [ ] **Step 1: Add a manual `Check for Updates` action in the menu panel**
- [ ] **Step 2: Add an updates card to `Mecha Pro` settings**
- [ ] **Step 3: Keep the UI resilient when Sparkle is unavailable or busy**
- [ ] **Step 4: Re-run the focused typecheck/build commands**

### Task 4: Extend the release pipeline

**Files:**
- Modify: `version.env`
- Modify: `build_mecha.sh`
- Modify: `release_mecha.sh`
- Modify: `scripts/release_common.sh`
- Create: `scripts/generate_update_site.sh`
- Create: `scripts/github_release_publish.sh`
- Create: `.github/workflows/publish-pages.yml`
- Create: `Tests/test_update_site.sh`

- [ ] **Step 1: Add repo-owned release metadata constants and ZIP helpers**
- [ ] **Step 2: Stage updater archives and generate appcast metadata**
- [ ] **Step 3: Publish release assets to GitHub Releases and appcast files to the Pages site directory**
- [ ] **Step 4: Add a GitHub Pages workflow for the generated updater site**
- [ ] **Step 5: Run the shell tests for the release/update pipeline**

### Task 5: Verify end-to-end behavior

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Run focused updater and release tests**
- [ ] **Step 2: Run a full typecheck across the touched Swift files**
- [ ] **Step 3: Build the app and verify Sparkle is embedded in the bundle**
- [ ] **Step 4: Update the README with the updater behavior and internal-eval caveat**
