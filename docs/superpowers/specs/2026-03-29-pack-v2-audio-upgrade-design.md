# Pack V2 Audio Upgrade Design

**Goal:** Move Mecha toward Klack-level quality through a hybrid route: richer pack metadata and deeper upstream-style assets now, with runtime and engine support that can scale into premium packs next.

**Context**
- Mecha currently loads a shallow manifest with `keyMapping` and optional `keyUpMapping`.
- Built-in packs are small and inconsistent; most have no true release samples.
- The upstream `soundpacks.zip` provides much deeper legacy-style flat packs with hundreds of samples across multiple switch sets.
- Mecha already has two pack builders, but they output mismatched schemas.

**Design**
- Introduce `manifestVersion: 2` as the canonical pack format.
- Keep backward compatibility with existing manifest v1 packs in the runtime loader.
- Standardize all build/import tooling on a single canonical builder path that emits manifest v2.
- Add explicit compatibility metadata so shallow or imported flat packs are clearly marked as `legacy` instead of pretending to be fully grouped premium packs.
- Expand runtime metadata to support grouped down/up samples, fallback routing, audio metadata, and rendering hints for the audio engine.

**Manifest V2**
- Required top-level fields:
  - `manifestVersion`
  - `id`
  - `name`
  - `brand`
  - `switchType`
  - `audio`
  - `groups`
  - `fallbacks`
  - `coverage`
- Optional top-level fields:
  - `description`
  - `rendering`
  - `compatibility`
- `groups` maps logical key groups to `down` and `up` sample arrays.
- `fallbacks` maps unsupported groups to a nearest supported group.
- `coverage` records whether the pack is premium or compatibility-oriented and exposes sample counts for validation/reporting.
- `rendering` provides engine hints like `defaultGainDb`, `stereoWidth`, and `pitchJitterCents`.

**Compatibility Strategy**
- Runtime continues to parse v1 manifests.
- Existing Mecha packs will be converted into explicit compatibility packs.
- Imported upstream flat packs from `soundpacks.zip` will be converted into v2 compatibility packs where:
  - `groups.alphanumeric.down` contains the imported pool
  - other groups fall back to `alphanumeric`
  - `coverage` and `compatibility` explicitly state reduced grouping fidelity

**Canonical Builder**
- Canonical builder lives under `SoundPipeline/`.
- It must support:
  - structured grouped source packs
  - flat legacy source packs
  - zip/import workflows for upstream packs
- Both old builder paths will be retired into wrappers or compatibility entry points that emit the same v2 manifest contract.

**Validator**
- Add a validator script that checks:
  - manifest version and schema correctness
  - required files exist
  - coverage counts are accurate
  - pack tier is marked correctly
  - premium packs meet minimum grouped sample thresholds

**Engine Prep**
- SoundPackManager should expose rendering hints from v2 manifests.
- AudioEngineManager should consume those hints for better playback behavior.
- First engine-prep pass in this scope:
  - pack-driven gain hints
  - pack-driven pitch jitter hints
  - pack-driven stereo spread hints

**Upstream References**
- `wayvibes`, `mechvibes`, and `mechvibes-dx` are reference inputs for compatibility and cleaner import/release paths.
- Mecha remains its own implementation and pack format owner.
