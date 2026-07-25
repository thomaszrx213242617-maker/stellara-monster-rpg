# 开发日志 (DEVLOG)

> 由 harness/harness.py devlog add 自动追加。

## 2026-07-22 14:37 — 项目启动: 确认设计为原创IP宝可梦-like(3D朱紫式探索 + Z-A式实时战斗 + 收服养成); 搭建harness框架与目录结构。

## 2026-07-22 14:40 — 完成 harness 框架与三份文档: 需求(REQUIREMENTS)/规划(TASKS,自动生成)/规范(STANDARDS)/README。

## 2026-07-22 15:04 — 实现 P1 MVP 代码: 探索(玩家/相机/世界)、数据层(克制/技能/灵兽)、Z-A式实时战斗原型、昼夜与夜间收服规则。详见 core/ world/ battle/ autoload/。

## 2026-07-22 15:14 — 本地git初始化并首次提交(框架+文档+MVP代码+5个开源插件). phantom-camera因仓库体积克隆超时, 标注为走Godot资源库安装.

## 2026-07-22 16:02 — P2-P4 集成闭环完成: 探索→草丛遭遇→实时战斗→经验/进化→收服(消耗球)→宝可梦中心治疗存档; 状态异常+特性+多技能切换+NPC对话. 数据扩充至14灵兽/23技能/道具.

## 2026-07-22 17:06 — 完成 T020 道馆战: GymZone + 训练家战斗模式(胜利发徽章+自动存档, 禁止收服); T025 构建导出指南 docs/BUILD.md.

## 2026-07-25 13:15 — 新增标题画面(新游戏/继续/设置/退出)与暂停菜单(Esc), main_scene 切到 TitleScreen.tscn; 全脚本编译验证通过。

## 2026-07-25 13:23 — 新增灵兽图鉴系统: GameState.dex_seen/dex_caught + note_dex_seen/note_dex_caught, SaveManager 持久化, BattleArena 遭遇登记已见/收服登记已捕; Pokedex 面板(已捕/已见/未知三态, 显示属性与种族值), 暂停菜单加「灵兽图鉴」按钮。编辑器导入编译验证通过。

## 2026-07-25 13:47 — 修复 Godot 报错: InputSetup 注册 ui_cancel(KEY_ESCAPE, 原 KEY_ESC 在 Godot4 不存在); 新增 队伍/背包 面板(PartyBag): 查看队伍(名称/等级/HP/种族值/招式)与背包, 野外对选中成员使用伤药治疗, 暂停菜单加「队伍/背包」按钮。编辑器导入编译验证通过(无 SCRIPT ERROR/Parse Error)。
