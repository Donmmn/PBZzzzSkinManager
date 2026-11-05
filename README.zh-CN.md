# PBZzzzSkinManager

[English](README.md) | [简体中文](README.zh-CN.md)

用于 Windows Steam《**影之刃零**》的游戏内角色与大招动画管理器。兼容角色通过清单接入，前置不限于席德、叶瞬光或其他指定角色。

**[下载管理器 2.4.5（默认 F6）](https://github.com/Donmmn/PBZzzzSkinManager/releases/tag/v2.4.5)** · [角色包接入说明](docs/character-packs.zh-CN.md) · [反馈问题](https://github.com/Donmmn/PBZzzzSkinManager/issues)

请下载发布附件里的 **PBZWardrobe-Core-2.4.5-F6.zip**。GitHub 自动生成的 **Source code** 压缩包只是源码，不能作为模组安装。

![真实游戏内管理器演示](https://github.com/Donmmn/PBZzzzSkinManager/releases/download/v2.4.2-preview/Core-overview.png)

*用户提供的 2.4.2 历史界面截图，布局供参考；当前 2.4.5 默认使用 F6。图中角色需要单独下载。*

## 功能

- F6 换装面板：斜向循环列表、实时角色预览、界面独占输入和中英文切换。
- F5 开关兼容角色的三渲二材质，左下角显示实际着色方案及材质覆盖范围。
- 每个角色独立的大招动画开关、导入目录入口与“检测并预览”功能。
- 手动扫描角色目录；点击空槽打开角色模组文件夹。
- 可选的“充满大招能量”按钮，只在点击时补满当前玩家能量，不自动充能或释放技能。
- 切换回游戏原皮，在重载存档或重启后生效。

## 环境要求

- Windows x64、Steam《影之刃零》。
- 单独安装 [PBZ 专用 UE4SS v3.0.1-1183-gcdbc0b66](https://github.com/KintaroModding/ue4ss/releases/tag/v3.0.1-1183-gcdbc0b66)。**在发布页附件中选择 [`phantombladezero_ue4ss_v3.0.1-1183-gcdbc0b66.zip`](https://github.com/KintaroModding/ue4ss/releases/download/v3.0.1-1183-gcdbc0b66/phantombladezero_ue4ss_v3.0.1-1183-gcdbc0b66.zip)**（此链接可直接下载）。不要选择通用 `UE4SS_v...zip`、其他游戏的包或 GitHub 自动生成的 `Source code` 源码包。
- 视频播放需要 Windows Media Foundation；Windows N 可能需要安装媒体功能包。
- 另行下载兼容角色包。角色资源由作者另发夸克网盘，本仓库暂未公布夸克链接。

玩家**不需要**安装 UE 编辑器、Blender、Python、FFmpeg 或外部播放器。Core 包含共享界面、骨架兼容资源、Shader 和原皮头像，不包含自定义可玩角色、角色贴图/头像包、大招录屏或 UE4SS 加载器本体。

## 安装

1. 退出游戏，备份已有模组。
2. 下载上述文件名完全一致的 PBZ 专用 ZIP，将压缩包的**内容直接解压到 `PBZ/platform/steam`**，与较大的 `PBZ.exe` 同级；不要额外套一层以压缩包名称命名的文件夹。
3. 解压管理器安装包，将 **`GameFiles` 内的 `platform` 和 `ProjectPBZ`** 合并到 PBZ 游戏根目录，不要把外层 `GameFiles` 文件夹整个复制进去。
4. 按同样的相对目录安装角色包，再从 Steam 启动游戏并读档。

升级时保留自己的 `State`、`selected.txt` 和 `controls.json`。如果其他模组也修改了共享脚本，应先合并它们的适配。旧的直接覆盖主角包可能干扰原皮恢复。新增 cooked 模型资源后必须完整重启游戏；扫描只刷新清单，不能动态挂载新增容器。

## 操作

| 按键或按钮 | 功能 |
| --- | --- |
| F6 | 打开/关闭换装界面 |
| Esc | 关闭面板或中止视频 |
| 鼠标、方向键、Enter | 选择/应用角色，执行功能 |
| F5 | 开关角色包支持的三渲二材质，默认关闭 |
| 扫描按钮 / 面板内 F8 | 手动刷新缓存的角色列表 |
| 地球图标 | 切换中文/英文 |
| 充满大招能量 | 手动补满当前玩家的武技能量 |

新安装默认 **F6 面板 / F5 着色**。选择原皮后需要重载存档或重启，不会即时恢复原生布料和动画。

### 从旧版迁移按键

本包只提供 `controls.example.json`，不会覆盖你的 `controls.json`。已有配置继续优先，因此升级不会自动把原来的 F10、F11 或其他自定义键改成 F6。

退出游戏后，在 `platform/steam/ue4ss/Mods/PBZWardrobe/controls.json` **只将 `wardrobe_key` 改成 `"F6"`，保留自己的 `shader_key` 和其他字段**，然后重启。没有该文件时直接使用内置默认；需要自定义时复制示例为 `controls.json` 再修改。两个键必须不同，支持 F1–F12。

```json
{
  "schema": 1,
  "wardrobe_key": "F6",
  "shader_key": "F5"
}
```

上例仅适用于仍使用 F5 着色的配置，不要覆盖自己改过的着色键。F6 已在本轮干净安装中验证；其他 Mod 仍可能占用它。[冲突说明](docs/hotkey-compatibility.md)。本版不修改游戏的全屏开关、Alt+Enter、INI 或 UE4SS 控制台。

## 大招动画

把 `Ultimate.mp4` 放到对应角色 `model.json` 的同级目录：

```text
ProjectPBZ/Content/Paks/~mods/PBZWardrobeModels/<角色ID>/
  model.json
  Ultimate.mp4
```

每个角色的动画开关默认关闭。缺少视频时，点击按钮只会打开目录并生成导入说明 TXT，不会开启播放。导入后点击“检测并预览动画”。角色的可选“含大招动画版”可以直接把视频放在上述目录，管理器会自动识别。

推荐 H.264 视频 + AAC 音频，最长 60 秒、最大 512 MB。开启后，成功释放对应的 Q / 手柄 LT 武技会插播视频、暂停游戏世界，并在结束后恢复。能量不足时不应误播。请使用具有相应使用许可的素材。

## 兼容性与状态

本轮已完成 Steam 干净环境文件校验（695 个文件）、全新导入的 108 个文件 SHA256 核对，以及冷启动读档和 F6 面板实机确认。发行包的 60 个 GameFiles 与该实测安装逐文件一致；仅整理了说明与发行元数据。本轮没有重新遍历全部角色、战斗和过场，不扩大验收范围。[验证记录](docs/validation-2.4.5.md)。游戏更新可能需要适配，没有量化帧率保证；Vortex 部署尚未验证。

F5 是原创风格化着色实现，并非绝区零官方渲染器的完整复刻；实际能力和参数由角色清单决定。Core 适配成年魂主角，不是任意 PAK 转换器，也不是全游戏模组管理器。

## 源码、构建与安全

`Scripts/` 存放运行时 Lua；`source/` 存放音频/目录辅助模块 C++、Shader 与界面作者文件。[构建说明](docs/build.md) 区分可单独构建的 helper 和依赖游戏专用工具链的 cooked 资源。当前安装 ZIP 与本轮实测 F6 安装的游戏文件一致，附件提供 SHA256。旧 2.4.2 安装包已被此版替代，不再推荐使用。

辅助 DLL 未签名，用于本地视频音频、目录列举和用户主动请求的文件夹打开。公开源码及扫描结果不等于绝对安全。[安全与 AI 披露](docs/security-and-ai.md) 记录包体用途及历史 Nexus 源码包复核背景，不建议关闭系统防护安装。

## 署名与许可

《影之刃零》：**S-GAME**；UE4SS：**UE4SS-RE**；PBZ 加载器配置：**KintaroModding**；`json.lua`：**rxi**，保留 MIT 声明。详见[第三方说明](THIRD_PARTY_NOTICES.md)。

代码、界面、原创 Shader 和说明由 OpenAI Codex / ChatGPT 辅助制作，并经过用户反复实机测试。演示图是真实游戏截图。本仓库**公开源码供审查，尚未额外授予覆盖整个项目的开源许可**。第三方及游戏衍生资产保留各自权利；角色包与视频另附来源和授权说明。
