# 星澜地区 (Stellara) — 原创 IP 宝可梦-like 3D 对战 RPG

> 一款开放世界 3D 宝可梦-like 游戏：朱紫式自由探索 + Z-A 式实时动作战斗 + 收服养成。
> **原创 IP**，不使用任何任天堂/Game Freak 版权素材。

- 引擎: **Godot 4.7** (Forward Plus, Jolt 物理)
- 平台: v1 Windows 单机
- 状态: **P1 MVP 开发中**

---

## 快速开始

1. 用 Godot 4.7 打开本目录（`project.godot`）。
2. 在「项目设置 → 插件」中启用已下载的 addons（见下）。
3. 按 **F5** 运行。玩家可在测试场地行走；按 `B` 进入实时战斗原型。

## 目录结构

```
addons/   开源插件
autoload/ 全局单例 (GameState/DataBus/DayNight/SaveManager)
core/     数据层 (Creature/Move/TypeChart/数值)
world/    探索 (PlayerController/CameraRig/Terrain)
battle/   实时战斗 (Arena/Combatant/MoveExecutor/BattleFSM)
ui/       HUD/菜单/对话/队伍背包
data/     JSON 数据 (creatures/moves/type_chart/items)
tests/    GDUnit4 单元测试
docs/     需求(REQUIREMENTS)/规划(TASKS)/日志(DEVLOG)/规范(STANDARDS)
harness/  harness.py 任务与日志管理
```

## 开发框架 (harness)

所有任务与进度由 `harness/harness.py` 管理：

```bash
python harness/harness.py init        # 首次初始化任务库
python harness/harness.py plan        # 查看阶段路线图
python harness/harness.py task list   # 列出任务
python harness/harness.py task set T006 status in_progress
python harness/harness.py devlog add "完成玩家控制器"
python harness/harness.py report      # 完成度报告
```

## 已引入的开源工具

| 工具 | 用途 | 许可证 |
|------|------|--------|
| GDUnit4 | 单元测试 | MIT |
| LimboAI | AI / 状态机 | MIT |
| Terrain3D | 3D 地形 | MIT |
| phantom-camera | 跟随相机 | MIT |
| godot_dialogue_manager | 对话 | MIT |
| PankuConsole | 调试控制台 | MIT |
| scatter | 场景布景 | MIT |
| godot_datatable_plugin | 数据表 | MIT |

> 详阅 `docs/REQUIREMENTS.md`（设计）与 `docs/STANDARDS.md`（规范）。

## 版权

本项目为原创 IP。机制借鉴宝可梦系列，但所有名称、形象、音频均为原创或 CC0 重制，不含任何受版权保护素材。
