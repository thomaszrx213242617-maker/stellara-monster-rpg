# 构建与导出 (Windows)

本项目为 GDScript + 内置插件，无需 C#/外部依赖。导出为 Windows 可执行文件只需在 Godot 编辑器里走标准流程。

## 一次性准备：安装导出模板
1. 打开 Godot 4.7 → 编辑器顶部菜单 **Editor → Manage Export Templates**。
2. 点击 **Download** 下载对应版本的官方导出模板（需联网，约几十 MB）。
3. 下载完成后关闭该窗口。

> 导出模板是 Godot 官方的，非第三方资源，安全。

## 导出 Windows 可执行文件
1. 菜单 **Project → Export**（或 `Ctrl+Alt+E`）。
2. 点击 **Add…** → 选择 **Windows Desktop** → 确认。
3. 在右侧 `Export Path` 填：`build/星澜地区.exe`（目录会自动创建）。
4. （可选）勾选 `Export With Debug` 之外的 **Release** 配置以获得优化构建。
5. 点击 **Export Project**（或 **Export & Run** 直接运行测试）。
6. 生成的 `build/星澜地区.exe` + 同目录 `.pck` 即为可分发文件，拷贝到任意 Windows 机器即可运行（需相同架构）。

## 注意事项
- 若只勾了 `embed_pck`（默认），`.exe` 会内嵌资源，单文件即可分发。
- 若玩家机器缺运行库，Godot 会自动提示；Windows 10/11 一般无需额外安装。
- 本项目未使用 GDExtension（LimboAI/Terrain3D 未接入），因此**不需要**额外拷贝原生库（`.dll`/`.so`），导出即用。
- 想做 Steam/安装包等后续再扩展；当前聚焦可运行单机版。

## 自动化（可选，CI）
GitHub Actions 可用 `Godot Engine` 官方 action 自动导出，待 `T005` 仓库建立后可接入（见 `docs/GITHUB_GUIDE.md`）。
