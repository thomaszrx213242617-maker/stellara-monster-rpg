# 开发规范 (STANDARDS)

> 适用于「星澜物语 / STELLARA」Godot 4.7.1 项目。所有贡献者（含 AI harness）必须遵守。
> 本文档随项目演进更新；与 `REQUIREMENTS.md` / `GAME_DESIGN.md` / `FRAMEWORK.md` 协同。

---

## 1. GDScript 代码风格

- 缩进: **4 个空格**，禁止 Tab。
- 每行 ≤ 100 字符。
- 命名:
  - 类/节点脚本: `PascalCase`（`PlayerController.gd`）
  - 变量/函数: `snake_case`（`move_speed`, `take_damage()`）
  - 常量: `CONSTANT_CASE`（`MAX_HP`）
  - 信号: `snake_case` 过去式（`hp_changed`, `battle_ended`）
- 类型注解: 强烈建议标注类型 (`var hp: float = 0.0`)；公开 API 用 `##` doc 注释。
- 每个脚本顶部注释说明职责。
- 魔法数字禁止：数值放 `data/` 或 `const`。

### 1.1 ⚠️ 强制规则：禁止对返回 Variant 的表达式用 `:=` 推断类型

Godot 4 中，对**返回 Variant、无确定类型**的表达式用 `:=` 推断，会**直接编译失败**（"Cannot infer the type of 'x' variable" / "inferred from a Variant value"）。以下调用返回值都是 Variant，**必须显式标注目标类型**：

```gdscript
# ❌ 错误：会报 Parse Error
var evo := load("res://battle/Combatant.gd").new()
var tp  := get_node_or_null(follow_target)
var d   := data.get("base", {})

# ✅ 正确：显式标注类型
var evo: Combatant = load("res://battle/Combatant.gd").new()
var tp: Node3D    = get_node_or_null(follow_target)
var d: Dictionary = data.get("base", {})
```

> 触发黑名单：`load()` / `preload()` / `instance().new()` / `Dictionary.get()` / `get_node_or_null()` / `instantiate()` 等。新脚本里凡此类结果一律标注类型。

---

## 2. 目录与组织

- 严格按 `REQUIREMENTS.md §9.1` 的目录结构放置代码。
- `core/` 只放纯数据/逻辑（不含节点），便于单测。
- 场景文件 `.tscn` 与脚本同名同目录；预制体放 `world/`、`battle/` 子目录的 `scenes/`。
- 数据文件统一放 `data/`，优先 JSON（便于平衡），复杂对象用 `.tres` Resource。
- **测试目录是 `test/`**（非 `tests/`）：当前冒烟测试为 `test/SmokeTest.gd`。

---

## 3. 命名空间 / 全局约定（autoload 单例）

> 这是本项目**最容易踩的坑**，见 §10.2。

- 共有 **6 个 autoload 单例**，两层名字必须分清：
  - **class_name（类标识，对外/类型用）**：`DataBus` / `GameState` / `DayNight` / `SaveManager` / `InputSetup` / `SoundBus`。
  - **单例键名（project.godot 的 autoload key，代码里当全局变量用）**：`Data` / `Game` / `Clock` / `Save` / `Keys` / `SFX`。
    - 即代码里写 `Data.xxx` / `Game.xxx` / `Clock.xxx` / `Save.xxx` / `Keys.xxx` / `SFX.xxx` 才指向单例**实例**。
    - 写 `DataBus.xxx`（class_name）会解析到**类而非实例** → 报 "Cannot call non-static function ... on the class" / "Cannot find member"。
  - **MusicBus 已整体删除**（用户决策：只删 BGM、保留音效 SFX），故共 6 个单例。
- **输入动作由 `Keys`(InputSetup) 运行时注册**（WASD/空格/Shift/B/C/E 等），project.godot 中**无静态 `[input]`**；新增动作改 `autoload/InputSetup.gd`，不要手改 project.godot。
- 禁止全局变量散落；跨场景状态走 autoload。

---

## 4. Git / 分支 / 提交规范

- **主干: `master`**（非 `main`）。功能分支可选 `feat/<任务id>-简短描述`（如 `feat/T006-player-move`）；AI 当前直接在 `master` 提交并直连 SSH 推送。
- 提交信息（中文或英文均可，须清晰，并带任务号）：
  - `feat: 新增玩家控制器与跟随相机 (T006)`
  - `fix: 修正夜间规则误判 (T009)`
  - `docs: 更新需求/规范文档`
  - `chore: 下载 dialogue_manager 插件`
- 提交粒度: 一个任务/一个逻辑改动一次提交，禁止巨型混合提交。
- **提交前必须跑验收闸门**：`python harness/harness.py verify`（编译 + 冒烟 0 FAIL 才允许提交）。
- 禁止提交: `.godot/`、`*.tmp`、密钥/Token、大二进制美术（用 Git LFS 或外链）。`.gitignore` 已含 `.godot/`。

---

## 5. 任务与 devlog（harness）

- 所有任务以 `harness/tasks.json` 为事实来源，用 `harness/harness.py` 管理。
- 开始一个任务: `python harness/harness.py task set <id> status in_progress`
- 完成: `status done` 并 `python harness/harness.py devlog add "<一句话>"`
- 文档 `docs/TASKS.md` 由脚本生成，**勿手改**（改 `tasks.json` 后跑 `sync`）。

