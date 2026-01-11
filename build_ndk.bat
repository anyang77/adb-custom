@echo off
REM NDK ARM64 静态编译脚本 (Windows)

setlocal enabledelayedexpansion

echo.
echo ==========================================
echo ADB ARM64 NDK 静态编译 (Windows)
echo ==========================================
echo.

REM 配置
set NDK_PATH=E:\zygisk项目\android-ndk-r26b
set ARCH=arm64-v8a
set API_LEVEL=30
set BUILD_DIR=build_ndk
set OUTPUT_DIR=output_arm64

REM 检查NDK
if not exist "%NDK_PATH%" (
    echo ❌ 错误: NDK不存在 - %NDK_PATH%
    exit /b 1
)
echo ✓ NDK 找到: %NDK_PATH%
echo.

REM 清理目录
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"
mkdir "%BUILD_DIR%"
mkdir "%OUTPUT_DIR%"

echo 开始编译...
echo.

REM 执行 ndk-build
call "%NDK_PATH%\ndk-build.cmd" ^
    NDK_PROJECT_PATH=. ^
    NDK_APPLICATION_MK=jni\Application.mk ^
    APP_BUILD_SCRIPT=jni\Android.mk ^
    NDK_OUT="%BUILD_DIR%\out" ^
    NDK_LIBS_OUT="%BUILD_DIR%\libs" ^
    APP_PLATFORM=android-%API_LEVEL%

if %ERRORLEVEL% neq 0 (
    echo ❌ 编译失败!
    exit /b 1
)

echo.
echo ==========================================
echo 编译完成!
echo ==========================================
echo.

REM 检查输出文件
set ADBD_PATH=%BUILD_DIR%\libs\%ARCH%\adbd.exe
if not exist "%ADBD_PATH%" (
    set ADBD_PATH=%BUILD_DIR%\libs\%ARCH%\adbd
)

if exist "%ADBD_PATH%" (
    echo ✓ adbd 编译成功!
    echo   位置: %ADBD_PATH%
    dir "%ADBD_PATH%"
    echo.

    REM 复制到输出目录
    copy "%ADBD_PATH%" "%OUTPUT_DIR%\"
    echo ✓ 已复制到: %OUTPUT_DIR%\adbd
    echo.

) else (
    echo ❌ 未找到输出文件
    echo 检查目录内容:
    dir "%BUILD_DIR%\libs"
    exit /b 1
)

echo ==========================================
echo 部署步骤:
echo ==========================================
echo.
echo 1. 将二进制文件推送到设备:
echo    adb push %OUTPUT_DIR%\adbd /system/bin/
echo.
echo 2. 设置权限:
echo    adb shell chmod 755 /system/bin/adbd
echo.
echo 3. 重启设备:
echo    adb reboot
echo.
echo 4. 验证:
echo    adb shell ps ^| grep adbd
echo.

pause
