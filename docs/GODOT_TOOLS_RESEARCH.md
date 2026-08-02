# 开源 Godot 4 工具调研报告

> 生成日期:2026-08-02 ｜ 项目:星澜物语 / STELLARA(Godot 4.7.1,GDScript,原创 IP 3D RPG)
> 目的:为项目筛选可引入的开源开发工具。**本报告仅调研,未下载**——下载需你确认后执行。
> 红线:只引入 **MIT / Apache-2.0 / BSD / MPL / CC0 / 公共领域**;必须 **Godot 4.x** 兼容;排除付费、闭源、仅商店无源码、传染性许可证(GPL/LGPL/AGPL)、许可证未核实者。

---

## 调研原则与排除项

- **仅收录**:明确标注上述合规许可证 + Godot 4.x 兼容 + 维护活跃/可用。
- **已排除**(不符红线,详见文末):`godot-rpg-stats`(LGPLv3)、`stat-growth-rpg-system`(AGPL-3.0)、`a-magno/godot-turn-based-framework`(无 LICENSE)、`SimpleXTerrain`(许可证未核实/仓库 404)、`UT.Boom`(许可证待核)、所有 **C#/.NET 专属**方案(与本项目 GDScript 强冲突)。
- **引入规范**:下载后一律放入 `addons/`,并保留 `LICENSE` 副本与出处注释(README 顶部写明来源仓库与版本);第三方 demo 资源若含非原创素材须剔除。

---

## 一、地图与地形

