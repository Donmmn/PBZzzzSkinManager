# Character packs

[简体中文](character-packs.zh-CN.md)

Use `schema/model.schema.json` and `schema/contract.json` together with the actual `Scripts/profile_config.lua` validator. The example manifest contains placeholder resource paths and is **not a working character**.

```text
GameFiles/ProjectPBZ/Content/Paks/~mods/PBZWardrobeModels/<id>/
  model.json
  Textures/<material identifier>.png
  Packages/<resource>.pak
  Packages/<resource>.utoc
  Packages/<resource>.ucas
  Ultimate.mp4                    # optional
```

The lowercase ASCII id must match its directory. A pack needs a PBZ-compatible mesh, post-process animation blueprint, secondary-physics resource and textures; ordinary MMD files cannot be loaded directly. Material slot indices are zero-based. Explicit face/hair/eye roles prevent character-specific guesses. Shader use is opt-in through `paint.enabled`, declared parents, surface types and scalar parameters; the original-skin and native combat paths are not arbitrary character replacements.

Core bundles v4/v5 shader masters. For v5, surface type 4 adds exposed-skin shading. Do not enable primary hit physics unless the declared sockets and physics asset fit the character skeleton. Incorrect collision setup can break damage reception. Keep all pak/utoc/ucas companions and restart after adding containers.

For Quark distribution, package the same GameFiles layout with CN/EN instructions, source credits/permissions, version/required Core version and SHA256SUMS.txt. Place an optional authorized Ultimate.mp4 beside model.json, not in the Core archive. No automatic network download is performed by the manager.

Test cold load, switching both ways, F5 on/off, hit damage, weapon grip, movement, secondary physics, teleport, actual cutscenes and uninstall. A valid manifest is not proof of game compatibility. Preserve other projects' adapters and only overwrite files owned by this pack.
