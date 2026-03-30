# GitHub Release Updater Design

## Goal

Add a native macOS updater to Mecha so existing users can receive new releases from GitHub Releases through a Sparkle appcast published on GitHub Pages.

## Constraints

- Keep the current manual `swiftc` build flow working locally.
- Skip Apple Developer ID signing and notarization for now.
- Preserve the existing DMG-based install path for first-time installs.
- Do not disturb the already-dirty event-tap permission fix in the working tree.

## Approved Approach

Use Sparkle 2 with its prebuilt framework vendored into the repository, GitHub Releases as the update archive host, and GitHub Pages as the `appcast.xml` host.

### Why this approach

- Sparkle provides the native updater UX macOS users expect.
- GitHub Releases is already the project's distribution source.
- GitHub Pages gives us a stable feed URL without standing up separate infrastructure.
- Vendoring Sparkle's prebuilt framework avoids depending on a full Xcode package-resolution flow on this machine.

## App Design

Add a small `UpdateManager` wrapper around Sparkle's `SPUStandardUpdaterController`.

Responsibilities:

- start the updater on launch
- expose updater state to SwiftUI
- provide a `checkForUpdates()` action for menu/settings UI
- surface whether automatic update checks are enabled
- keep all Sparkle-specific code isolated from the rest of the app

UI changes:

- add a `Check for Updates` action in the menu bar panel footer
- add an `Updates` section in `Mecha Pro` settings showing feed status and automatic checks

Configuration:

- add `SUFeedURL`
- add `SUPublicEDKey`
- enable automatic checks by default with a reasonable interval

## Release Design

Extend the release flow to produce both:

- a DMG for manual installs
- a ZIP archive for Sparkle updates

Release metadata flow:

1. Build `Mecha.app`
2. Create `Mecha.zip`
3. Upload release assets to GitHub Releases
4. Generate `appcast.xml` from the archive directory using Sparkle tooling
5. Publish the appcast site to GitHub Pages

The appcast will reference GitHub Release asset URLs directly.

## Publishing Design

Store the generated updater site in a repo-owned folder so it can be deployed by GitHub Actions to Pages.

Site contents:

- `appcast.xml`
- optional release-notes files per version if present later

Use a Pages workflow to deploy the generated site directory whenever release metadata is updated on `main`.

## Security Model For Now

- Sparkle EdDSA signing is enabled for update archive integrity.
- Apple notarization is intentionally deferred.
- The first updater-enabled build still requires manual installation and local Gatekeeper bypass for internal evaluation.

## Verification

We will verify:

- Sparkle can be imported and linked by the current `swiftc` build
- the app bundle embeds Sparkle correctly
- the updater UI compiles and exposes the manual check action
- release helper tests generate the correct GitHub URLs and appcast staging layout
- the release script can emit a ZIP plus `appcast.xml`
