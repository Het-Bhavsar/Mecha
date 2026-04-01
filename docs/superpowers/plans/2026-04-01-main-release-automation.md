# Main Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every merge to `main` publish a signed GitHub release for the exact merged version while blocking unreleasable PRs before they land.

**Architecture:** Split version bumping from building so CI can release immutable merge commits, add shell validation helpers that enforce release metadata correctness, and wire GitHub Actions to run PR validation plus signed/notarized release publishing on `main`.

**Tech Stack:** Bash, GitHub Actions, GitHub CLI, macOS signing/notarization tools, shell-based tests, Git metadata

---

### Task 1: Lock release metadata invariants with tests

**Files:**
- Create: `Tests/test_release_metadata_validation.sh`
- Modify: `Tests/test_release_pipeline.sh`

- [ ] **Step 1: Write failing tests for metadata validation and non-mutating release builds**
- [ ] **Step 2: Run the focused shell tests and confirm they fail for the missing helpers**
- [ ] **Step 3: Add minimal helper coverage to the existing release test script**
- [ ] **Step 4: Re-run the focused shell tests and confirm they pass**

### Task 2: Split version preparation from building

**Files:**
- Create: `scripts/prepare_release_version.sh`
- Create: `scripts/validate_release_metadata.sh`
- Modify: `build_mecha.sh`
- Modify: `release_mecha.sh`
- Modify: `ship_release.sh`
- Modify: `scripts/versioning.sh`

- [ ] **Step 1: Add a standalone version-prep script that bumps and synchronizes version files**
- [ ] **Step 2: Refactor the build path so it uses the existing version without editing tracked files**
- [ ] **Step 3: Add a metadata validation script that checks all version sources agree**
- [ ] **Step 4: Wire release scripts to validate metadata before building or publishing**
- [ ] **Step 5: Re-run the focused shell tests**

### Task 3: Add CI-safe release publishing behavior

**Files:**
- Modify: `scripts/github_release_publish.sh`
- Modify: `scripts/release_common.sh`

- [ ] **Step 1: Add guardrails for duplicate tags/releases**
- [ ] **Step 2: Make release creation target the exact pushed commit SHA**
- [ ] **Step 3: Keep asset upload idempotent without silently re-pointing tags**
- [ ] **Step 4: Re-run the focused release tests**

### Task 4: Wire GitHub Actions for validation and release

**Files:**
- Create: `.github/workflows/pr-release-validation.yml`
- Create: `.github/workflows/release-on-main.yml`
- Modify: `.github/workflows/publish-pages.yml`

- [ ] **Step 1: Add a PR workflow that validates version bumps and release helpers**
- [ ] **Step 2: Add a `main` release workflow on macOS with signing/notary setup**
- [ ] **Step 3: Publish GitHub Releases and deploy the generated appcast site from CI**
- [ ] **Step 4: Make the Pages workflow coexist cleanly with the new release path**

### Task 5: Add local sync affordances and documentation

**Files:**
- Create: `sync_repo.sh`
- Modify: `README.md`

- [ ] **Step 1: Add a one-command local sync helper for `main` and tags**
- [ ] **Step 2: Document the new merge-to-release flow and required GitHub secrets**
- [ ] **Step 3: Run the full touched shell test suite and capture any remaining gaps**
