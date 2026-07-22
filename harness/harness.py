#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
harness.py —— 宝可梦-like 游戏 开发框架控制脚本

作用:
  把开发循环流水线化。所有任务以 tasks.json 为唯一事实来源 (single source of truth),
  本脚本负责: 查看/新增/更新任务、生成 docs/TASKS.md 规划文档、向 docs/DEVLOG.md 追加日志。

用法 (在仓库根目录或 harness/ 下运行):
  python harness/harness.py init                # 首次初始化 tasks.json (含完整路线图)
  python harness/harness.py task list           # 列出全部任务
  python harness/harness.py task show <id>      # 查看单个任务详情
  python harness/harness.py task add "<标题>" --phase "P1" --prio high --desc "..."
  python harness/harness.py task set <id> status <todo|in_progress|done|blocked|deferred>
  python harness/harness.py task set <id> note "<进度说明>"
  python harness/harness.py devlog add "<一句话进展>"
  python harness/harness.py report              # 输出阶段完成度报告
  python harness/harness.py plan                # 输出按阶段的路线图

约定:
  - 状态: todo -> in_progress -> done | blocked | deferred
  - 任务 id 形如 T001, T002 ... 自动递增
  - docs/TASKS.md 由本脚本从 tasks.json 生成, 不要手改 (改 tasks.json 后重跑即可)
  - docs/DEVLOG.md 由 devlog add 追加, 可手改补充
