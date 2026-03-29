# Open Source Sound Pack Sources

This directory stages upstream sound-pack sources for evaluation and import into Mecha.

## Import-safe now

### mechvibes
- Source: https://github.com/hainguyents13/mechvibes
- Local path: `Mecha/raw_sources/open_source/mechvibes`
- License: MIT (`LICENSE` file present)
- Notes:
  - Upstream audio lives under `src/audio/`
  - Current upstream includes packs such as `cherrymx-*-abs`, `cherrymx-*-pbt`, `nk-cream`, `holy-pandas`, `topre-purple-hybrid-pbt`, `eg-oreo`, and `eg-crystal-purple`

### mechvibes-dx
- Source: https://github.com/hainguyents13/mechvibes-dx
- Local path: `Mecha/raw_sources/open_source/mechvibes-dx`
- License: MIT stated in `README.md`
- Notes:
  - Keyboard packs live under `soundpacks/keyboard/`
  - Format is Mechvibes-style sprite/config pack layout (`config.json` + `sound.ogg`)

## Review-only until license is clarified

### wayvibes
- Source: https://github.com/sahaj-b/wayvibes
- Local path: `Mecha/raw_sources/open_source/wayvibes`
- License: not clearly declared in repo root files fetched locally
- Notes:
  - This source is valuable because many packs are deeper, with per-key WAV coverage
  - Do not redistribute or bundle these packs into Mecha until the license is confirmed

## Practical takeaway

- `mechvibes` and `mechvibes-dx` are the cleanest immediate upstreams for legal import work.
- `wayvibes` is useful as a quality and format reference, but not yet safe for shipping.
