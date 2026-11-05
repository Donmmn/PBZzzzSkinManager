# PBZzzzSkinManager

[English](README.md) | [简体中文](README.zh-CN.md)

An in-game character and cinematic manager for **Phantom Blade Zero** on Windows Steam. Compatible character packs join through manifests; Core is not tied to Seed, Ye Shunguang, or any other specific character.

**[Download Core 2.4.5 — F6](https://github.com/Donmmn/PBZzzzSkinManager/releases/tag/v2.4.5)** · [Character-pack format](docs/character-packs.md) · [Report a problem](https://github.com/Donmmn/PBZzzzSkinManager/issues)

Download **PBZWardrobe-Core-2.4.5-F6.zip** from the release assets. GitHub's automatic **Source code** archives are not installable mod packages.

![Actual in-game manager demonstration](https://github.com/Donmmn/PBZzzzSkinManager/releases/download/v2.4.2-preview/Core-overview.png)

*User-supplied historical 2.4.2 gameplay screenshot for the UI layout. Current 2.4.5 defaults to F6; the displayed character is a separate download.*

## Features

- F6 wardrobe with a looping diagonal roster, live character preview, exclusive UI input, and Chinese/English interface.
- Opt-in F5 stylized character shading. The lower-left status shows the actual scheme and material coverage.
- Per-character Ultimate movie switch, import-folder access, and a combined recheck/preview action.
- Explicit folder scanning; empty slots open the character-pack folder.
- An optional manual **Refill ultimate** button for the local player. No automatic refill or skill activation.
- Original-skin selection, applied after reloading a save or restarting the game.

## Requirements

- Windows x64 and Steam Phantom Blade Zero.
- Install [PBZ-configured UE4SS v3.0.1-1183-gcdbc0b66](https://github.com/KintaroModding/ue4ss/releases/tag/v3.0.1-1183-gcdbc0b66) separately. **Choose the asset named [`phantombladezero_ue4ss_v3.0.1-1183-gcdbc0b66.zip`](https://github.com/KintaroModding/ue4ss/releases/download/v3.0.1-1183-gcdbc0b66/phantombladezero_ue4ss_v3.0.1-1183-gcdbc0b66.zip)** (direct download). Do not choose a generic `UE4SS_v...zip`, a package for another game, or GitHub's `Source code` archives.
- Windows Media Foundation for movies; Windows N may need the Media Feature Pack.
- Compatible character packs, downloaded separately from the author's character releases / Quark shares. No Quark download links have been announced in this repository yet.

Players do **not** need Unreal Editor, Blender, Python, FFmpeg, or an external video player. Core includes shared UI, compatibility skeleton resources, shaders, and the Original thumbnail, but no custom playable character, character texture/portrait pack, Ultimate movie, or UE4SS loader.

## Installation

1. Close the game and back up existing mods.
2. Download the exact PBZ-specific ZIP named above and extract its **contents directly into `PBZ/platform/steam`**, beside the larger `PBZ.exe`. Do not add an extra outer folder named after the ZIP.
3. Extract the Core ZIP. Merge **`platform` and `ProjectPBZ` from inside `GameFiles`** into the PBZ game root. Do not copy the outer `GameFiles` folder itself.
4. Install compatible character packages with the same relative layout, then launch through Steam and load a save.

When upgrading, preserve `State`, `selected.txt`, and your `controls.json`. Merge any adapters added by other mods before overwriting shared scripts. Legacy direct-replacement packages can interfere with Original restoration. Adding cooked model resources requires a full game restart; scanning refreshes manifests and does not mount new containers dynamically.

## Controls

| Control | Action |
| --- | --- |
| F6 | Open / close the wardrobe |
| Esc | Close the panel or cancel a movie |
| Mouse, arrows, Enter | Select / apply a character or activate an action |
| F5 | Toggle a supported character's stylized shading; starts OFF |
| Scan button / F8 while open | Refresh the cached character list |
| Globe button | Switch Chinese / English |
| Refill ultimate | Explicitly refill the current player's ability energy |

Fresh installs default to **F6 wardrobe / F5 shading**. Selecting Original takes effect after reloading a save or restarting; it does not immediately restore native cloth/animation in-place.

### Migrating an older key configuration

The package ships only `controls.example.json`, so it does not overwrite your `controls.json`. Existing settings still win: upgrading does not silently change a previous F10, F11, or custom binding to F6.

With the game closed, edit `platform/steam/ue4ss/Mods/PBZWardrobe/controls.json`: **change only `wardrobe_key` to `"F6"`, keep your existing `shader_key` and other fields**, then restart. If no config exists, the built-in defaults work without creating one. Copy the example to `controls.json` only when you want to customize. Both keys must differ and be F1–F12.

```json
{
  "schema": 1,
  "wardrobe_key": "F6",
  "shader_key": "F5"
}
```

This example assumes you still use F5 for shading; do not overwrite a customized shader key. F6 was verified in this clean installation, but another mod may still use it. [Hotkey compatibility](docs/hotkey-compatibility.md). This version does not modify fullscreen flags, Alt+Enter, INI files, or the UE4SS console.

## Ultimate movies

Put `Ultimate.mp4` beside the chosen character's `model.json`:

```text
ProjectPBZ/Content/Paks/~mods/PBZWardrobeModels/<character-id>/
  model.json
  Ultimate.mp4
```

The switch starts OFF for each character. When the file is missing, clicking it only opens the folder and creates an import-instruction TXT; it does not enable playback. Use **Recheck and preview** after importing. A character's optional **With Cinematic** edition can bundle the file in that directory for automatic discovery.

Recommended encoding: H.264 video + AAC audio, at most 60 seconds / 512 MB. When enabled, the corresponding successful Q / controller LT Combat Art plays the movie, pauses the world, and restores play when finished. Insufficient energy should not trigger substitute playback. Do not replace missing clips with unlicensed downloads.

## Compatibility and status

This round verified the clean Steam environment (695 files), SHA256 for 108 freshly imported files, and a cold save load with the F6 panel working in-game. The release's 60 GameFiles match that tested installation; only documentation and release metadata were finalized. The full character/combat/cutscene regression suite was not repeated this round. [Validation scope](docs/validation-2.4.5.md). Game updates may require changes; no FPS guarantee is claimed and Vortex deployment remains unverified.

F5 is an original stylized implementation, not a complete recreation of ZZZ's official renderer. Actual capability and parameters come from the character manifest. Core adapts the adult Hun protagonist; it is not an arbitrary PAK converter or a whole-game mod manager.

## Source, build, and safety

Runtime Lua is in `Scripts/`; native audio/directory helper source and Shader/UI authoring files are in `source/`. [Build scope](docs/build.md) explains how to build the helper and why this repository does not independently rebuild all game-specific cooked resources. The current installer contains the GameFiles tested in this F6 installation; release checksums are provided. It supersedes the old 2.4.2 installer, which is no longer recommended.

The helper DLL is unsigned and handles local movie audio, directory listing, and explicitly requested folder opening. Source visibility and scan results are not an absolute safety guarantee. [Security and AI disclosure](docs/security-and-ai.md) describes the package and historical Nexus source-archive review context. Do not disable system protection to install it.

## Credits and permissions

PBZ: **S-GAME**. UE4SS: **UE4SS-RE**. PBZ loader configuration: **KintaroModding**. `json.lua`: **rxi**, MIT notice retained. [Third-party notices](THIRD_PARTY_NOTICES.md).

Code, UI, original shaders, and documentation were developed with OpenAI Codex / ChatGPT assistance and iterative user testing. The demonstration is a real gameplay screenshot. This repository is **source-available for review**; no additional project-wide open-source license has been granted. Third-party and game-derived assets retain their own rights. Character packs and movies have separate attribution and permission notices.
