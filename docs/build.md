# Source and build scope

## Native helper

The frozen `source/build.cmd` builds `source/PBZCinematicAudio.cpp` into `Tools/PBZCinematicAudio.dll`. Install Visual Studio 2022 with the C++ desktop workload and a Windows SDK. Adjust its `vcvars64.bat` location if Visual Studio is not installed at the default Community path, then run the script. This is a developer build step, not a player installation requirement.

The helper links Windows Media Foundation, waveOut, OLE and Shell libraries. It accepts validated local paths for audio and explicitly requested directory actions; it is not a downloader or an installer. Runtime state is kept under the mod's local State directory. The build uses the static C++ runtime and PE hardening flags; the released DLL is unsigned. A successful build is not a claim of bit-for-bit reproducibility with the existing DLL.

## Cooked Shader / UI / skeleton resources

The release contains the runtime resources needed by Core. Shader HLSL and material/UI author scripts are included here for review. The target PBZ Unreal branch has game-specific uniform-buffer and shader ABI layouts, so a stock engine version and these small author scripts alone do not reconstruct every compatible cooked container. The full adjusted editor/cook/package toolchain is not included. **This repository is not a one-click full binary build.** Do not recook existing resources with a stock engine and assume compatibility.

## Source validation

Run `python tools/check_source.py --core-zip <downloaded Core ZIP>` to compare every published runtime Lua script against the frozen install package, allowing UTF-8 BOM / CRLF-to-LF checkout normalization only, validate JSON, and reject accidental private state/binary/video content in the source tree. With the optional developer dependency `lupa`, `--lua` additionally compiles the Lua sources. This is offline validation, not in-game acceptance.

Historical UI fixture scripts remain in the unchanged Source Review release ZIP. Their old workspace-relative paths are not advertised as portable tests; they are omitted from this repository. Runtime Lua is synchronized with the current release package; repository text transport may normalize line endings. The versioned Source Review ZIP preserves the corresponding source files for review.

The initial `v2.4.2-preview` source tag used a strict byte comparison in the check script. Use the current `main` branch's check script when validating an LF-normalized checkout. The installer and optional Source Review ZIP are unchanged; this maintenance correction does not alter game behavior.
