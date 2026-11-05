# PBZzzzSkinManager

[English](README.md) | [简体中文](README.zh-CN.md)

用于 Windows Steam《**影之刃零**》的游戏内角色与大招动画管理器。兼容角色通过清单接入，前置不限于席德、叶瞬光或其他指定角色。

**[下载管理器 2.4.2 预览版](https://github.com/Donmmn/PBZzzzSkinManager/releases/tag/v2.4.2-preview)** · [角色包接入说明](docs/character-packs.zh-CN.md) · [反馈问题](https://github.com/Donmmn/PBZzzzSkinManager/issues)

请下载发布附件里的 **PBZWardrobe-Core-2.4.2-preview.zip**。GitHub 自动生成的 **Source code** 压缩包只是源码，不能作为模组安装。

![真实游戏内管理器演示](https://github.com/Donmmn/PBZzzzSkinManager/releases/download/v2.4.2-preview/Core-overview.png)

*演示图由用户提供，为真实游戏截图；图中的角色需要单独下载。*

## 功能

- F10 换装面板：斜向循环列表、实时角色预览、界面独占输入和中英文切换。
- F5 开关兼容角色的三渲二材质，左下角显示实际着色方案及材质覆盖范围。
- 每个角色独立的大招动画开关、导入目录入口与“检测并预览”功能。
- 手动扫描角色目录；点击空槽打开角色模组文件夹。
- 可选的“充满大招能量”按钮，只在点击时补满当前玩家能量，不自动充能或释放技能。
- 切换回游戏原皮，在重载存档或重启后生效。

## 环境要求

- Windows x64、Steam《影之刃零》。
- 单独安装 [PBZ 专用 UE4SS v3.0.1-1183-gcdbc0b66](https://github.com/KintaroModding/ue4ss/releases/tag/v3.0.1-1183-gcdbc0b66)。
- 视频播放需要 Windows Media Foundation；Windows N 可能需要安装媒体功能包。
- 另行下载兼容角色包。角色资源由作者另发夸克网盘，本仓库暂未公布夸克链接。

玩家**不需要**安装 UE 编辑器、Blender、Python、FFmpeg 或外部播放器。Core 包含共享界面、骨架兼容资源、Shader 和原皮头像，不包含自定义可玩角色、角色贴图/头像包、大招录屏或 UE4SS 加载器本体。

## 安装

1. 退出游戏，备份已有模组。
2. 将上述 PBZ UE4SS 包解压到 `PBZ/platform/steam`，与较大的 `PBZ.exe` 放在一起。
3. 解压管理器安装包，将 **`GameFiles` 内的 `platform` 和 `ProjectPBZ`** 合并到 PBZ 游戏根目录，不要把外层 `GameFiles` 文件夹整个复制进去。
4. 按同样的相对目录安装角色包，再从 Steam 启动游戏并读档。

升级时保留自己的 `State`、`selected.txt` 和 `controls.json`。如果其他模组也修改了共享脚本，应先合并它们的适配。旧的直接覆盖主角包可能干扰原皮恢复。新增 cooked 模型资源后必须完整重启游戏；扫描只刷新清单，不能动态挂载新增容器。

## 操作

| 按键或按钮 | 功能 |
| --- | --- |
| F10 | 打开/关闭换装界面 |
| Esc | 关闭面板或中止视频 |
| 鼠标、方向键、Enter | 选择/应用角色，执行功能 |
| F5 | 开关角色包支持的三渲二材质，默认关闭 |
| 扫描按钮 / 面板内 F8 | 手动刷新缓存的角色列表 |
| 地球图标 | 切换中文/英文 |
| 充满大招能量 | 手动补满当前玩家的武技能量 |

按键冲突时，可以在 `controls.json` 中将 `wardrobe_key`、`shader_key` 改成其他 F1–F12 按键，然后重启游戏。选择原皮后需要重载存档或重启；不会即时在原地恢复原生布料和动画。

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

此版为 **preview 预览版**：用户已验收 Steam build **26367565** 下现有本机整合安装，但通用分发包的独立干净安装仍待验证。游戏更新可能需要重新适配。没有量化帧率保证；提供手动安装说明，Vortex 部署尚未验证。

F5 是原创风格化着色实现，并非绝区零官方渲染器的完整复刻；实际能力和参数由角色清单决定。Core 适配成年魂主角，不是任意 PAK 转换器，也不是全游戏模组管理器。

## 源码、构建与安全

`Scripts/` 存放运行时 Lua；`source/` 存放音频/目录辅助模块 C++、Shader 与界面作者文件。[构建说明](docs/build.md) 区分可单独构建的 helper 和依赖游戏专用工具链的 cooked 资源。发布 ZIP 保留之前审核的 2.4.2 原始字节，附件提供 SHA256。

辅助 DLL 未签名，用于本地视频音频、目录列举和用户主动请求的文件夹打开。公开源码及扫描结果不等于绝对安全。[安全与 AI 披露](docs/security-and-ai.md) 记录包体用途及 Nexus 源码包复核状态，不建议关闭系统防护安装。

## 署名与许可

《影之刃零》：**S-GAME**；UE4SS：**UE4SS-RE**；PBZ 加载器配置：**KintaroModding**；`json.lua`：**rxi**，保留 MIT 声明。详见[第三方说明](THIRD_PARTY_NOTICES.md)。

代码、界面、原创 Shader 和说明由 OpenAI Codex / ChatGPT 辅助制作，并经过用户反复实机测试。演示图是真实游戏截图。本仓库**公开源码供审查，尚未额外授予覆盖整个项目的开源许可**。第三方及游戏衍生资产保留各自权利；角色包与视频另附来源和授权说明。
