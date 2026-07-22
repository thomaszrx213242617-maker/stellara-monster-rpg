# GitHub 一键推送脚本 (T005)

> 你只需先在 github.com 注册账号并新建一个空仓库（不要勾选 Add README/.gitignore/license，保持空仓库），然后把下面的 USERNAME 和 REPO 换成你自己的，复制粘贴到 PowerShell 即可完成首次推送。

## 0. 在 GitHub 创建仓库
1. 登录 github.com -> 右上角 + -> New repository。
2. Repository name 填 stellara（或你喜欢的英文名，不能有空格）。
3. Description 可选。
4. 选 Public（或 Private）。
5. 不要勾选 Add a README / .gitignore / license（保持空仓库，避免与本地冲突）。
6. 点 Create repository，记下页面上的 https://github.com/<你的用户名>/<仓库名>.git。

## 1. 创建 Personal Access Token (PAT)
用于命令行推送（比密码安全，GitHub 已不再支持密码推送）。
1. GitHub 右上角头像 -> Settings -> Developer settings -> Personal access tokens -> Tokens (classic)。
2. Generate new token (classic) -> 勾选 repo 权限 -> 生成。
3. 复制并保存 token（关掉页面就再也看不到了）。

## 2. 在 PowerShell 里执行 (Windows)

把下面整块复制到 PowerShell，先替换占位符再回车：

```powershell
# === 把下面三行换成你自己的 ===
$USER  = "你的GitHub用户名"
$REPO  = "stellara"
$TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxx"

# 切到项目目录（用正斜杠避免转义问题）
Set-Location "G:/游戏设计/宝可梦游戏设计"

# 确认远程还没设
$remote = git remote get-url origin 2>$null
if (-not $remote) {
    git remote add origin "https://${USER}:${TOKEN}@github.com/${USER}/${REPO}.git"
    Write-Host "已添加 origin"
} else {
    git remote set-url origin "https://${USER}:${TOKEN}@github.com/${USER}/${REPO}.git"
    Write-Host "已更新 origin"
}

# 推送到 main（若默认分支是 master 则把 main 改成 master）
git branch -M main
git push -u origin main
```

## 3. 后续日常推送
```powershell
Set-Location "G:/游戏设计/宝可梦游戏设计"
git add .
git commit -m "feat: 你的更新说明"
git push
```

## 4. 不想把 token 写进 git remote URL？（更安全）
第一次推送成功后，清掉 remote 里的 token，改用 SSH 或 GitHub CLI 登录：

```powershell
git remote set-url origin "https://github.com/${USER}/${REPO}.git"
gh auth login
```

## 常见问题
- push 报 403 / 认证失败：token 复制错误或没勾 repo 权限，重新生成。
- 报 repository not found：USERNAME/REPO 拼写错，或仓库还没创建。
- 报 failed to push some refs：远端有空 commit，本地无；先 git pull --rebase origin main 再 push。

> 推上去后，第一时间把 TOKEN 视为泄露处理：去 GitHub 撤销该 token 并重新生成。