"""
import json
import sys
import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HARNESS = Path(__file__).resolve().parent
TASKS_JSON = HARNESS / "tasks.json"
TASKS_MD = ROOT / "docs" / "TASKS.md"
DEVLOG_MD = ROOT / "docs" / "DEVLOG.md"
REQ_MD = ROOT / "docs" / "REQUIREMENTS.md"

STATUS_ORDER = ["todo", "in_progress", "blocked", "deferred", "done"]
STATUS_ICON = {
    "todo": "[ ]",
    "in_progress": "[~]",
    "blocked": "[!]",
    "deferred": "[-]",
    "done": "[x]",
}

# ---------------------------------------------------------------------------
# 种子路线图: 首次 init 时写入 tasks.json。按阶段组织, 这是整个项目的骨架。
# ---------------------------------------------------------------------------
SEED_TASKS = [
    # ---- P0 基础框架与工具 ----
    dict(phase="P0 基础框架与工具", title="搭建 harness 开发框架", desc="建立 docs/ 四件套(需求/task/devlog/规范)与 harness.py 任务管理脚本。", prio="high", deps=""),
    dict(phase="P0 基础框架与工具", title="编写开发需求文档(游戏设计)", desc="原创IP世界观、核心循环、3D探索、Z-A式实时战斗、属性克制、收服养成、道馆、昼夜规则。", prio="high", deps="T001"),
    dict(phase="P0 基础框架与工具", title="编写 task 规划与开发规范", desc="分阶段路线图 + GDScript 风格/目录/命名/分支提交/版权规范。", prio="high", deps="T001"),
    dict(phase="P0 基础框架与工具", title="下载开源 Godot 工具", desc="GDUnit4/LimboAI/Terrain3D/phantom-camera/godot_dialogue_manager/PankuConsole/scatter/datatable 等。", prio="high", deps=""),
    dict(phase="P0 基础框架与工具", title="初始化 git 与 GitHub 仓库", desc="git init、完善 .gitignore、引导用户建 GitHub 仓库并首次提交。", prio="high", deps="T004"),

    # ---- P1 MVP 垂直切片 ----
    dict(phase="P1 MVP 垂直切片", title="3D 探索移动与跟随相机", desc="CharacterBody3D 玩家控制器、phantom-camera 第三人称跟随、输入映射、小测试场地。", prio="high", deps="T004"),
    dict(phase="P1 MVP 垂直切片", title="属性/数值/技能数据层", desc="原创宝可梦/技能/属性克制表 Resource 与 JSON 数据; 种族值、威力、PP、命中、克制倍率。", prio="high", deps="T002"),
    dict(phase="P1 MVP 垂直切片", title="实时战斗原型(Z-A式)", desc="竞技场场景、玩家操控宝可梦实时移动+闪避、卡时机放招、属性克制与数值生效、LimboAI 对手。", prio="high", deps="T007,T008"),
    dict(phase="P1 MVP 垂直切片", title="昼夜循环与夜间规则", desc="昼夜循环(光照/天空)、'夜间不可对战收集点数'规则与提示。", prio="medium", deps="T007"),

    # ---- P2 探索世界 ----
    dict(phase="P2 探索世界", title="真实地形与开放区域", desc="Terrain3D 接入、可行走大地图、碰撞、区域边界。", prio="medium", deps="T006"),
    dict(phase="P2 探索世界", title="NPC 与对话系统", desc="godot_dialogue_manager 接入、道馆门口/宝可梦中心/NPC 对话。", prio="medium", deps="T006"),
    dict(phase="P2 探索世界", title="宝可梦中心与存档点", desc="治疗/队伍管理 UI、存档(autoload SaveManager)。", prio="medium", deps="T013"),
    dict(phase="P2 探索世界", title="野怪遭遇与道具拾取", desc="草丛随机遭遇、地面道具(CC0 占位)、scatter 布景。", prio="medium", deps="T006"),

    # ---- P3 实时战斗系统深化 ----
    dict(phase="P3 实时战斗深化", title="Z-A 战斗机制深化", desc="完美闪避、招式冷却条、蓄力/连段、环境互动。", prio="high", deps="T009"),
    dict(phase="P3 实时战斗深化", title="特性与状态异常", desc="特性系统、中毒/麻痹/睡眠/灼烧等状态及其实时效果。", prio="medium", deps="T009"),
    dict(phase="P3 实时战斗深化", title="多技能与换人", desc="每只宝可梦 1-4 技能、战斗中换人、属性/时机策略。", prio="medium", deps="T009"),

    # ---- P4 收服与养成 ----
    dict(phase="P4 收服与养成", title="捕捉系统", desc="投掷/收服判定(基于血量/状态)、捕捉动画占位、加入队伍或存储。", prio="high", deps="T009,T012"),
    dict(phase="P4 收服与养成", title="等级/经验/进化", desc="经验曲线、升级、进化条件与占位演出。", prio="high", deps="T008"),
    dict(phase="P4 收服与养成", title="背包与道具", desc="道具数据、使用逻辑(伤药/球/状态解除)、队伍管理界面。", prio="medium", deps="T008"),

    # ---- P5 道馆与进度 ----
    dict(phase="P5 道馆与进度", title="道馆战(Z-A战斗+朱紫结构)", desc="道馆场景、馆主 AI、连续对战、徽章奖励。", prio="high", deps="T015,T016"),
    dict(phase="P5 道馆与进度", title="主线进度与地图解锁", desc="剧情节点、区域解锁、图鉴进度。", prio="medium", deps="T013"),

    # ---- P6 内容填充与平衡 ----
    dict(phase="P6 内容填充与平衡", title="原创宝可梦图鉴", desc="设计原创属性与若干宝可梦(占位图形)、技能池、属性平衡表。", prio="medium", deps="T008"),
    dict(phase="P6 内容填充与平衡", title="数值平衡与测试", desc="GDUnit4 单元测试数值/克制, 战斗平衡调参。", prio="medium", deps="T005"),

    # ---- P7 打磨与发布 ----
    dict(phase="P7 打磨与发布", title="UI/UX 与设置", desc="标题/暂停/设置菜单、可访问性、键位自定义。", prio="medium", deps="T010"),
    dict(phase="P7 打磨与发布", title="性能优化与构建", desc="剔除占位、批量处理、导出 Windows 构建。", prio="medium", deps="T011"),
]


def now():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")


def load_tasks():
    if not TASKS_JSON.exists():
        return []
    with open(TASKS_JSON, "r", encoding="utf-8") as f:
        return json.load(f)


def save_tasks(tasks):
    with open(TASKS_JSON, "w", encoding="utf-8") as f:
        json.dump(tasks, f, ensure_ascii=False, indent=2)


def next_id(tasks):
    nums = [int(t["id"][1:]) for t in tasks if t["id"].startswith("T") and t["id"][1:].isdigit()]
    return f"T{len(nums)+1:03d}"


def gen_tasks_md(tasks):
    lines = []
    lines.append("# 任务规划 (TASKS)")
    lines.append("")
    lines.append("> 本文档由 `harness/harness.py` 从 `harness/tasks.json` 自动生成, 请勿手改。")
    lines.append("> 修改任务请用 `python harness/harness.py task set <id> status <x>`。")
    lines.append("")
    total = len(tasks)
    done = sum(1 for t in tasks if t["status"] == "done")
    lines.append(f"**总进度**: {done}/{total} 完成")
    lines.append("")
    # 汇总表
    lines.append("## 任务总览")
    lines.append("")
    lines.append("| ID | 阶段 | 标题 | 状态 | 优先级 | 依赖 |")
    lines.append("|----|------|------|------|--------|------|")
    for t in tasks:
        lines.append(f"| {t['id']} | {t['phase']} | {t['title']} | {STATUS_ICON[t['status']]} {t['status']} | {t['prio']} | {t.get('deps','') or '-'} |")
    lines.append("")
    # 按阶段分组
    phases = []
    for t in tasks:
        if t["phase"] not in phases:
            phases.append(t["phase"])
    for ph in phases:
        ph_tasks = [t for t in tasks if t["phase"] == ph]
        p_done = sum(1 for t in ph_tasks if t["status"] == "done")
        lines.append(f"## {ph}  ({p_done}/{len(ph_tasks)})")
        lines.append("")
        for t in ph_tasks:
            lines.append(f"### {STATUS_ICON[t['status']]} {t['id']} — {t['title']}")
            lines.append("")
            lines.append(f"- **状态**: {t['status']}")
            lines.append(f"- **优先级**: {t['prio']}")
            lines.append(f"- **依赖**: {t.get('deps','') or '无'}")
            lines.append(f"- **描述**: {t['desc']}")
            if t.get("note"):
                lines.append(f"- **进度**: {t['note']}")
            lines.append("")
    TASKS_MD.write_text("\n".join(lines), encoding="utf-8")


def ensure_devlog():
    if not DEVLOG_MD.exists():
        DEVLOG_MD.write_text("# 开发日志 (DEVLOG)\n\n> 由 harness/harness.py devlog add 自动追加。\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# 命令
# ---------------------------------------------------------------------------
def cmd_init():
    if TASKS_JSON.exists():
        print("tasks.json 已存在, 跳过初始化 (如需重置请先删除该文件)。")
        return
    tasks = []
    for i, s in enumerate(SEED_TASKS, start=1):
        tasks.append({
            "id": f"T{i:03d}",
            "phase": s["phase"],
            "title": s["title"],
            "desc": s["desc"],
            "status": "todo",
            "prio": s["prio"],
            "deps": s.get("deps", ""),
            "note": "",
        })
    save_tasks(tasks)
    gen_tasks_md(tasks)
    ensure_devlog()
    print(f"已初始化 {len(tasks)} 个任务, 生成 {TASKS_MD.relative_to(ROOT)}")


def cmd_task_list():
    tasks = load_tasks()
    for t in tasks:
        print(f"{STATUS_ICON[t['status']]} {t['id']} [{t['phase']}] {t['title']}  ({t['status']}/{t['prio']})")


def cmd_task_show(tid):
    tasks = load_tasks()
    for t in tasks:
        if t["id"] == tid:
            print(json.dumps(t, ensure_ascii=False, indent=2))
            return
    print(f"未找到任务 {tid}")


def cmd_task_add(title, phase, prio, desc):
    tasks = load_tasks()
    tid = next_id(tasks)
    tasks.append({"id": tid, "phase": phase, "title": title, "desc": desc or title,
                  "status": "todo", "prio": prio, "deps": "", "note": ""})
    save_tasks(tasks)
    gen_tasks_md(tasks)
    print(f"已新增 {tid}")


def cmd_task_set(tid, field, value):
    tasks = load_tasks()
    for t in tasks:
        if t["id"] == tid:
            if field == "status":
                if value not in STATUS_ORDER:
                    print(f"非法状态: {value}, 可选 {STATUS_ORDER}")
                    return
                t["status"] = value
            elif field == "note":
                t["note"] = value
            elif field == "prio":
                t["prio"] = value
            else:
                print(f"不支持的字段: {field}")
                return
            save_tasks(tasks)
            gen_tasks_md(tasks)
            print(f"{tid} {field} -> {value}")
            return
    print(f"未找到任务 {tid}")


def cmd_devlog_add(msg):
    ensure_devlog()
    with open(DEVLOG_MD, "a", encoding="utf-8") as f:
        f.write(f"\n## {now()} — {msg}\n")
    print(f"已记录 devlog: {msg}")


def cmd_report():
    tasks = load_tasks()
    total = len(tasks)
    done = sum(1 for t in tasks if t["status"] == "done")
    inprog = sum(1 for t in tasks if t["status"] == "in_progress")
    print(f"总任务 {total} | 完成 {done} | 进行中 {inprog} | 待办 {total-done-inprog}")
    phases = []
    for t in tasks:
        if t["phase"] not in phases:
            phases.append(t["phase"])
    for ph in phases:
        pts = [t for t in tasks if t["phase"] == ph]
        pd = sum(1 for t in pts if t["status"] == "done")
        print(f"  {ph}: {pd}/{len(pts)}")


def cmd_plan():
    tasks = load_tasks()
    phases = []
    for t in tasks:
        if t["phase"] not in phases:
            phases.append(t["phase"])
    for ph in phases:
        pts = [t for t in tasks if t["phase"] == ph]
        print(f"\n### {ph}")
        for t in pts:
            print(f"  {STATUS_ICON[t['status']]} {t['id']} {t['title']}")


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return
    cmd = args[0]
    if cmd == "init":
        cmd_init()
    elif cmd == "task":
        sub = args[1] if len(args) > 1 else "list"
        if sub == "list":
            cmd_task_list()
        elif sub == "show":
            cmd_task_show(args[2])
        elif sub == "add":
            # task add "<title>" --phase P1 --prio high --desc "..."
            title = args[2] if len(args) > 2 else "未命名任务"
            phase = "P1 MVP 垂直切片"
            prio = "medium"
            desc = title
            i = 3
            while i < len(args):
                if args[i] == "--phase":
                    phase = args[i+1]; i += 2
                elif args[i] == "--prio":
                    prio = args[i+1]; i += 2
                elif args[i] == "--desc":
                    desc = args[i+1]; i += 2
                else:
                    i += 1
            cmd_task_add(title, phase, prio, desc)
        elif sub == "set":
            cmd_task_set(args[2], args[3], args[4])
        else:
            print("未知 task 子命令")
    elif cmd == "devlog":
        if args[1] == "add":
            cmd_devlog_add(" ".join(args[2:]))
    elif cmd == "report":
        cmd_report()
    elif cmd == "plan":
        cmd_plan()
    else:
        print(f"未知命令: {cmd}")


if __name__ == "__main__":
    main()
