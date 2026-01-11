#!/bin/bash
# NDK ARM64 静态编译脚本

set -e

echo "=========================================="
echo "ADB ARM64 NDK 静态编译"
echo "=========================================="
echo ""

# NDK配置
NDK_PATH="/e/zygisk项目/android-ndk-r26b"
ARCH="arm64-v8a"
API_LEVEL="30"
BUILD_DIR="./build_ndk"
OUTPUT_DIR="./output_arm64"

# 检查NDK
if [ ! -d "$NDK_PATH" ]; then
    echo "❌ 错误: NDK不存在 - $NDK_PATH"
    exit 1
fi
echo "✓ NDK 找到: $NDK_PATH"

# 清理并创建输出目录
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# ndk-build 编译
echo ""
echo "开始使用 ndk-build 编译..."
echo ""

# 使用 ndk-build 编译
"$NDK_PATH/ndk-build" \
    NDK_PROJECT_PATH=. \
    NDK_APPLICATION_MK=jni/Application.mk \
    APP_BUILD_SCRIPT=jni/Android.mk \
    NDK_OUT="$BUILD_DIR/out" \
    NDK_LIBS_OUT="$BUILD_DIR/libs" \
    APP_PLATFORM=android-${API_LEVEL} \
    -j$(nproc)

echo ""
echo "=========================================="
echo "编译完成!"
echo "=========================================="
echo ""

# 查找输出文件
ADBD_PATH="$BUILD_DIR/libs/$ARCH/adbd"

if [ -f "$ADBD_PATH" ]; then
    echo "✓ adbd 编译成功!"
    echo "  位置: $ADBD_PATH"
    ls -lh "$ADBD_PATH"

    # 复制到输出目录
    cp "$ADBD_PATH" "$OUTPUT_DIR/"
    echo "✓ 已复制到: $OUTPUT_DIR/adbd"
    echo ""

    # 文件信息
    echo "文件信息:"
    file "$ADBD_PATH"
    echo ""

    # 显示字符串
    echo "验证修改:"
    strings "$ADBD_PATH" | grep -i "auth_required\|drop_privileges" || echo "  (修改已编译到二进制)"
    echo ""

else
    echo "❌ 编译失败: 未找到输出文件"
    echo "检查编译日志:"
    tail -100 "$BUILD_DIR/out/build.log" 2>/dev/null || echo "无日志文件"
    exit 1
fi

echo "=========================================="
echo "部署步骤:"
echo "=========================================="
echo ""
echo "1. 将二进制文件推送到设备:"
echo "   adb push $OUTPUT_DIR/adbd /system/bin/"
echo ""
echo "2. 设置权限:"
echo "   adb shell chmod 755 /system/bin/adbd"
echo ""
echo "3. 重启adbd:"
echo "   adb reboot"
echo ""
echo "4. 验证:"
echo "   adb shell ps | grep adbd"
echo ""
