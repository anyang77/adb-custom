@echo off
setlocal enabledelayedexpansion

echo.
echo ╔════════════════════════════════════════════════════╗
echo ║  上传 ADB 源码到 GitHub + 设置自动编译              ║
echo ╚════════════════════════════════════════════════════╝
echo.

set GITHUB_URL=https://github.com/anyang77/adb-custom.git
set GITHUB_USER=anyang77

REM 检查 git
git --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: git 未安装
    echo 请从 https://git-scm.com/download/win 下载 Git for Windows
    pause
    exit /b 1
)
echo ✓ Git 已安装
echo.

REM 初始化 git
if not exist ".git" (
    echo 📝 初始化 Git 仓库...
    git init
    echo ✓ Git 仓库已初始化
    echo.
)

REM 配置 git
echo ⚙️  配置 Git...
git config user.email "build@example.com"
git config user.name "ADB Custom Build"
echo ✓ Git 已配置
echo.

REM 添加文件
echo 📦 添加文件到暂存区...
git add -A
echo ✓ 文件已添加
echo.

REM 创建提交
echo 💾 创建提交...
git diff-index --quiet HEAD --
if errorlevel 1 (
    git commit -m "Add ADB ARM64 custom build (no-auth + always-root)"
    echo ✓ 提交已创建
) else (
    echo ⚠️  没有新的变更
)
echo.

REM 添加远程
echo 🌐 添加远程仓库...
git remote remove origin >nul 2>&1
git remote add origin %GITHUB_URL%
echo ✓ 远程仓库已添加: %GITHUB_URL%
echo.

REM 获取当前分支
for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set CURRENT_BRANCH=%%i
echo 📍 当前分支: %CURRENT_BRANCH%
echo.

REM Push 到 GitHub
echo ════════════════════════════════════════════════════
echo 📤 上传到 GitHub
echo ════════════════════════════════════════════════════
echo.
echo 请按照以下步骤进行:
echo.
echo 1️⃣  生成 GitHub Personal Token (PAT):
echo    https://github.com/settings/tokens
echo    - 选择 'repo' (完整仓库访问)
echo    - 复制生成的 Token
echo.
echo 2️⃣  执行以下命令:
echo    git push -u origin %CURRENT_BRANCH%
echo.
echo 3️⃣  输入凭证:
echo    Username: %GITHUB_USER%
echo    Password: ^<粘贴你的 token^>
echo.
echo ════════════════════════════════════════════════════
echo.
set /p CONFIRM="准备好了吗? (y/n): "

if /i "%CONFIRM%"=="y" (
    echo.
    echo 正在上传...
    echo.
    git push -u origin %CURRENT_BRANCH%

    if errorlevel 1 (
        echo.
        echo ❌ 上传失败
        echo 请检查:
        echo  1. GitHub token 是否正确
        echo  2. 仓库是否存在
        echo  3. 网络连接是否正常
        pause
        exit /b 1
    ) else (
        echo.
        echo ╔════════════════════════════════════════════════════╗
        echo ║  ✅ 上传成功!                                     ║
        echo ╚════════════════════════════════════════════════════╝
        echo.
        echo 📊 GitHub Actions 状态:
        echo    仓库: https://github.com/anyang77/adb-custom
        echo    Actions: https://github.com/anyang77/adb-custom/actions
        echo.
        echo 🚀 自动编译已启动!
        echo    等待 40-60 分钟...
        echo    编译完成后从 Releases 下载 adbd_arm64
        echo.
        echo 📥 下载位置:
        echo    https://github.com/anyang77/adb-custom/releases
        echo.
        pause
    )
) else (
    echo 已取消
    pause
    exit /b 0
)
