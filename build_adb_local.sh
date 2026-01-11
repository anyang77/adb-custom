#!/bin/bash
# ADB ARM64 本地编译脚本
# 前置要求: repo, git, build-essential, java
# 用法: bash build_adb_local.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# 配置
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOSP_DIR="${HOME}/aosp"
BUILD_LOG="${PROJECT_DIR}/build.log"

print_step "ADB ARM64 Build Script"
echo ""

# 1. 检查工具
print_step "Checking prerequisites"

TOOLS_OK=true
for tool in git repo java gcc; do
    if command -v $tool &> /dev/null; then
        VERSION=$($tool --version 2>&1 | head -1)
        print_success "$tool: found"
    else
        print_error "$tool: not found"
        TOOLS_OK=false
    fi
done

if [ "$TOOLS_OK" = false ]; then
    echo ""
    echo "Install missing tools:"
    echo "  Ubuntu/Debian:"
    echo "    sudo apt-get install openjdk-11-jdk git curl python3-dev build-essential bc bison flex"
    echo "    mkdir -p ~/bin && curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo && chmod a+x ~/bin/repo"
    echo "    export PATH=\"\$HOME/bin:\$PATH\""
    echo ""
    echo "  macOS:"
    echo "    brew install openjdk git python repo"
    echo ""
    exit 1
fi

# 2. 检查磁盘空间
print_step "Checking disk space"
AVAILABLE=$(df "$HOME" | tail -1 | awk '{print $4}')
REQUIRED=$((100 * 1024 * 1024)) # 100GB in KB

if [ "$AVAILABLE" -lt "$REQUIRED" ]; then
    print_warning "Available: $(($AVAILABLE/1024/1024))GB, Required: 100GB+"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

print_success "Disk space: $(($AVAILABLE/1024/1024))GB available"

# 3. 配置 git
print_step "Configuring git"
git config --global user.email "build@example.com"
git config --global user.name "Builder"
git config --global gc.autodetach false
git config --global url."https://android.googlesource.com/".insteadOf "ssh://android.googlesource.com/"
git config --global http.postBuffer 524288000
print_success "Git configured"

# 4. 初始化 AOSP
if [ ! -d "$AOSP_DIR/.repo" ]; then
    print_step "Initializing AOSP"
    mkdir -p "$AOSP_DIR"
    cd "$AOSP_DIR"

    repo init \
        -u https://android.googlesource.com/platform/manifest \
        -b android-13.0.0_r1 \
        --depth=1 \
        -j 4 \
        2>&1 | tail -5

    print_success "AOSP initialized"
else
    print_success "AOSP already initialized"
fi

# 5. 同步源码
print_step "Syncing AOSP sources (30-60 minutes)"
cd "$AOSP_DIR"

SYNC_ATTEMPTS=0
MAX_ATTEMPTS=3

while [ $SYNC_ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    SYNC_ATTEMPTS=$((SYNC_ATTEMPTS + 1))
    echo "Attempt $SYNC_ATTEMPTS/$MAX_ATTEMPTS"

    if timeout 3600 repo sync \
        -j 4 \
        --no-tags \
        --no-clone-bundle \
        -q 2>&1 | tail -10; then
        print_success "Sync completed"
        break
    else
        if [ $SYNC_ATTEMPTS -lt $MAX_ATTEMPTS ]; then
            print_warning "Sync timeout, retrying..."
            sleep 30
        fi
    fi
done

if [ ! -f "$AOSP_DIR/build/envsetup.sh" ]; then
    print_error "AOSP sync failed"
    exit 1
fi

# 6. 复制 ADB 代码
print_step "Copying modified ADB sources"
[ -d "$AOSP_DIR/packages/modules/adb.bak" ] && rm -rf "$AOSP_DIR/packages/modules/adb.bak"
[ -d "$AOSP_DIR/packages/modules/adb" ] && mv "$AOSP_DIR/packages/modules/adb" "$AOSP_DIR/packages/modules/adb.bak"
mkdir -p "$AOSP_DIR/packages/modules"
cp -r "$PROJECT_DIR" "$AOSP_DIR/packages/modules/adb"
print_success "ADB sources copied"

# 7. 编译
print_step "Building ADB ARM64"
cd "$AOSP_DIR"

bash -c '
    set -e
    source build/envsetup.sh > /dev/null 2>&1

    print_build_info() {
        echo ""
        echo "=== Build Configuration ==="
        echo "Target Device: $(get_build_var TARGET_DEVICE)"
        echo "Product: $(get_build_var PRODUCT)"
        echo "Variant: $(get_build_var TARGET_BUILD_VARIANT)"
        echo ""
    }

    # 选择配置
    lunch aosp_arm64-eng > /dev/null 2>&1
    print_build_info

    # 编译
    echo "Building adbd..."
    m adbd -j$(nproc) 2>&1 | tee "'$BUILD_LOG'" | tail -50
' || {
    print_error "Build failed"
    echo ""
    echo "Last 50 lines of build log:"
    tail -50 "$BUILD_LOG"
    exit 1
}

print_success "Build completed"

# 8. 提取二进制
print_step "Extracting binary"
ADBD_PATH=$(find "$AOSP_DIR/out" -name "adbd" -type f 2>/dev/null | head -1)

if [ -z "$ADBD_PATH" ]; then
    print_error "Binary not found"
    exit 1
fi

cp "$ADBD_PATH" "$PROJECT_DIR/adbd_arm64"
print_success "Binary extracted"

# 输出结果
echo ""
echo "=== Build Complete ==="
echo ""
echo "Output: $PROJECT_DIR/adbd_arm64"
echo "Size: $(du -h "$PROJECT_DIR/adbd_arm64" | cut -f1)"
echo "Type: $(file -b "$PROJECT_DIR/adbd_arm64")"
echo ""
echo "Next steps:"
echo "  adb push adbd_arm64 /system/bin/adbd"
echo "  adb shell chmod 755 /system/bin/adbd"
echo "  adb reboot"
echo ""
