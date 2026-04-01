# Main Release Automation Design

## Goal

Make every merge into `main` produce a signed GitHub release automatically from GitHub Actions, using the exact version already committed in the merged code.

## Constraints

- GitHub Actions must become the authoritative release path.
- CI must not mutate tracked version files during release.
- The published release must be built from the exact merge commit on `main`.
- Apple signing and notarization must run on GitHub-hosted macOS runners using repository secrets.
- The local repository cannot be force-synced remotely, so local sync must be reduced to a single fetch/pull path.

## Approved Approach

Use a two-workflow model:

- a `pull_request` validation workflow that blocks merges to `main` unless the incoming change is releaseable
- a `push` to `main` release workflow that validates the merged commit, signs/notarizes the app, creates the matching GitHub tag/release, and deploys the generated appcast site

### Why this approach

- It removes the current gap between "merged on GitHub" and "released from a local machine".
- It preserves a single source of truth for release metadata: the merged commit itself.
- It keeps releases deterministic because CI builds the checked-out merge SHA instead of a later local state.
- It shifts secrets and signing to GitHub infrastructure instead of depending on whoever merged the PR.

## Versioning Design

`version.env` remains the canonical release manifest. The following files must always agree with it:

- `version.env`
- `Mecha/Info.plist`
- `project.yml`
- `Mecha.xcodeproj/project.pbxproj`

The current `build_mecha.sh` script auto-bumps versions before every build. That behavior is incompatible with CI releasing the exact merged commit, so version preparation must be split into two actions:

- explicit version bump/sync for local release preparation
- non-mutating build/release commands for CI and verification

The release pipeline will fail if version metadata is inconsistent or if a `main` merge reuses an existing tag.

## Workflow Design

### Pull Request Validation

Trigger on `pull_request` targeting `main`.

Validation rules:

- require the release version to change in the PR compared with the base branch
- require all version metadata files to stay in sync
- run the shell tests that verify release helpers and update-site generation

This makes "every merge to `main` is releaseable" an enforced invariant instead of a convention.

### Release On Main

Trigger on every push to `main`.

Release flow:

1. Check out the exact pushed commit.
2. Validate version metadata consistency.
3. Fail fast if the target release tag or GitHub release already exists.
4. Import the Developer ID certificate into a temporary CI keychain.
5. Store `notarytool` credentials in a temporary keychain profile.
6. Build the app without changing tracked version files.
7. Produce the ZIP and DMG assets.
8. Notarize and staple the artifacts.
9. Generate the appcast/update site from the released version.
10. Publish the GitHub release for the exact commit SHA.
11. Deploy the generated appcast site to GitHub Pages.

## Secrets And Signing Model

The release workflow will require repository secrets for:

- base64-encoded Developer ID Application certificate (`.p12`)
- certificate password
- signing identity name
- Apple ID used for notarization
- Apple team ID
- Apple app-specific password for `notarytool`

These secrets are only used inside the release workflow. Missing or invalid secrets are a hard failure because `main` should not advance to an unreleasable state.

## Local Sync Design

GitHub Actions cannot push changes into a contributor's local clone. The correct fix is to eliminate local-only release state and make GitHub the authoritative source for:

- `main`
- release tags
- GitHub Releases
- deployed appcast content

Local sync is then reduced to fetching the current branch and tags:

`git checkout main && git pull --ff-only --tags`

To reduce drift further, add a small helper script that performs that exact sync command and document it in the README.

## Failure Modes

- If a PR forgets to bump the release version, validation fails before merge.
- If merged version files disagree, validation fails before merge and before release.
- If a pushed `main` commit tries to reuse an existing tag, the release workflow fails without overwriting anything.
- If signing or notarization credentials are invalid, the release workflow fails and no partial release is published.

## Verification

We will verify:

- version validation fails when metadata disagrees
- version validation fails when a PR to `main` does not advance the release version
- release scripts can build from existing version metadata without bumping it
- the `main` release workflow is wired to create the release from the pushed SHA
- the README documents both the GitHub secret setup and the local sync command
