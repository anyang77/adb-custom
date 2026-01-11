# Dockerfile for ADB ARM64 Compilation
# 完整的 AOSP 编译环境，包括所有依赖

FROM ubuntu:22.04

# 设置时区和语言
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8

# 安装依赖
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    python3 python3-dev \
    git curl wget \
    repo \
    build-essential \
    libssl-dev \
    bc \
    bison \
    flex \
    ccache \
    android-sdk-platform-tools \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /workspace

# 复制源码
COPY . /workspace/adb-src

# 创建编译脚本
RUN mkdir -p /workspace/aosp && cat > /workspace/compile.sh << 'EOF'
#!/bin/bash
set -e

echo "======================================"
echo "AOSP ARM64 ADB 编译"
echo "======================================"

cd /workspace/aosp

# 初始化 AOSP
echo "初始化 AOSP (这会下载几十GB的源码)..."
repo init -u https://android.googlesource.com/platform/manifest -b android-14 -q
echo "同步源码..."
repo sync -j$(nproc) -q --fail-fast 2>&1 | grep -E "Fetching|Syncing|error" || true

# 复制修改后的 ADB 代码
echo "复制修改后的 ADB 代码..."
rm -rf packages/modules/adb
cp -r /workspace/adb-src packages/modules/adb

# 编译
echo "初始化编译环境..."
source build/envsetup.sh > /dev/null

echo "配置 ARM64 编译..."
lunch aosp_arm64-eng > /dev/null

echo "开始编译 ADB..."
mmma packages/modules/adb -j$(nproc)

# 查找输出
echo ""
echo "======================================"
echo "编译完成！"
echo "======================================"
ADBD=$(find out/target/product -name "adbd" -type f 2>/dev/null | head -1)
if [ -n "$ADBD" ]; then
    echo "✓ adbd: $ADBD"
    ls -lh "$ADBD"
    cp "$ADBD" /workspace/output/
    echo "✓ 已复制到: /workspace/output/adbd"
else
    echo "❌ 未找到编译输出"
    exit 1
fi
EOF

chmod +x /workspace/compile.sh

ENTRYPOINT ["/workspace/compile.sh"]
