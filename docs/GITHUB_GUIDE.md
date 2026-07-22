# GitHub 账号与仓库创建指南（保姆级）

> 目标: 你还没有 GitHub。本指南带你注册账号、新建仓库；本地 git 提交由我完成，
> 推送(to GitHub)需要你的账号凭据, 按第四节操作即可。

---

## 一、注册 GitHub 账号

1. 打开浏览器访问 **https://github.com**
2. 点击右上角绿色按钮 **Sign up**（注册）。
3. 输入你的**邮箱** → 点 Continue。
4. 设置**密码**（至少 8 位，含字母数字）→ Continue。
5. 输入**用户名 Username**（英文/数字，例如 `yourname`，之后仓库地址就是 `github.com/yourname/...`）。
6. 选是否接收邮件 → Continue。
7. 完成**人机验证**（拼图）。
8. **验证邮箱**：GitHub 会发一封邮件，点里面的 Verify 按钮。
   ⚠️ 不验证邮箱无法创建仓库/推送。

---

## 二、新建仓库（Repository）

1. 登录后，点页面右上角 **`+`** → 选 **New repository**。
2. **Repository name**：建议用英文，例如 `stellara-monster-rpg`
   （仓库名最好别用中文/空格，避免命令行与路径问题）。
3. **Description**：可选，填 "原创IP宝可梦-like 3D对战RPG (Godot 4)"。
4. 选 **Public**（公开）或 **Private**（私有，仅你能看）。
5. ⚠️ **不要**勾选 "Add a README file" / "Add .gitignore" / "Add license"
   —— 我们项目里已经有了，勾了会冲突。
6. 点 **Create repository**。
7. 创建后会看到一个空仓库页面，里面有类似：
   `https://github.com/<你的用户名>/<仓库名>.git`
   复制这个地址备用（第四节要用）。

---

## 三、本地 git 提交（由我执行）

我会在项目根目录执行（你无需操作）：

```bash
git init
git add .
git commit -m "chore: 初始化项目框架 + P1 MVP (harness/docs/探索/实时战斗)"
```

> 首次 commit 前我会先 `git config user.name / user.email`（用占位值）。
> 你拿到 GitHub 后，请改成你自己的：
> ```bash
> git config user.name  "你的GitHub用户名"
> git config user.email "你的GitHub邮箱"
> ```

---

## 四、推送到 GitHub（需要你操作 / 提供凭据）

### 方式 A：用 GitHub CLI（推荐，最省事）
1. 下载安装 GitHub CLI：https://cli.github.com （Windows 装完重启终端）。
2. 在终端登录：
   ```bash
   gh auth login
   ```
   按提示选 GitHub.com → 选 HTTPS → 浏览器授权。
3. 关联远程并推送：
   ```bash
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git branch -M main
   git push -u origin main
   ```

### 方式 B：用 Personal Access Token（经典方式）
1. 登录 GitHub → 右上角头像 → **Settings** → 左侧 **Developer settings**
   → **Personal access tokens** → **Tokens (classic)** → **Generate new token (classic)**。
2. Note 填 `stellar-game`，**Expiration** 选 90 days（或 No expiration 自己负责安全）。
3. 勾选 **repo**（整组勾上）。
4. 点 **Generate token**，**立刻复制**那串 `ghp_...` 令牌（只显示一次！）。
5. 在终端执行：
   ```bash
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git branch -M main
   git push -u origin main
   ```
6. 提示输入用户名 → 填你的 GitHub 用户名；
   提示输入密码 → **粘贴刚才的 token**（不是你的账号密码，且粘贴时屏幕不显示，正常）。

> 🔒 安全提醒：token 等同于密码，不要发给任何人，也不要提交进代码。

---

## 五、后续日常流程

- 我每完成一个任务会本地 `git commit`（并写 devlog）。
- 你只需在有网时 `git push`（或 `gh push`）把进度推上去。
- 想看历史：`git log --oneline`。
- 想拉取：`git pull`。

---

## 六、常见问题

- **push 被拒 (non-fast-forward)**：先 `git pull --rebase origin main` 再 `git push`。
- **403 错误**：token 权限不足或已失效，重新生成 token。
- **中文路径警告**：Windows 下一般没问题；若报错，把仓库名改成纯英文即可。
- **addons 很大推不动**：GDExtension 预编译二进制较大属正常；如想瘦身可后续用 Git LFS。
