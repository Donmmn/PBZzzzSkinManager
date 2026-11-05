# Hotkey compatibility — 2.4.5

## English

New installations default to **F6** for the wardrobe and **F5** for shading. Existing controls.json is preserved and takes precedence; changing wardrobe_key to "F6" is an explicit migration, not an automatic upgrade. Keep the user's shader_key. Read the config once at startup and restart after edits. The footer uses the actual configured names in both languages.

The old F10 default can collide with UE4SS ConsoleEnablerMod, which adds Tilde and F10 to the engine's native ConsoleKeys. That is separate from UE4SS's debug GUI toggle, Ctrl+O by default; checking only IsKeyBindRegistered cannot see the native ConsoleKeys path. F11 was considered but PBZ's own DefaultInput.ini enables bF11TogglesFullscreen, so the final release uses F6 and does not change fullscreen settings. The experimental F11 fullscreen module is not shipped or required.

F6 worked in the clean installation tested for this release. This does not guarantee compatibility with every additional mod or custom key map. If a key is occupied, choose a free F1–F12 key in your own controls.json, keep wardrobe and shader keys distinct, and restart. Core does not disable other mods or rewrite UE4SS/engine input settings to claim a key.

## 简体中文

新安装默认 **F6 面板 / F5 着色**。已有controls.json优先保留；把wardrobe_key改成"F6"需要明确迁移，升级不会静默代改。保留自己的shader_key。配置在启动时读取，修改后重启，中英文底部提示取实际键名。

旧默认F10会与UE4SS ConsoleEnablerMod的原生ConsoleKeys产生有条件冲突，与默认Ctrl+O的UE4SS调试GUI不是同一机制。仅查IsKeyBindRegistered不能发现原生ConsoleKeys占用。曾考虑F11，但PBZ自己的DefaultInput.ini开启bF11TogglesFullscreen；最终发行改用F6，不修改全屏设置，也不包含或调用试验性的F11全屏兼容模块。

本轮干净安装已确认F6生效，但不能保证任意额外Mod均无冲突。需要时在自己的controls.json选择空闲F1–F12键，保持面板键与着色键不同，重启生效。Core不为占用按键停用其他Mod或重写引擎/UE4SS配置。

## Source references

- [Pinned ConsoleEnablerMod](https://github.com/UE4SS-RE/RE-UE4SS/blob/cdbc0b66cb2bb5b4a3d2f69b6e61a8460961e54c/assets/Mods/ConsoleEnablerMod/Scripts/main.lua)
- [Pinned UE4SS GUI settings](https://github.com/UE4SS-RE/RE-UE4SS/blob/cdbc0b66cb2bb5b4a3d2f69b6e61a8460961e54c/assets/UE4SS-settings.ini)
- [Epic UInputSettings API](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/UInputSettings)
- The PBZ project-config observation was a local read-only inspection; game configuration files and resource keys are not redistributed here.
