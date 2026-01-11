#!/bin/bash
# 本地生成 AOSP 缓存并上传到 GitHub
# 用法: bash build_and_upload_cache.sh

set -e

GITHUB_REPO="anyang77/adb-custom"  # 改成你的仓库
AOSP_DIR="$HOME/aosp"
CACHE_FILE="aosp-android13.tar.gz"

echo "========================================="
echo "AOSP Cache Builder"
echo "========================================="
echo ""

# 检查工具
if ! command -v git &> /dev/null; then
    echo "❌ git 未安装"
    exit 1
fi

if ! command -v repo &> /dev/null; then
    echo "❌ repo 未安装，正在安装..."
    mkdir -p ~/bin
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
    chmod a+x ~/bin/repo
    export PATH="$HOME/bin:$PATH"
fi

if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI 未安装"
    echo "请先安装: https://cli.github.com/"
    echo "或运行: brew install gh (macOS) / winget install GitHub.cli (Windows)"
    exit 1
fi

# 配置 git
echo "=== Configuring git ==="
git config --global user.email "build@example.com"
git config --global user.name "Builder"
git config --global gc.autodetach false
git config --global url."https://android.googlesource.com/".insteadOf "ssh://android.googlesource.com/"

# 初始化/同步 AOSP
if [ ! -d "$AOSP_DIR/.repo" ]; then
    echo ""
    echo "=== Initializing AOSP ==="
    mkdir -p "$AOSP_DIR"
    cd "$AOSP_DIR"

    repo init -u https://android.googlesource.com/platform/manifest \
              -b android-13.0.0_r1 --depth=1 2>&1 | tail -10

    echo "✓ AOSP initialized"
else
    echo "✓ AOSP directory exists, updating..."
    cd "$AOSP_DIR"
fi

echo ""
echo "=== Syncing AOSP sources ==="
echo "This will take 30-60 minutes depending on your network..."
echo ""

# 开始时间
START_TIME=$(date +%s)

# 同步（带重试）
for attempt in 1 2 3; do
    echo "Sync attempt $attempt/3..."
    if timeout 7200 repo sync -j4 --no-tags --no-clone-bundle 2>&1 | tail -20; then
        echo "✓ Sync completed"
        break
    else
        echo "⚠ Sync attempt $attempt timed out or failed"
        if [ $attempt -lt 3 ]; then
            echo "Retrying in 10 seconds..."
            sleep 10
        fi
    fi
done

# 验证关键文件
if [ ! -f "build/envsetup.sh" ]; then
    echo "❌ AOSP sync failed - missing build/envsetup.sh"
    exit 1
fi

echo "✓ AOSP synced successfully"

# 显示耗时
END_TIME=$(date +%s)
SYNC_TIME=$((END_TIME - START_TIME))
echo "Sync time: $((SYNC_TIME / 60)) minutes"

# 复制修改后的 ADB
echo ""
echo "=== Copying modified ADB ==="
WORKSPACE=$(pwd)/../adb
if [ -d "$WORKSPACE" ]; then
    rm -rf packages/modules/adb
    cp -r "$WORKSPACE" packages/modules/adb
    echo "✓ Modified ADB copied"
else
    echo "⚠ Could not find ADB source, using default"
fi

# 编译
echo ""
echo "=== Building ADB ==="
bash -c '
    set -e
    source build/envsetup.sh > /dev/null 2>&1
    lunch aosp_arm64-eng > /dev/null 2>&1
    m adbd -j$(nproc) 2>&1 | tail -50
' || {
    echo "❌ Build failed"
    exit 1
}

# 验证二进制
ADBD_PATH=$(find out -name "adbd" -type f 2>/dev/null | head -1)
if [ -z "$ADBD_PATH" ]; then
    echo "❌ adbd binary not found"
    exit 1
fi

echo "✓ Build successful"
echo "Binary: $ADBD_PATH"
ls -lh "$ADBD_PATH"

# 生成缓存包
echo ""
echo "=== Creating cache package ==="
if [ -f "$CACHE_FILE" ]; then
    rm "$CACHE_FILE"
fi

echo "Compressing AOSP sources (this takes 10-20 minutes)..."
tar -czf "$CACHE_FILE" \
    .repo/ \
    build/ \
    system/ \
    frameworks/ \
    prebuilts/ \
    packages/modules/adb/ \
    external/ \
    bionic/ \
    2>/dev/null || {
    echo "⚠ Compression failed"
    exit 1
}

CACHE_SIZE=$(du -h "$CACHE_FILE" | cut -f1)
echo "✓ Cache created: $CACHE_SIZE"
echo "File: $(pwd)/$CACHE_FILE"

# 上传到 GitHub
echo ""
echo "=== Uploading to GitHub ==="
echo "Checking GitHub authentication..."

if ! gh auth status > /dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub"
    echo "Please run: gh auth login"
    exit 1
fi

echo "✓ GitHub authenticated"

# 创建或更新 Release
echo "Creating release tag 'aosp-cache'..."

# 检查是否已有该 tag
if gh release view aosp-cache -R "$GITHUB_REPO" > /dev/null 2>&1; then
    echo "Deleting old release..."
    gh release delete aosp-cache -R "$GITHUB_REPO" --yes || true
    sleep 2
fi

echo "Uploading cache ($CACHE_SIZE)..."
gh release create aosp-cache \
    "$CACHE_FILE" \
    -R "$GITHUB_REPO" \
    -t "AOSP Android 13 Cache" \
    -n "Pre-cached AOSP Android 13 sources for faster builds." \
    --prerelease || {
    echo "❌ Upload failed"
    exit 1
}

echo "✓ Cache uploaded to GitHub Releases"

# 清理
echo ""
echo "=== Cleanup ==="
rm "$CACHE_FILE"
echo "✓ Local cache file deleted"

echo ""
echo "========================================="
echo "✓ Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Commit your ADB changes: git push"
echo "2. GitHub Actions will automatically:"
echo "   - Download cached AOSP"
echo "   - Compile ADB"
echo "   - Create Release with adbd_arm64"
echo ""
echo "All future builds will take ~15 minutes!"
