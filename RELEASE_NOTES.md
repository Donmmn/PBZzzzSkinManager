# 2.4.5 — F6 wardrobe default

## English

- F6 opens the wardrobe by default; F5 shading, Esc close/cancel and in-panel F8 scanning remain available.
- Existing controls.json is preserved. To migrate F10/F11/custom bindings to F6, close the game and edit only wardrobe_key to "F6", keep shader_key, then restart. New installs without controls.json use F6/F5; controls.example.json is a template.
- The footer reflects actual configured key names in Chinese and English.
- No fullscreen flag, Alt+Enter, INI, ConsoleKeys or UE4SS built-in mod is changed. The experimental F11 compatibility module is not included.
- Clean Steam environment verification covered 695 files; 108 freshly imported files passed SHA256 checks. Cold load and F6 panel operation were confirmed. The final package preserves all 60 tested Core GameFiles. A full gameplay regression was not repeated this round.

Install **PBZWardrobe-Core-2.4.5-F6.zip**. Source Review and GitHub's automatic Source code downloads are for development/review, not installation. Character packs/videos and the UE4SS loader are separate. This supersedes the withdrawn 2.4.2 Core installer. Native helper remains unsigned; no safety or FPS guarantee is claimed. Check SHA256SUMS.txt.

## 简体中文

- 默认F6打开面板；F5着色、Esc关闭/中止、面板内F8扫描保持不变。
- 保留已有controls.json。旧F10/F11/自定义键升级不会被静默覆盖；退出游戏后仅把wardrobe_key改为"F6"，保留shader_key，再重启。没有配置时使用F6/F5内置默认，controls.example.json仅为模板。
- 中英文底部提示同步显示实际配置键名。
- 不修改全屏开关、Alt+Enter、INI、ConsoleKeys或UE4SS内置Mod，不包含试验性F11兼容模块。
- Steam干净环境校验695文件，全新导入108文件通过SHA256核对，冷启动读档和F6面板已确认。最终包60个Core游戏文件与实测一致；本轮未重复完整游戏回归。

安装请下载 **PBZWardrobe-Core-2.4.5-F6.zip**。Source Review及GitHub自动生成的Source code只供开发审查，不是安装包。角色、视频和UE4SS加载器另行下载。本版替代已撤回的2.4.2 Core安装包。原生helper仍未签名，不作绝对安全或帧率保证，校验值见SHA256SUMS.txt。
