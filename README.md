# PBZzzzSkinManager

[English](README.md) | [简体中文](README.zh-CN.md)

An in-game character and cinematic manager for **Phantom Blade Zero** on Windows Steam. Compatible character packs join through manifests; Core is not tied to Seed, Ye Shunguang, or any other specific character.

**[Download Core 2.4.2 Preview](https://github.com/Donmmn/PBZzzzSkinManager/releases/tag/v2.4.2-preview)** · [Character-pack format](docs/character-packs.md) · [Report a problem](https://github.com/Donmmn/PBZzzzSkinManager/issues)

Download **PBZWardrobe-Core-2.4.2-preview.zip** from the release assets. GitHub's automatic **Source code** archives are not installable mod packages.

![Actual in-game manager demonstration](https://github.com/Donmmn/PBZzzzSkinManager/releases/download/v2.4.2-preview/Core-overview.png)

*User-supplied gameplay screenshot. The displayed character is a separate download.*

## Features

- F10 wardrobe with a looping diagonal roster, live character preview, exclusive UI input, and Chinese/English interface.
- Opt-in F5 stylized character shading. The lower-left status shows the actual scheme and material coverage.
- Per-character Ultimate movie switch, import-folder access, and a combined recheck/preview action.
- Explicit folder scanning; empty slots open the character-pack folder.
- An optional manual **Refill ultimate** button for the local player. No automatic refill or skill activation.
- Original-skin selection, applied after reloading a save or restarting the game.

## Requirements

- Windows x64 and Steam Phantom Blade Zero.
- [PBZ-configured UE4SS v3.0.1-1183-gcdbc0b66](https://github.com/KintaroModding/ue4ss/releases/tag/v3.0.1-1183-gcdbc0b66), installed separately.
- Windows Media Foundation for movies; Windows N may need the Media Feature Pack.
- Compatible character packs, downloaded separately from the author's character releases / Quark shares. No Quark download links have been announced in this repository yet.

Players do **not** need Unreal Editor, Blender, Python, FFmpeg, or an external video player. Core includes shared UI, compatibility skeleton resources, shaders, and the Original thumbnail, but no custom playable character, character texture/portrait pack, Ultimate movie, or UE4SS loader.

## Installation

1. Close the game and back up existing mods.
2. Extract the linked PBZ UE4SS package into `PBZ/platform/steam`, beside the larger `PBZ.exe`.
3. Extract the Core ZIP. Merge **`platform` and `ProjectPBZ` from inside `GameFiles`** into the PBZ game root. Do not copy the outer `GameFiles` folder itself.
4. Install compatible character packages with the same relative layout, then launch through Steam and load a save.

When upgrading, preserve `State`, `selected.txt`, and your `controls.json`. Merge any adapters added by other mods before overwriting shared scripts. Legacy direct-replacement packages can interfere with Original restoration. Adding cooked model resources requires a full game restart; scanning refreshes manifests and does not mount new containers dynamically.

## Controls

| Control | Action |
| --- | --- |
| F10 | Open / close the wardrobe |
| Esc | Close the panel or cancel a movie |
| Mouse, arrows, Enter | Select / apply a character or activate an action |
| F5 | Toggle a supported character's stylized shading; starts OFF |
| Scan button / F8 while open | Refresh the cached character list |
| Globe button | Switch Chinese / English |
| Refill ultimate | Explicitly refill the current player's ability energy |

If another mod uses F5/F10, edit `wardrobe_key` and `shader_key` in `controls.json` to other F1–F12 keys and restart. Selecting Original takes effect after reloading a save or restarting; it does not immediately restore native cloth/animation in-place.

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

This release is a **preview**. The existing local integrated installation was accepted on Steam build **26367565**; an independent clean install of this portable generic distribution is still pending. Game updates may require changes. No FPS guarantee is claimed. Manual installation is documented; Vortex deployment is unverified.

F5 is an original stylized implementation, not a complete recreation of ZZZ's official renderer. Actual capability and parameters come from the character manifest. Core adapts the adult Hun protagonist; it is not an arbitrary PAK converter or a whole-game mod manager.

## Source, build, and safety

Runtime Lua is in `Scripts/`; native audio/directory helper source and Shader/UI authoring files are in `source/`. [Build scope](docs/build.md) explains how to build the helper and why this repository does not independently rebuild all game-specific cooked resources. The release ZIPs retain the exact previously reviewed 2.4.2 bytes; checksums are provided with the release.

The helper DLL is unsigned and handles local movie audio, directory listing, and explicitly requested folder opening. Source visibility and scan results are not an absolute safety guarantee. [Security and AI disclosure](docs/security-and-ai.md) describes the package and current Nexus source-archive review status. Do not disable system protection to install it.

## Credits and permissions

PBZ: **S-GAME**. UE4SS: **UE4SS-RE**. PBZ loader configuration: **KintaroModding**. `json.lua`: **rxi**, MIT notice retained. [Third-party notices](THIRD_PARTY_NOTICES.md).

Code, UI, original shaders, and documentation were developed with OpenAI Codex / ChatGPT assistance and iterative user testing. The demonstration is a real gameplay screenshot. This repository is **source-available for review**; no additional project-wide open-source license has been granted. Third-party and game-derived assets retain their own rights. Character packs and movies have separate attribution and permission notices.
