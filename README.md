# Mecha

<p align="center">
  <img src="./Mecha/Resources/logo_square.png" alt="Mecha logo" width="148" />
</p>

<p align="center">
  <strong>Mechanical keyboard software for macOS.</strong><br />
  A native menu bar app that brings switch acoustics, sound packs, and low-latency playback to your Mac.
</p>

## What Mecha Is

Mecha is a macOS menu bar utility that plays mechanical keyboard sounds system-wide while you type. It is designed for people who want the feel of switch acoustics without changing their hardware, and for builders who want a cleaner foundation for pack research, sound normalization, and playback tuning.

The app is built in SwiftUI/AppKit and includes a native settings window, a low-latency audio engine, a switch-aware sound pack catalog, and tooling for importing and validating richer keyboard sound datasets.

## Highlights

- Native macOS menu bar app with no Dock presence during normal use
- Low-latency audio playback tuned for keyboard interaction
- Master output plus per-key-family acoustic mixer controls
- Structured sound pack catalog with brand, switch, and variant grouping
- Manifest v2 support for richer sample coverage and rendering hints
- Sound pack import, validation, and normalization tooling
- macOS-style settings UI and permissions onboarding
- Build and DMG scripts with centralized versioning

## How It Works

Mecha listens for keyboard events through macOS Accessibility APIs, maps those events into keyboard zones, then triggers preloaded samples through the audio engine with pack-specific rendering hints. The current codebase supports:

- legacy bundled packs
- imported multi-sample packs
- variant-aware catalog display
- spatial and timing hints in the playback pipeline
- a menu bar control surface for output, mixer, and sound pack selection

## Requirements

- macOS 14 or later
- Xcode Command Line Tools
- Accessibility permission so Mecha can hear global key events

## Build

```bash
bash ./build_mecha.sh
open ./build/Mecha.app
```

`build_mecha.sh` now builds the exact version already present in [`version.env`](./version.env).

To prepare the next release version locally before a manual release:

```bash
bash ./scripts/prepare_release_version.sh
```

## Create A DMG

```bash
bash ./create_dmg.sh
```

## GitHub Release Updates

Mecha now supports Sparkle-based updates for existing installs using:

- GitHub Releases for update archives
- GitHub Pages for the `appcast.xml` feed
- a versioned `.zip` for in-app updates
- a `.dmg` for first-time manual installs

The release path is now merge-driven:

1. open a PR against `main`
2. update the release version metadata in the PR
3. let `PR Release Validation` confirm the branch is releaseable
4. merge to `main`
5. let `Release On Main` build, sign, notarize, publish the GitHub release, and deploy the update feed

The `main` workflow publishes the exact `APP_VERSION` and `BUILD_NUMBER` already committed in the merged PR. It does not auto-bump versions in CI.

For manual local releases, the old path still exists:

```bash
bash ./ship_release.sh
```

That path prepares the next patch version locally, builds the app, creates both release assets, pushes the release commit, and publishes the GitHub release.

### Required GitHub Secrets

`Release On Main` expects these repository secrets:

- `MECHA_SIGN_CERT_P12_BASE64`
- `MECHA_SIGN_CERT_PASSWORD`
- `MECHA_SIGN_IDENTITY`
- `MECHA_NOTARY_APPLE_ID`
- `MECHA_NOTARY_TEAM_ID`
- `MECHA_NOTARY_APP_PASSWORD`

### Local Sync

GitHub is now the source of truth for `main`, release tags, and GitHub Releases. After a merge or release, sync a local clone with:

```bash
bash ./sync_repo.sh
```

That is equivalent to:

```bash
git checkout main
git pull --ff-only --tags
```

The first updater-enabled build still needs to be installed manually once. After that, users can use `Check for Updates` from the menu or settings, and Mecha can also poll the feed automatically.

## Internal Evaluation On macOS

For internal testing, Mecha can be opened manually even before Developer ID signing and notarization are in place.

1. Open `Mecha.app`, or drag it from the DMG to `Applications` and try launching it once.
2. macOS will block it.
3. Open `System Settings > Privacy & Security`.
4. Near the bottom, find the message that says `Mecha` was blocked.
5. Click `Open Anyway`.
6. Confirm again in the follow-up dialog.

This is only a temporary evaluation path for trusted internal Macs. Public distribution still needs proper Apple signing and notarization.

## Project Layout

- [`Mecha/`](./Mecha): Swift source, app resources, sound packs, icons, and views
- [`SoundPipeline/`](./SoundPipeline): pack import, grouping, and normalization utilities
- [`Tests/`](./Tests): lightweight regression and validation checks
- [`docs/`](./docs): design notes and implementation planning docs
- [`raw_sources/`](./raw_sources): local research and reference material for pack exploration

## Audio Pack Direction

Mecha is moving toward a richer pack model that keeps audio variants distinct instead of flattening them away. The current tooling focuses on:

- preserving brand-level identity
- keeping switch variants separate when the recording context changes
- mapping multi-file upstream packs into keyboard zones
- validating coverage before shipping packs

## Acknowledgements

Mecha’s pack research and normalization work draws inspiration from the open mechanical keyboard sound community, including projects such as Wayvibes, Mechvibes, and Mechvibes DX.

## Status

This repository tracks the active macOS app and audio pipeline work. Expect the pack format, engine tuning, and release polish to keep improving as the sound library gets deeper.
