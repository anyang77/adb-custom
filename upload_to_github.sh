#!/bin/bash
# 上传到 GitHub 并设置自动编译

set -e

GITHUB_URL="https://github.com/anyang77/adb-custom.git"
GITHUB_USER="anyang77"

echo "╔════════════════════════════════════════════════════╗"
echo "║  上传 ADB 源码到 GitHub + 设置自动编译              ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# 检查 git
if ! command -v git &> /dev/null; then
    echo "❌ 错误: git 未安装"
    exit 1
fi
echo "✓ Git 已安装"

# 初始化 git
if [ ! -d ".git" ]; then
    echo ""
    echo "📝 初始化 Git 仓库..."
    git init
    echo "✓ Git 仓库已初始化"
fi

# 配置 git
echo ""
echo "⚙️  配置 Git..."
git config user.email "build@example.com" || true
git config user.name "ADB Custom Build" || true
echo "✓ Git 已配置"

# 添加文件
echo ""
echo "📦 添加文件到暂存区..."
git add -A
echo "✓ 文件已添加"

# 创建提交
echo ""
echo "💾 创建提交..."
if git diff-index --quiet HEAD --; then
    echo "⚠️  没有新的变更"
else
    git commit -m "Add ADB ARM64 custom build (no-auth + always-root)"
    echo "✓ 提交已创建"
fi

# 添加远程
echo ""
echo "🌐 添加远程仓库..."
if git remote | grep -q origin; then
    echo "  移除旧的 origin..."
    git remote remove origin
fi

git remote add origin "$GITHUB_URL"
echo "✓ 远程仓库已添加: $GITHUB_URL"

# 检查分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo ""
echo "📍 当前分支: $CURRENT_BRANCH"

# Push 到 GitHub
echo ""
echo "📤 上传到 GitHub..."
echo ""
echo "请按照以下步骤进行:"
echo ""
echo "1️⃣  生成 GitHub Personal Token (PAT):"
echo "   https://github.com/settings/tokens"
echo "   - 选择 'repo' (完整仓库访问)"
echo "   - 复制生成的 Token"
echo ""
echo "2️⃣  执行以下命令:"
echo ""
echo "   git push -u origin $CURRENT_BRANCH"
echo ""
echo "3️⃣  输入用户名和 token:"
echo "   Username: $GITHUB_USER"
echo "   Password: <粘贴你的 token>"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "准备好了吗? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "正在上传..."
    git push -u origin "$CURRENT_BRANCH"

    if [ $? -eq 0 ]; then
        echo ""
        echo "╔════════════════════════════════════════════════════╗"
        echo "║  ✅ 上传成功!                                     ║"
        echo "╚════════════════════════════════════════════════════╝"
        echo ""
        echo "📊 GitHub Actions 状态:"
        echo "   仓库: https://github.com/anyang77/adb-custom"
        echo "   Actions: https://github.com/anyang77/adb-custom/actions"
        echo ""
        echo "🚀 自动编译已启动!"
        echo "   等待 40-60 分钟..."
        echo "   编译完成后从 Releases 下载 adbd_arm64"
        echo ""
        echo "📥 下载位置:"
        echo "   https://github.com/anyang77/adb-custom/releases"
        echo ""
    else
        echo "❌ 上传失败"
        exit 1
    fi
else
    echo "已取消"
    exit 0
fi
