# 角色包接入

[English](character-packs.md)

结合 `schema/model.schema.json`、`schema/contract.json` 与实际 `Scripts/profile_config.lua` 校验。示例清单包含占位路径，**不是可用角色包**。

```text
GameFiles/ProjectPBZ/Content/Paks/~mods/PBZWardrobeModels/<id>/
  model.json
  Textures/<材质标识>.png
  Packages/<资源>.pak
  Packages/<资源>.utoc
  Packages/<资源>.ucas
  Ultimate.mp4                    # 可选
```

小写 ASCII id 必须与目录同名。角色需提供兼容 PBZ 的骨架网格、后处理动画蓝图、次级物理资产和贴图，不能直接读取普通 MMD 文件。材质槽索引从 0 开始，需显式声明脸、头发和眼睛分区。通过 paint.enabled、父材质、表面类型与标量参数声明 Shader 能力，不按角色名硬编码。

Core 附带 v4/v5 母材质，v5 的表面类型 4 用于皮肤。主受击物理仅在骨骼挂点和物理资产确实匹配时启用，否则会影响正常受伤。保留 pak/utoc/ucas 三件套，新增容器后重启游戏。

夸克包沿用同一 GameFiles 目录，另附中英文说明、来源和许可、角色版本/最低 Core 版本及 SHA256SUMS.txt。可选且已获许可的 Ultimate.mp4 与 model.json 同级，不放进管理器包。管理器不自动联网下载。

至少验证冷启动读档、往返切换、F5、受击扣血、握持、走跑、次级物理、传送、真实过场与卸载。清单通过不代表游戏兼容。保留其他工程的适配，仅替换本角色包自己的文件。
