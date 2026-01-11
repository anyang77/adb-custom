@echo off
REM ADB AOSP 本地编译脚本 (Windows + Docker)
REM 一键下载、编译、生成二进制

setlocal enabledelayedexpansion

echo.
echo =========================================
echo ADB ARM64 本地编译 (Docker)
echo =========================================
echo.

REM 检查 Docker
echo === 检查 Docker ===
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker 未安装
    echo 请安装 Docker Desktop: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)
echo ✓ Docker 已安装

set PROJECT_DIR=%cd%

echo.
echo === 启动 Docker 容器 ===
echo 这将耗时 1-2 小时...
echo.

REM 在 Docker 中运行编译
docker run -it --rm ^
  -v "%PROJECT_DIR%":/workspace ^
  -v aosp-build:/aosp ^
  ubuntu:22.04 bash -c "
set -e

AOSP_DIR=/aosp
WORKSPACE=/workspace

echo '=== 安装工具 ==='
apt-get update -qq
apt-get install -y --no-install-recommends git curl python3 repo build-essential bc bison flex ccache openjdk-11-jdk-headless > /dev/null

echo ''
echo '=== 配置 git ==='
git config --global user.email 'build@example.com' 2>/dev/null || true
git config --global user.name 'Builder' 2>/dev/null || true
git config --global gc.autodetach false 2>/dev/null || true
git config --global url.'https://android.googlesource.com/'.insteadOf 'ssh://android.googlesource.com/' 2>/dev/null || true
git config --global http.postBuffer 524288000 2>/dev/null || true

echo '=== 初始化 AOSP ==='
mkdir -p \$AOSP_DIR
cd \$AOSP_DIR

if [ ! -d '.repo' ]; then
    repo init -u https://android.googlesource.com/platform/manifest \
              -b android-13.0.0_r1 --depth=1 -j 4 2>&1 | tail -5
fi

echo ''
echo '=== 同步 AOSP 源码 (30-60 分钟) ==='
ATTEMPT=0
MAX_ATTEMPTS=3

while [ \$ATTEMPT -lt \$MAX_ATTEMPTS ]; do
    ATTEMPT=\$((ATTEMPT + 1))
    echo \"同步尝试 \$ATTEMPT/\$MAX_ATTEMPTS\"

    if timeout 3600 repo sync -j 4 --no-tags --no-clone-bundle -q 2>&1 | tail -5; then
        if [ -f 'build/envsetup.sh' ]; then
            echo '✓ 同步成功'
            break
        fi
    fi

    if [ \$ATTEMPT -lt \$MAX_ATTEMPTS ]; then
        echo '⚠ 同步失败，30 秒后重试...'
        sleep 30
    fi
done

if [ ! -f 'build/envsetup.sh' ]; then
    echo '❌ AOSP 同步失败'
    exit 1
fi

echo ''
echo '=== 复制修改的 ADB 代码 ==='
rm -rf packages/modules/adb
cp -r \$WORKSPACE packages/modules/adb

echo ''
echo '=== 编译 ADB (10-20 分钟) ==='
bash -c '
    set -e
    source build/envsetup.sh > /dev/null 2>&1
    lunch aosp_arm64-eng > /dev/null 2>&1
    m adbd -j\$(nproc) 2>&1 | tail -50
'

echo ''
echo '✓ 编译完成'

echo ''
echo '=== 提取二进制 ==='
ADBD_PATH=\$(find out -name \"adbd\" -type f 2>/dev/null | head -1)
if [ -z \"\$ADBD_PATH\" ]; then
    echo '❌ 找不到 adbd 二进制'
    exit 1
fi

cp \"\$ADBD_PATH\" \$WORKSPACE/adbd_arm64
echo '✓ 二进制已提取'
ls -lh \$WORKSPACE/adbd_arm64
"

if errorlevel 1 (
    echo.
    echo ❌ 编译失败
    pause
    exit /b 1
)

echo.
echo ✓ 编译完成！
echo.
echo 输出文件: %PROJECT_DIR%\adbd_arm64
echo.
echo 下一步:
echo   1. 推送到设备: adb push adbd_arm64 /system/bin/adbd
echo   2. 设置权限: adb shell chmod 755 /system/bin/adbd
echo   3. 重启设备: adb reboot
echo.
pause