| 工具 | 用途 | 许可证 | G4 兼容 | 推荐 | 集成风险 |
|---|---|---|---|---|---|
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | 高性能可雕刻 3D 地形(GDExtension) | MIT | 4.1+ | 高 | 需匹配 4.7.1 构建;移动端有特别说明 |
| [HTerrain](https://github.com/Zylann/godot_heightmap_plugin) | 高度图地形,纯 GDScript | MIT | 4.6+ | 高 | 作者声明仅修 bug、不再加功能 |
| [godot_voxel](https://github.com/Zylann/godot_voxel) | 体素/无限地形、可破坏 | MIT | 4.x | 高(方块/洞穴类) | 学习曲线陡 |
| [Better Terrain](https://github.com/cogwheelgames/better-terrain) | 替代内置 autotile 的多连接地形 | **公共领域** | 4.3 | 高 | 2024 后更新少 |
| [ProtonScatter](https://github.com/HungryProton/scatter) | 程序化散布道具/植被 | MIT | 4.1 | 高 | 演示纹理含 Textures.com 授权,需替换 |
| [TileMapDual](https://github.com/pablogila/TileMapDual) | 双网格自动拼接(47→15 块) | MIT | 4.5.x | 中高 | 需按其双网格规则设计图块 |
| [GDT Terrain Generator](https://github.com/daffadamara/GDTerrainGenerator) | 噪声分块地形+LOD+材质绘制 | MIT | 4.6 | 中高 | 较新,关注版本跟进 |

> 注:Godot 4 内置 **TileSet Terrain Sets**(peering)零许可风险,基础瓦片需求可先不引插件。

---

## 二、内容系统(对话 / 任务 / 存档 / 设置 / 本地化)

| 工具 | 用途 | 许可证 | G4 兼容 | 推荐 | 集成风险 |
|---|---|---|---|---|---|
| [Dialogic 2](https://github.com/dialogic-godot/dialogic) | 最全可视化对话/剧情系统 | MIT | 4.3+ | 高(体量大) | 自带存档逻辑,须与统一存档出口对齐 |
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | 脚本式轻量对话,无状态 runtime | MIT | 4.4/4.5 | 高(轻量首选) | 需自建"游戏状态"对接分支 |
| [Rakugo](https://github.com/rakugoteam/Rakugo-Dialogue-System) | 视觉小说式对话系统 | MIT | 4 主分支 | 中 | 生态新、文档少 |
| [Quest System](https://github.com/ShomyKohai/quest-system) | 模块化任务系统 + CSV/POT 本地化 | MIT | 4.4+ | 高 | 与存档/本地化需对接 |
| [Quest Manager](https://github.com/Rubonnek/quest-manager) | 信号丰富、自带序列化的任务管理 | MIT | 4.2.1+ | 高 | 同上,需统一存档出口 |
| [Addon Save](https://github.com/kimbunner/godot-save) | 加密/压缩/备份/自动存档 | MIT | 4.1+ | 高 | 建议作为**集中存档出口** |
| [Godot Game Settings](https://github.com/raff-a/godot-game-settings) | 显示/音频/输入预设统一管理 | MIT | 4.5 | 高 | 无运行时冲突 |
| [Localization Editor](https://github.com/EthanGrahn/godot-localization-editor) | CSV 管理 + 自动翻译 | MIT | 4 | 高 | 与原生 `@GlobalScope` 本地化体系规划对接 |

> 关键风险:Dialogic / Rakugo / Quest Manager 自带存档逻辑,务必统一到 **Addon Save** 单一出口,避免多份存档冲突。

---

## 三、角色与战斗(状态机 / AI / 数值 / 回合)

| 工具 | 用途 | 许可证 | G4 兼容 | 推荐 | 集成风险 |
|---|---|---|---|---|---|
| [gd-YAFSM](https://github.com/m4rr5/gd-YAFSM) | 流程图式可嵌套有限状态机 | MIT | 4.x 专属 | 高 | 纯 GDScript、即插即用,不接管项目 |
| [SignalStateMachine](https://github.com/MemeKing/SignalStateMachine) | 信号驱动极简 FSM(~40 行) | MIT | 4.5 | 高 | 最轻量、易嵌入 combat.gd |
| [Beehave](https://github.com/bitbrain/beehave) | 纯 GDScript 行为树 + 运行时调试视图 | MIT | 4.7 | 高 | 零原生依赖,最贴合 GDScript 项目 |
| [LimboAI](https://github.com/limbonaut/limboai) | BT+HSM + 可视化调试器 | MIT | 4.2+(GDExtension) | 高 | C++ 扩展,引入二进制依赖 |
| [FlowerStats](https://github.com/Abab-bk/FlowerStats) | Resource 数值 + Buff/Modifier 栈 | MIT | 4.2 | 中高 | 版本早(0.2),可作 combat.gd 数值层补充 |

> 建议:**AI 主选 Beehave**(轻、纯 GDScript);FSM 取 gd-YAFSM 或 SignalStateMachine;数值补 FlowerStats。**保留自研 `core/combat.gd` 为数值核心**,不引入整套战斗框架(回合制方案多为 C#,已排除)。

---

## 四、调试与基础设施(测试 / 编辑器增强 / 工具库 / 性能)

| 工具 | 用途 | 许可证 | G4 兼容 | 推荐 | 集成风险 |
|---|---|---|---|---|---|
| [GdUnit4](https://github.com/MikeSchulze/gdUnit4) | 编辑器内 GDScript 单元测试(Mock/SceneRunner/CI) | MIT | 4.2+ | 高 | 注入 `GdUnitRunner` autoload + 独立 `test/` 目录,与 `SmokeTest.gd` 不冲突 |
| [Gut](https://github.com/bitwes/Gut) | 官方资源库头部测试框架(双击/Mock/JUnit) | MIT | 4.x(9.x) | 高 | 以插件运行,与 `harness verify` 互补 |
| [Inspector Extender](https://godotengine.org/asset-library/asset/1632) | 用注释扩展 Inspector(按钮/警告/表格) | MIT | 4.0 | 高 | 纯编辑器插件,不注入游戏运行时 |
| [godot_debug_draw_3d](https://github.com/DmitriySalnikov/godot_debug_draw_3d) | GDExtension 3D/2D 调试绘制(盒/线/球/文本) | MIT | 4.x | 高 | 导出默认 dummy 库零开销,headless 兼容 |
| [godot-debug-menu](https://github.com/HugoLocurcio/godot-debug-menu) | 游戏内 FPS/CPU/GPU 监控叠层(F3 切换) | MIT | 4.x | 高 | 仅运行时节点,不干扰测试 |
| [Debug API](https://godotengine.org/asset-library/asset/5131) | 50+ 内置监视器/声明式面板,headless 安全 | MIT | 4.0+ | 高 | 支持手动 autoload 模式避免污染 |
| [lebriton.godot_utils](https://github.com/lebriton/godot_utils) | GDScript 工具集(数组/向量/节点/几何) | MIT | 4.x | 中 | 作者声明不再主动维护 |

> 测试框架 **Gut 与 GdUnit4 二选一**即可,避免两套体系并行。二者均用独立 `test/` 目录,与现有 `test/SmokeTest.gd` + `harness verify` 验收闸门不冲突。

---

## 综合推荐优先级(供下载决策)

### 🟢 强烈推荐(下载首选,增益大 + 风险低)
1. **Beehave** — 纯 GDScript 行为树,驱动敌人/伙伴 AI,零原生依赖
2. **gd-YAFSM** 或 **SignalStateMachine** — 轻量状态机,嵌入现有战斗/角色逻辑
3. **Addon Save** — 统一存档出口,消除多插件存档冲突隐患
4. **Dialogue Manager** — 轻量对话,比 Dialogic 更易与自研状态对接
5. **Inspector Extender** — 纯编辑器增强,零运行时风险
6. **godot_debug_draw_3d** — 调试可视化,headless 安全
7. **Gut**(或 GdUnit4 二选一)— 补全单元测试体系

### 🟡 按需引入(特定需求时再下)
- **Terrain3D / HTerrain** — 若需地形雕刻(当前世界由代码构建,可暂缓)
- **ProtonScatter** — 植被/道具散布(注意替换演示纹理)
- **Better Terrain** — 瓦片自动拼接(公共领域最省心)
- **Godot Game Settings** — 设置面板统一管理
- **Localization Editor** — 多语言 CSV 管理
- **Quest System / Quest Manager** — 任务系统(需对接存档/本地化)

### 🟠 谨慎评估(有依赖/版本/维护顾虑)
- **LimboAI** — 功能强但有 C++ 扩展二进制依赖
- **godot_voxel** — 体素地形学习曲线陡
- **FlowerStats** — 版本早(0.2)
- **GdUnit4 vs Gut** — 二选一,勿并行

---

## 排除清单(不符红线,不得引入)

| 工具 | 原因 |
|---|---|
| `godot-rpg-stats` | LGPLv3(传染性,违反项目红线) |
| `stat-growth-rpg-system` | AGPL-3.0(传染性,违反项目红线) |
| `a-magno/godot-turn-based-framework` | 无 LICENSE 文件(默认保留权利) |
| `SimpleXTerrain` | 许可证未核实(仓库 404) |
| `UT.Boom` | 许可证待核,需自建验证 |
| 所有 C#/.NET 方案(TurnBasedSystem-CS、godot-tbs-framework、BZ Settings、CSharpGodotTools 等) | 与本项目 GDScript 强冲突 |

---

## 下一步

确认后我将:
1. 按你勾选的清单,逐一下载到 `addons/<tool>/`,保留 `LICENSE` 与出处注释;
2. 对 GDExtension 类(Terrain3D/LimboAI/debug_draw_3d)确认 4.7.1 构建可用;
3. 跑 `python harness/harness.py verify` 确保引入后编译 + 冒烟仍 PASS;
4. 提交并直连 SSH 推送。
