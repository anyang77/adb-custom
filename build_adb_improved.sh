#!/bin/bash
# ADB ARM64 编译脚本 - 改进版本
# 修复 repo 工具问题，提供更好的错误处理
# 用法: bash build_adb_improved.sh

set -e

# 颜色定义
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
REPO_TOOL="${HOME}/bin/repo"

echo ""
echo "========================================="
echo "ADB ARM64 编译脚本 (改进版)"
echo "========================================="
echo ""

# ============= 第 1 步：检查和安装工具 =============

print_step "检查系统工具"

# 检查 git
if ! command -v git &> /dev/null; then
    print_error "git 未安装"
    exit 1
fi
print_success "git 已安装"

# 检查 java
if ! command -v java &> /dev/null; then
    print_error "Java 未安装，需要 OpenJDK 11"
    echo "  Ubuntu: sudo apt-get install openjdk-11-jdk"
    echo "  macOS: brew install openjdk@11"
    exit 1
fi
JAVA_VERSION=$(java -version 2>&1 | head -1)
print_success "Java 已安装: $JAVA_VERSION"

# 检查 python3
if ! command -v python3 &> /dev/null; then
    print_error "Python3 未安装"
    exit 1
fi
print_success "Python3 已安装"

# 检查 gcc/make
if ! command -v gcc &> /dev/null; then
    print_error "build-essential 未安装"
    echo "  Ubuntu: sudo apt-get install build-essential"
    exit 1
fi
print_success "build-essential 已安装"

# 安装 repo 工具
print_step "检查 repo 工具"

if [ ! -f "$REPO_TOOL" ]; then
    print_warning "repo 工具未安装，正在下载..."
    mkdir -p "${HOME}/bin"

    curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$REPO_TOOL" || {
        print_error "下载 repo 失败"
        exit 1
    }

    chmod a+x "$REPO_TOOL"
    print_success "repo 工具已安装"
else
    print_success "repo 工具已存在"
fi

# 验证 repo
if ! "$REPO_TOOL" --version &> /dev/null; then
    print_error "repo 工具验证失败"
    rm -f "$REPO_TOOL"
    exit 1
fi

print_success "repo 工具验证成功"

# ============= 第 2 步：检查磁盘空间 =============

print_step "检查磁盘空间"

AVAILABLE=$(df "$HOME" | tail -1 | awk '{print $4}')
REQUIRED=$((100 * 1024 * 1024)) # 100GB in KB

AVAILABLE_GB=$((AVAILABLE / 1024 / 1024))
REQUIRED_GB=$((REQUIRED / 1024 / 1024))

echo "可用空间: ${AVAILABLE_GB}GB"
echo "需要空间: ${REQUIRED_GB}GB+"

if [ "$AVAILABLE" -lt "$REQUIRED" ]; then
    print_warning "磁盘空间不足"
    read -p "继续? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

print_success "磁盘空间检查通过"

# ============= 第 3 步：配置 Git =============

print_step "配置 Git"

git config --global user.email "build@example.com" 2>/dev/null || true
git config --global user.name "Builder" 2>/dev/null || true
git config --global gc.autodetach false 2>/dev/null || true
git config --global url."https://android.googlesource.com/".insteadOf "ssh://android.googlesource.com/" 2>/dev/null || true
git config --global http.postBuffer 524288000 2>/dev/null || true
git config --global http.lowSpeedLimit 0 2>/dev/null || true
git config --global http.lowSpeedTime 999999 2>/dev/null || true

print_success "Git 配置完成"

# ============= 第 4 步：初始化 AOSP =============

print_step "初始化 AOSP"

if [ -d "$AOSP_DIR/.repo" ]; then
    print_warning "AOSP 已存在，跳过初始化"
else
    mkdir -p "$AOSP_DIR"
    cd "$AOSP_DIR"

    echo "运行: repo init -u https://android.googlesource.com/platform/manifest -b android-13.0.0_r1 --depth=1"

    if ! "$REPO_TOOL" init \
        -u https://android.googlesource.com/platform/manifest \
        -b android-13.0.0_r1 \
        --depth=1 \
        -j 4 \
        2>&1 | tail -10; then
        print_error "repo init 失败"
        exit 1
    fi

    print_success "AOSP 初始化完成"
fi

# ============= 第 5 步：同步 AOSP 源码 =============

print_step "同步 AOSP 源码（这可能需要 30-60 分钟）"

cd "$AOSP_DIR"

# 验证 repo 是否可用
if ! "$REPO_TOOL" --version &> /dev/null; then
    print_error "repo 工具不可用"
    exit 1
fi

SYNC_ATTEMPTS=0
MAX_ATTEMPTS=3
SYNC_SUCCESS=false

