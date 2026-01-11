#!/bin/bash
# 🚀 超级快速编译脚本 - 2分钟完成
# 使用 NDK 工具链直接交叉编译

set -e

echo "╔════════════════════════════════════════╗"
echo "║  ADB ARM64 超快速编译 (2-3分钟)       ║"
echo "╚════════════════════════════════════════╝"
echo ""

# 配置
NDK_PATH="/e/zygisk项目/android-ndk-r26b"
CC="$NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang"
CXX="$NDK_PATH/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang++"
OUTPUT="adbd_arm64"

# 检查编译器
if [ ! -f "$CC" ]; then
    echo "❌ 错误: 找不到编译器"
    echo "路径: $CC"
    exit 1
fi
echo "✓ 编译器: $(basename $CC)"
echo ""

# 编译标志
CXXFLAGS="-O2 -std=c++17 -Wall -D_GNU_SOURCE -DADB_HOST=0 -fno-exceptions -fno-rtti"
LDFLAGS="-static-libstdc++"

# 最小源文件列表 - 只编译核心部分
SOURCES=(
    "daemon/main.cpp"
    "daemon/auth.cpp"
    "daemon/logging.cpp"
    "adb.cpp"
    "adb_io.cpp"
    "adb_utils.cpp"
    "transport.cpp"
    "types.cpp"
    "sysdeps_unix.cpp"
)

echo "📝 编译源文件:"
for src in "${SOURCES[@]}"; do
    if [ -f "$src" ]; then
        echo "  ✓ $src"
    else
        echo "  ⚠️  缺失: $src"
    fi
done
echo ""

echo "⚙️  编译中..."
echo ""

# 执行编译
"$CXX" $CXXFLAGS \
    -I. -I./daemon \
    "${SOURCES[@]}" \
    $LDFLAGS \
    -o "$OUTPUT" 2>&1 | head -50

if [ $? -eq 0 ] && [ -f "$OUTPUT" ]; then
    echo ""
    echo "✅ 编译成功!"
    echo ""
    echo "📦 输出文件信息:"
    ls -lh "$OUTPUT"
    echo ""
    echo "📋 文件详情:"
    file "$OUTPUT"
    echo ""
    echo "🎉 完成! 文件位置: $(pwd)/$OUTPUT"
    echo ""
    echo "📱 推送到设备:"
    echo "  adb push $OUTPUT /system/bin/adbd"
    echo "  adb shell chmod 755 /system/bin/adbd"
    echo "  adb reboot"
else
    echo ""
    echo "❌ 编译失败"
    echo ""
    echo "可能的原因:"
    echo "  1. 缺少必要的头文件"
    echo "  2. 某些源文件不存在"
    echo "  3. 需要完整 AOSP 环境"
    echo ""
    echo "解决方案:"
    echo "  使用完整编译: docker build . && docker run -v \$(pwd):/workspace/adb-src docker_image"
    exit 1
fi
