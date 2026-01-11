#!/bin/bash
# 快速AOSP ARM64 编译脚本
# 假设已有完整AOSP环境

set -e

echo "========================================"
echo "Android ADB ARM64 快速编译"
echo "========================================"
echo ""

# 检查是否在AOSP目录中
if [ ! -f "build/envsetup.sh" ]; then
    echo "错误: 请在AOSP根目录中运行此脚本"
    echo "当前目录: $(pwd)"
    exit 1
fi

echo "✓ 检测到AOSP环境"
echo ""

# 初始化编译环境
echo "初始化编译环境..."
source build/envsetup.sh > /dev/null

# 配置ARM64构建
echo "配置 ARM64 eng 构建..."
lunch aosp_arm64-eng > /dev/null

echo ""
echo "========================================"
echo "编译配置:"
echo "========================================"
echo "架构: ARM64 (aarch64)"
echo "目标: aosp_arm64-eng"
echo "编译模式: eng (engineering build)"
echo ""

# 开始编译
echo "开始编译 ADB 模块..."
echo "时间: $(date)"
echo ""

mmma packages/modules/adb

echo ""
echo "========================================"
echo "编译完成!"
echo "========================================"
echo ""

# 查找输出文件
ADBD_PATH=$(find out/target/product -name "adbd" -type f 2>/dev/null | head -1)

if [ -n "$ADBD_PATH" ]; then
    echo "✓ adbd 位置: $ADBD_PATH"
    echo "✓ 文件大小: $(du -h "$ADBD_PATH" | cut -f1)"
    echo ""
    echo "验证二进制文件:"
    file "$ADBD_PATH"
    echo ""
    echo "推送到设备的命令:"
    echo "  adb push $ADBD_PATH /system/bin/"
    echo "  adb reboot"
else
    echo "❌ 未找到编译输出的 adbd"
    exit 1
fi

echo ""
echo "编译时间: $(date)"