while [ $SYNC_ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    SYNC_ATTEMPTS=$((SYNC_ATTEMPTS + 1))

    echo ""
    echo "同步尝试 $SYNC_ATTEMPTS/$MAX_ATTEMPTS"
    echo "运行: repo sync -j4 --no-tags --no-clone-bundle"
    echo ""

    # 使用 timeout 防止无限等待
    if timeout 3600 "$REPO_TOOL" sync \
        -j 4 \
        --no-tags \
        --no-clone-bundle \
        -q 2>&1 | tail -20; then

        # 验证关键文件
        if [ -f "build/envsetup.sh" ]; then
            print_success "同步成功"
            SYNC_SUCCESS=true
            break
        else
            print_warning "同步完成但缺少关键文件，重试..."
        fi
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            print_warning "同步超时（1小时），重试..."
        else
            print_warning "同步失败 (exit code: $EXIT_CODE)，重试..."
        fi
    fi

    if [ $SYNC_ATTEMPTS -lt $MAX_ATTEMPTS ]; then
        echo "等待 30 秒后重试..."
        sleep 30
    fi
done

if [ "$SYNC_SUCCESS" = false ]; then
    print_error "同步失败，已尝试 $MAX_ATTEMPTS 次"
    echo ""
    echo "故障排查:"
    echo "  1. 检查网络连接: ping android.googlesource.com"
    echo "  2. 检查磁盘空间: df -h"
    echo "  3. 查看详细日志: cd $AOSP_DIR && repo sync -j1"
    exit 1
fi

# 验证 AOSP
if [ ! -f "$AOSP_DIR/build/envsetup.sh" ]; then
    print_error "AOSP 同步失败：找不到 build/envsetup.sh"
    exit 1
fi

print_success "AOSP 源码同步完成"
ls -lh "$AOSP_DIR/build/envsetup.sh"

# ============= 第 6 步：复制修改的 ADB 代码 =============

print_step "复制修改的 ADB 源码"

cd "$AOSP_DIR"

# 备份原始 ADB
if [ -d "packages/modules/adb" ]; then
    rm -rf packages/modules/adb.backup
    mv packages/modules/adb packages/modules/adb.backup
    print_success "原始 ADB 已备份"
fi

# 复制修改的代码
mkdir -p packages/modules
cp -r "$PROJECT_DIR" packages/modules/adb

print_success "ADB 源码已复制"

# 显示修改的文件
echo ""
echo "修改的源文件:"
find packages/modules/adb -type f \( -name "*.cpp" -o -name "*.h" \) | head -15

# ============= 第 7 步：编译 ADB =============

print_step "编译 ADB ARM64"

cd "$AOSP_DIR"

# 创建编译脚本
BUILD_SCRIPT=$(mktemp)
cat > "$BUILD_SCRIPT" << 'EOFBUILD'
#!/bin/bash
set -e

# 加载编译环境
echo "加载编译环境..."
source build/envsetup.sh > /dev/null 2>&1

# 选择编译配置
echo "选择编译配置..."
lunch aosp_arm64-eng > /dev/null 2>&1

# 显示编译信息
echo ""
echo "=== 编���配置 ==="
echo "目标设备: $(get_build_var TARGET_DEVICE)"
echo "产品: $(get_build_var PRODUCT)"
echo "变体: $(get_build_var TARGET_BUILD_VARIANT)"
echo "编译线程: $(nproc)"
echo ""

# 编译
echo "开始编译 adbd..."
m adbd -j$(nproc) 2>&1 | tee build_output.log

# 检查编译结果
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✓ 编译成功"
else
    echo ""
    echo "✗ 编译失败"
    exit 1
fi
EOFBUILD

chmod +x "$BUILD_SCRIPT"

if bash "$BUILD_SCRIPT" 2>&1 | tee -a "$BUILD_LOG"; then
    print_success "编译完成"
else
    print_error "编译失败"
    echo ""
    echo "查看编译日志:"
    echo "  tail -100 $AOSP_DIR/build_output.log"
    rm -f "$BUILD_SCRIPT"
    exit 1
fi

rm -f "$BUILD_SCRIPT"

# ============= 第 8 步：提取二进制 =============

print_step "提取二进制文件"

cd "$AOSP_DIR"

# 查找 adbd
ADBD_PATH=$(find out -name "adbd" -type f 2>/dev/null | head -1)

if [ -z "$ADBD_PATH" ]; then
    print_error "找不到 adbd 二进制文件"
    echo ""
    echo "搜索结果:"
    find out -name "adbd*" 2>/dev/null | head -10
    exit 1
fi

print_success "找到二进制: $ADBD_PATH"

# 验证二进制
echo ""
echo "二进制信息:"
file "$ADBD_PATH"
ls -lh "$ADBD_PATH"

# 复制到项目目录
cp "$ADBD_PATH" "$PROJECT_DIR/adbd_arm64"

print_success "二进制已复制到 $PROJECT_DIR/adbd_arm64"

# ============= 第 9 步：验证输出 =============

print_step "验证输出文件"

if [ ! -f "$PROJECT_DIR/adbd_arm64" ]; then
    print_error "输出文件不存在"
    exit 1
fi

echo ""
echo "=== 最终输出 ==="
ls -lh "$PROJECT_DIR/adbd_arm64"
file "$PROJECT_DIR/adbd_arm64"

# 检查是否是 ARM64
if file "$PROJECT_DIR/adbd_arm64" | grep -q "ARM aarch64"; then
    print_success "二进制验证成功 (ARM64)"
else
    print_warning "二进制架构可能不正确"
    file "$PROJECT_DIR/adbd_arm64"
fi

# ============= 完成 =============

echo ""
echo "========================================="
print_success "编译完成！"
echo "========================================="
echo ""
echo "输出文件: $PROJECT_DIR/adbd_arm64"
echo "文件大小: $(du -h "$PROJECT_DIR/adbd_arm64" | cut -f1)"
echo ""
echo "下一步:"
echo "  1. 推送到设备:"
echo "     adb push adbd_arm64 /data/local/tmp/"
echo "     adb shell chmod 755 /data/local/tmp/adbd_arm64"
echo ""
echo "  2. 测试:"
echo "     adb shell /data/local/tmp/adbd_arm64 --version"
echo ""
echo "  3. 部署:"
echo "     adb push adbd_arm64 /system/bin/adbd"
echo "     adb shell chmod 755 /system/bin/adbd"
echo "     adb reboot"
echo ""
