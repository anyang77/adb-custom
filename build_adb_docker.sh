#!/bin/bash
# ADB ARM64 编译脚本（Docker 版本）
# 支持: Linux, macOS, WSL2
# 用法: bash build_adb_docker.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
DOCKER_IMAGE="ubuntu:22.04"
DOCKER_NAME="adb-builder-$$"
AOSP_DIR="/tmp/aosp-$$"
WORKSPACE=$(pwd)

# 函数定义
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 检查系统
print_step "Checking system requirements"

if ! command -v docker &> /dev/null; then
    print_error "Docker not installed"
    echo "  Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

print_success "Docker found: $(docker --version)"

# 检查磁盘空间
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
REQUIRED_SPACE=$((100 * 1024 * 1024)) # 100GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    print_warning "Low disk space: $(($AVAILABLE_SPACE / 1024 / 1024))GB available, need 100GB+"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 创建临时目录
print_step "Preparing workspace"
mkdir -p "$AOSP_DIR"
print_success "Workspace: $AOSP_DIR"

# 启动 Docker 容器
print_step "Starting Docker container"
docker run -d \
    --name "$DOCKER_NAME" \
    --memory 16g \
    --cpus 4 \
    -v "$WORKSPACE":/workspace \
    -v "$AOSP_DIR":/aosp \
    -e GITHUB_WORKSPACE=/workspace \
    "$DOCKER_IMAGE" \
    tail -f /dev/null > /dev/null

trap "docker rm -f $DOCKER_NAME 2>/dev/null" EXIT

print_success "Container started: $DOCKER_NAME"

# 在容器内执行编译
print_step "Installing dependencies inside container"
docker exec "$DOCKER_NAME" bash -c '
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        openjdk-11-jdk-headless \
        python3 python3-dev python3-distutils \
        git curl wget \
        build-essential libssl-dev \
        bc bison flex ccache \
        liblz4-tool rsync \
        > /dev/null 2>&1
' && print_success "Dependencies installed"

# 安装 repo 工具
print_step "Installing repo tool"
docker exec "$DOCKER_NAME" bash -c '
    mkdir -p /root/bin
    curl -s https://storage.googleapis.com/git-repo-downloads/repo > /root/bin/repo
    chmod a+x /root/bin/repo
    export PATH="/root/bin:$PATH"
'
print_success "Repo tool installed"

# 初始化 AOSP
print_step "Initializing AOSP Android 13"
docker exec "$DOCKER_NAME" bash -c '
    cd /aosp
    export PATH="/root/bin:$PATH"

    git config --global user.email "build@local.dev"
    git config --global user.name "Local Builder"
    git config --global gc.autodetach false
    git config --global url."https://android.googlesource.com/".insteadOf "ssh://android.googlesource.com/"
    git config --global http.postBuffer 524288000

    /root/bin/repo init \
        -u https://android.googlesource.com/platform/manifest \
        -b android-13.0.0_r1 \
        --depth=1 \
        -j 4 \
        2>&1 | tail -3
' && print_success "AOSP initialized"

# 同步源码
print_step "Syncing AOSP sources (this may take 30-60 minutes)"
docker exec "$DOCKER_NAME" bash -c '
    cd /aosp
    export PATH="/root/bin:$PATH"

    # 首次尝试
    if timeout 3600 /root/bin/repo sync \
        -j 4 \
        --no-tags \
        --no-clone-bundle \
        -q; then
        echo "Sync completed successfully"
    else
        echo "Sync timeout or failed, retrying..."
        timeout 3600 /root/bin/repo sync \
            -j 4 \
            --no-tags \
            --no-clone-bundle \
            -q || true
    fi

    # 验证
    [ -f "build/envsetup.sh" ] || {
        echo "AOSP sync failed"
        exit 1
    }
' && print_success "AOSP sources synced"

# 复制 ADB 代码
print_step "Copying modified ADB sources"
docker exec "$DOCKER_NAME" bash -c '
    cd /aosp
    [ -d "packages/modules/adb.bak" ] && rm -rf packages/modules/adb.bak
    [ -d "packages/modules/adb" ] && mv packages/modules/adb packages/modules/adb.bak
    mkdir -p packages/modules
    cp -r /workspace packages/modules/adb
'
print_success "ADB sources copied"

# 编译
print_step "Building ADB ARM64"
docker exec "$DOCKER_NAME" bash -c '
    cd /aosp

    bash -c "
        set -e
        source build/envsetup.sh > /dev/null 2>&1
        lunch aosp_arm64-eng > /dev/null 2>&1

        echo \"Building adbd for ARM64...\"
        m adbd -j\$(nproc) 2>&1 | tail -50
    "
' && print_success "Build completed"

# 提取二进制
print_step "Extracting binary"
docker exec "$DOCKER_NAME" bash -c '
    cd /aosp
    ADBD=$(find out -name "adbd" -type f 2>/dev/null | head -1)
    [ -n "$ADBD" ] || { echo "Binary not found"; exit 1; }
    cp "$ADBD" /workspace/adbd_arm64
'

if [ -f "$WORKSPACE/adbd_arm64" ]; then
    print_success "Binary extracted"
    echo ""
    echo "File: adbd_arm64"
    file "$WORKSPACE/adbd_arm64"
    ls -lh "$WORKSPACE/adbd_arm64"
else
    print_error "Failed to extract binary"
    exit 1
fi

# 清理
print_step "Cleaning up"
docker rm -f "$DOCKER_NAME" > /dev/null 2>&1

echo ""
print_success "Build complete!"
echo ""
echo "Next steps:"
echo "  1. Push to device:"
echo "     adb push adbd_arm64 /system/bin/adbd"
echo "     adb shell chmod 755 /system/bin/adbd"
echo ""
echo "  2. Test:"
echo "     adb shell /system/bin/adbd --version"
echo ""