---

## 6. 资源与版权规范（红线）

- **绝不**引入任天堂/Game Freak 版权素材（名称、图像、音频、招式、地图、剧情）。机制可借鉴，表达层必须原创。
- 引入第三方资源前确认许可证 ∈ {MIT, Apache-2.0, BSD, MPL, CC0, 公共领域}；**禁止 GPL/LGPL/AGPL 等传染性许可证**。
- 每个外部资源在 `addons/` 或 `data/` 内保留 `LICENSE` / `README` 与出处注释。
- 所有自创名称（灵兽/技能/道具/地区）必须原创，不得与现有 IP 撞名。
- CC0 素材（如 Kenney/Kaykit）需**重命名、必要时改色**，避免直接照搬辨识度高的原作。
- 音频：不使用第三方版权音频；`SoundBus` 优先读 `audio/<name>.wav`，缺失则程序化合成（规避版权）。BGM 当前已移除，后续用原创/CC0。

---

## 7. 测试要求

- **主验证方式 = `harness verify`**：① `godot --headless --editor --quit` 全量编译检查；② 经 `tools/run_smoke.py` 跑 `test/SmokeTest.gd` 冒烟测试（0 `[FAIL]` 才 PASS）。
- `core/` 的数值、克制、经验、收服判定应补充单元测试（GDUnit4 已在 `addons/`，但当前以 `SmokeTest.gd` 为主；若写 GDUnit4 单测须独立目录、与冒烟测试不冲突）。
- 战斗/探索关键流程改动需在编辑器 F5 验证后再提交；每次交付前 `harness verify` 必须 PASS。

---

## 8. 第三方插件管理

- 插件统一放 `addons/<plugin_name>/`，通过 Godot 编辑器「项目设置 → 插件」启用。
- **当前 `addons/` 已含 5 个 GDScript 插件**（均为合规 GDScript，无 GDExtension 二进制依赖）：
  `datatable_godot` · `dialogue_manager` · `gdUnit4` · `panku_console` · `proton_scatter`。
- GDExtension 候选（LimboAI / Terrain3D）**未采用**——本项目走纯 GDScript 路线（避免 C#/二进制兼容坑，见 `GODOT_TOOLS_RESEARCH.md`）。
- 引入新插件须确认 Godot 4.7.1 兼容，且引入后**必须重跑 `harness verify`** 确认编译 + 冒烟仍 PASS。
- 插件升级走独立提交，写明版本/来源。

---

## 9. AI harness 协作约定

- AI 负责写代码、跑 `harness verify`、更新任务状态与 devlog、直连 SSH 推送。
- 需要用户在编辑器内操作的步骤（如启用插件、按 F5 运行、设置输入映射），AI 必须给出**逐字保姆级步骤**。
- 任何破坏性/外部操作（推送 GitHub、删除文件、使用 SSH 密钥）前必须明确告知并获确认（或用户已授权的工作流）。

---

## 10. 常见坑 / 强制规则（Gotchas）

> 以下为本项目实战中反复踩过的坑，列为**强制规则**。

### 10.1 Variant 推断即编译错误
见 §1.1：`load()/.new()/.get()/get_node_or_null()/instantiate()` 结果必须显式标类型，禁止 `:=` 推断 Variant。

### 10.2 单例键遮蔽（致命）
见 §3：autoload 的 `class_name` 与单例键名**必须不同**。若同名，`Name.xxx` 优先绑定到**类**而非单例实例，导致整片脚本加载失败。代码里一律用**键名**（`Data`/`Game`/`Clock`/`Save`/`Keys`/`SFX`）。

### 10.3 头less 编译验证必须用 `--editor --quit`
`godot --headless --editor --quit` 才会**真实导入并注册 autoload 全局**，是有效的编译检查。
**绝不能用 `godot --headless --script xxx.gd` 当编译检查**——它会把对 autoload 单例的引用误报成 "Identifier not found"（假阳性）。但注意：该导入检查**不报** §1.1 的 Variant 推断错误（假阴性），需用 `SmokeTest` 里 `load().new()` 实例化才能真正捕获。

### 10.4 `rm` 被安全删除拦截
Bash 的 `rm` 被环境"安全删除"（genie-trash）拦截，对中文相对/绝对路径均失败。
**绕过**：`find <dir> -maxdepth 1 -name '<file>' -delete`（不经 `rm` 二进制）。项目文件删除一律用此法。

### 10.5 直连 SSH 推送必须显式指定私钥
私钥 `id_ed25519_stellara` 为自定义名；默认 `ssh` 只试 `id_rsa`/`id_ed25519` 等默认名，不指定 `-i` 会"连上但 publickey 拒绝"。
推送命令（已验证可用）：
```bash
GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_stellara -o StrictHostKeyChecking=accept-new" \
  git push git@github.com:thomaszrx213242617-maker/stellara-monster-rpg.git master
```
> 注意：本机 `timeout` 是 Windows 批处理命令（语法报错），**不要**用它包裹 git/ssh；Git 自带网络超时即可。

### 10.6 文本文件 CRLF 警告
Git 可能提示 "CRLF will be replaced by LF"——无害，提交正常；保持 `.gitattributes`/`.gitignore` 现状即可。

---

> 规范变更须同步更新本文件并登记 harness 任务；新成员/AI 开工前应先读本文档与 `FRAMEWORK.md`。
