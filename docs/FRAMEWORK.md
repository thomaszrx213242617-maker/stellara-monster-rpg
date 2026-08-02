# 开发框架 (FRAMEWORK)

> 本文档是《星澜物语 / STELLARA》开发流程的总览。它把 `harness/` 下的脚本与 `docs/` 下的文档串成一个可重复的「下发任务 → 执行 → 验收 → 推送」闭环。
> 任务事实来源始终是 `harness/tasks.json`；`docs/TASKS.md` 由脚本自动生成，**不要手改**。

---

## 1. 目录布局

```
harness/
  harness.py      任务与日志管理脚本(唯一事实来源: tasks.json)
  tasks.json      全部任务(状态/阶段/优先级/依赖/进度)  ← single source of truth
tools/
  run_smoke.py    冒烟测试看门狗(子进程 120s 硬杀, 绕过 Windows timeout 失效)
docs/
  REQUIREMENTS.md  设计/需求(世界观、核心循环、系统拆解)
  TASKS.md         任务规划(由 harness.py 从 tasks.json 生成, 勿手改)
  DEVLOG.md        开发日志(由 harness.py devlog add 追加)
  STANDARDS.md     开发规范(GDScript 风格/目录/命名/提交/版权红线)
  GITHUB_GUIDE.md  GitHub 推送指南(SSH 直连 / 凭据 / 代理)
  BUILD.md         Windows 构建导出步骤
  PUSH_READY.md    推送前就绪检查清单
  FRAMEWORK.md     本文档(框架总览与工作流)
README.md          仓库首页, 含玩法/目录/快速开始
```

---

## 2. 脚本命令速查

所有命令在仓库根目录运行（Python 3.10+）：

```bash
# 任务管理
python harness/harness.py init              # 首次初始化 tasks.json(含完整路线图)
python harness/harness.py plan              # 按阶段打印路线图
python harness/harness.py task list         # 列出全部任务
python harness/harness.py task show T013    # 查看单个任务详情(JSON)
python harness/harness.py task add "<标题>" --phase "P1 MVP 垂直切片" --prio high --desc "..."
python harness/harness.py task set T013 status in_progress   # todo|in_progress|done|blocked|deferred
python harness/harness.py task set T013 note "进度说明"
python harness/harness.py devlog add "完成玩家控制器"

# 报告与文档
python harness/harness.py report            # 阶段完成度报告(总数/完成/进行中)
python harness/harness.py sync              # 重新生成 docs/TASKS.md 与 DEVLOG.md

# 验收门槛(关键)
python harness/harness.py verify            # 编译检查 + 冒烟测试, 0 FAIL 才 PASS
```

> `verify` 是验收闸门：先跑 `godot --headless --editor --quit` 做全量编译检查，再经 `tools/run_smoke.py` 跑冒烟测试。两者皆通过（无 `SCRIPT ERROR` / `Parse Error`、冒烟 0 `[FAIL]`）才输出 `PASS ✅`，否则 `FAIL ❌` 并以非 0 退出。Godot 路径可用环境变量 `GODOT_BIN` 覆盖，缺省回退到本项目桌面二进制。

---

## 3. 标准开发工作流

```
┌─────────────┐   批量任务清单   ┌──────────┐   执行 + 改代码   ┌──────────┐
│  用户(你)   │ ──────────────► │   AI 助手 │ ───────────────► │  Godot 代码 │
└─────────────┘                 └──────────┘                  └──────────┘
      ▲                              │  ▲                          │
      │   验收: 逐项核对完成度        │  └──── harness verify ──────┘
      │   (report / 冒烟 0 FAIL)      ▼
      │                        ┌──────────┐
      └──────── 确认 PASS ─────│ commit + │──── 直连 SSH 推送 master ──► GitHub
                               │  push    │
                               └──────────┘
```

1. **下发**：你以批量任务清单（截图/文字）下发需求；AI 把任务登记进 `tasks.json`（`task add`）并把对应项置 `in_progress`。
2. **执行**：AI 修改 Godot 脚本/场景/数据，过程中用 `devlog add` 记录关键节点。
3. **验收**：AI 跑 `harness verify` 作为客观完成度闸门——编译零错误 + 冒烟 0 FAIL。若 `FAIL`，回到执行修复。
4. **收口**：你确认验收通过后，AI 把任务置 `done`、`git commit` 并直连 SSH 推送 `master`，最后 `report` 复核进度。

> 版权红线（见 `STANDARDS.md` / `REQUIREMENTS.md`）：原创 IP，绝不引入任天堂/Game Freak 版权素材；机制可借鉴，表达层必须原创或 CC0 重制。

---

## 4. 文档角色对照

| 文档 | 角色 | 维护方式 |
|------|------|----------|
| `REQUIREMENTS.md` | 设计/需求，定义"做什么" | 手改 |
| `TASKS.md` | 任务规划，定义"做哪些、做到哪" | **脚本生成，勿手改** |
| `DEVLOG.md` | 开发日志，记录"怎么做/进展" | `devlog add` 追加 |
| `STANDARDS.md` | 编码/提交/版权规范 | 手改 |
| `GITHUB_GUIDE.md` | 推送与凭据流程 | 手改 |
| `BUILD.md` | 导出 Windows 构建 | 手改 |
| `PUSH_READY.md` | 推送前检查清单 | 手改 |
| `FRAMEWORK.md` | 本框架总览与工作流 | 手改 |
