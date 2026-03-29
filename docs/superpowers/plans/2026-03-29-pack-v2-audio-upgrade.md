# Pack V2 Audio Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add manifest v2 support, unify the pack toolchain, import deeper upstream soundpacks in compatibility mode, and prepare the audio engine to consume richer pack metadata.

**Architecture:** Mecha will support two runtime manifest generations: legacy v1 and canonical v2. A single builder/validator toolchain will emit v2 packs from either grouped premium sources or flat legacy sources, and the audio engine will consume pack rendering hints exposed by `SoundPackManager`.

**Tech Stack:** Swift, SwiftUI, AVFoundation, Python 3, shell build scripts

---

### Task 1: Add Failing Runtime Tests For Manifest V2

**Files:**
- Create: `Tests/SoundPackManifestV2Tests.swift`
- Modify: `Tests/AudioEnginePreferenceTests.swift`

- [ ] **Step 1: Write failing manifest v2 and rendering-hint tests**
- [ ] **Step 2: Run the standalone Swift tests and verify they fail for missing v2 support**
- [ ] **Step 3: Add failing audio helper assertions for pack-driven stereo/gain behavior**
- [ ] **Step 4: Run the tests again and verify the failures are correct**

### Task 2: Implement Manifest V2 Support In The Runtime Loader

**Files:**
- Modify: `Mecha/Managers/SoundPackManager.swift`

- [ ] **Step 1: Add manifest v2 Codable types for audio, rendering, groups, fallbacks, coverage, and compatibility metadata**
- [ ] **Step 2: Keep v1 decoding intact and add dual-format dispatch in the loader**
- [ ] **Step 3: Normalize v1 and v2 manifests into one runtime representation**
- [ ] **Step 4: Expose active pack rendering hints for the audio engine**
- [ ] **Step 5: Run the standalone Swift tests and make sure they pass**

### Task 3: Prepare The Audio Engine For Richer V2 Packs

**Files:**
- Modify: `Mecha/Managers/AudioEngineManager.swift`
- Modify: `Mecha/Managers/AppController.swift`

- [ ] **Step 1: Add failing tests for pack-driven playback helpers**
- [ ] **Step 2: Add rendering-profile support in the audio engine**
- [ ] **Step 3: Apply pack-driven gain, pitch-jitter, and stereo-width hints during playback**
- [ ] **Step 4: Wire `SoundPackManager` rendering metadata into `AudioEngineManager` through `AppController`**
- [ ] **Step 5: Run the audio helper tests and make sure they pass**

### Task 4: Standardize On One Canonical Builder And Add Validation

**Files:**
- Create: `SoundPipeline/manifest_v2.py`
- Create: `SoundPipeline/validate_pack.py`
- Modify: `SoundPipeline/build_pack.py`
- Modify: `split_mp3_to_pack.py`

- [ ] **Step 1: Write failing validator smoke checks for v2 packs**
- [ ] **Step 2: Add a shared manifest-v2 builder helper module**
- [ ] **Step 3: Update the canonical builder to emit manifest v2 for grouped and flat sources**
- [ ] **Step 4: Retire the schema mismatch by making `split_mp3_to_pack.py` emit the same v2 contract**
- [ ] **Step 5: Add validator rules for coverage and compatibility labeling**
- [ ] **Step 6: Run the validator tests and make sure they pass**

### Task 5: Import And Convert Current Packs Plus Upstream Soundpacks

**Files:**
- Create: `SoundPipeline/import_legacy_soundpacks.py`
- Modify: `Mecha/Resources/SoundPacks/*/manifest.json`
- Modify: `Mecha/Resources/SoundPacks/`

- [ ] **Step 1: Inspect and extract the provided `soundpacks.zip` into a reproducible import path**
- [ ] **Step 2: Convert Mecha’s existing built-in packs to explicit compatibility-aware v2 manifests**
- [ ] **Step 3: Import upstream flat packs as v2 compatibility packs with accurate fallback and coverage metadata**
- [ ] **Step 4: Run the validator against built-in and imported packs**
- [ ] **Step 5: Smoke-check that the app can enumerate the new packs**

### Task 6: Verify Build And Runtime Integration

**Files:**
- Modify: `Tests/SettingsWindowMetricsTests.swift` only if required by collateral compile changes

- [ ] **Step 1: Run all standalone Swift tests**
- [ ] **Step 2: Run pack validator over the bundled packs**
- [ ] **Step 3: Build the app with `bash ./build_mecha.sh`**
- [ ] **Step 4: Relaunch the built app and confirm the new pack inventory loads**
- [ ] **Step 5: Summarize the next engine-quality slice after v2 pack support is in place**
