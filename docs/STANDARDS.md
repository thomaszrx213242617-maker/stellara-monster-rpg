# 开发规范 (STANDARDS)

> 适用于「宝可梦-like」Godot 4.7 项目。所有贡献者（含 AI harness）必须遵守。

---

## 1. GDScript 代码风格

- 缩进: **4 个空格**，禁止 Tab。
- 每行 ≤ 100 字符。
- 命名:
  - 类/节点脚本: `PascalCase`（`PlayerController.gd`）
  - 变量/函数: `snake_case`（`move_speed`, `take_damage()`）
  - 常量: `CONSTANT_CASE`（`MAX_HP`）
  - 信号: `snake_case` 过去式（`hp_changed`, `battle_ended`）
- 类型注解: 开启 `strict` 模式，变量/函数尽量标注类型 (`var hp: float = 0.0`)。
- 每个脚本顶部注释说明职责；公开 API 用 `##` doc 注释。
- 魔法数字禁止：数值放 `data/` 或 `const`。

## 2. 目录与组织

- 严格按 `REQUIREMENTS.md §9.1` 的目录结构放置代码。
- `core/` 只放纯数据/逻辑（不含节点），便于 GDUnit4 单测。
- 场景文件 `.tscn` 与脚本同名同目录；预制体放 `world/`、`battle/` 子目录的 `scenes/`。
- 数据文件统一放 `data/`，优先 JSON（便于平衡），复杂对象用 `.tres` Resource。

## 3. 命名空间 / 全局约定

- autoload 单例名: `GameState`, `DataBus`, `DayNight`, `SaveManager`（见 project.godot）。
- 信号连接优先用 `@onready` + `connect`，或在编辑器内连。
- 禁止全局变量散落；跨场景状态走 autoload。

## 4. Git / 分支 / 提交规范

- 主干: `main`。功能分支: `feat/<任务id>-简短描述`（如 `feat/T006-player-move`）。
- 提交信息（中文或英文均可，须清晰）:
  - `feat: 新增玩家控制器与跟随相机 (T006)`
  - `fix: 修正夜间规则误判 (T009)`
  - `docs: 更新需求文档`
  - `chore: 下载 LimboAI 插件`
- 提交粒度: 一个任务/一个逻辑改动一次提交，禁止巨型混合提交。
- 提交前: 跑 `python harness/harness.py report` 确认任务状态已更新。
- 禁止提交: `.godot/`、`*.tmp`、密钥/Token、大二进制美术（用 Git LFS 或外链）。`.gitignore` 已含 `.godot/`。

## 5. 任务与 devlog（harness）

- 所有任务以 `harness/tasks.json` 为事实来源，用 `harness/harness.py` 管理。
- 开始一个任务: `python harness/harness.py task set <id> status in_progress`
- 完成: `status done` 并 `python harness/harness.py devlog add "<一句话>"`
- 文档 `docs/TASKS.md` 由脚本生成，**勿手改**。

## 6. 资源与版权规范（红线）

- **绝不**引入任天堂/Game Freak 版权素材（名称、图像、音频、招式、地图）。
- 引入第三方资源前确认许可证 ∈ {MIT, Apache-2.0, BSD, CC0, 公共领域}。
- 每个外部资源在 `addons/` 或 `data/` 内保留 `LICENSE` / `README` 与出处注释。
- 所有自创名称（灵兽/技能/道具/地区）必须原创，不得与现有 IP 撞名。
- CC0 素材（如 Kenney/Kaykit）需**重命名、必要时改色**，避免直接照搬辨识度高的原作。

## 7. 测试要求

- `core/` 的数值、克制、经验、收服判定必须有 GDUnit4 单测（`tests/`）。
- 战斗/探索关键流程改动需手动在编辑器 F5 验证后再提交。
- 性能：场景节点数、draw call 在 P7 前不强制，但避免明显泄漏。

## 8. 第三方插件管理

- 插件统一放 `addons/<plugin_name>/`，通过 Godot 编辑器「项目设置 → 插件」启用。
- GDExtension 类插件（LimboAI/Terrain3D/GDUnit4）需与 Godot 4.7 兼容；若启用报错，记录到 devlog 并按插件文档处理（通常需对应版本的预编译二进制）。
- 插件升级走独立提交，写明版本/来源。

## 9. AI harness 协作约定

- AI 负责写代码、跑 harness、更新任务状态与 devlog。
- 需要用户在编辑器内操作的步骤（如启用插件、按 F5 运行、设置输入映射），AI 必须给出**逐字保姆级步骤**。
- 任何破坏性/外部操作（推送 GitHub、删除文件）前必须明确告知并获确认。
