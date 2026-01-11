@echo off
REM ADB AOSP 缓存下载脚本 (纯 Windows 版本 - 使用 Docker)
REM 需要: Docker Desktop, GitHub CLI (gh)

setlocal enabledelayedexpansion

echo.
echo =========================================
echo ADB AOSP Cache Builder (Windows + Docker)
echo =========================================
echo.

REM 检查 Docker
echo === Checking Docker ===
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker not found
    echo Please install Docker Desktop: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)
echo ✓ Docker found

REM 检查 GitHub CLI
echo.
echo === Checking GitHub CLI ===
where gh >nul 2>&1
if errorlevel 1 (
    echo ❌ GitHub CLI not found
    echo Please install: winget install GitHub.cli
    pause
    exit /b 1
)
echo ✓ GitHub CLI found

REM 获取当前目录
set PROJECT_DIR=%cd%

echo.
echo === Starting Docker container ===
echo This will take 1-2 hours...
echo.

REM 在 Docker 中运行构建
docker run -it --rm ^
  -v "%PROJECT_DIR%":/workspace ^
  -v aosp-cache:/aosp ^
  ubuntu:22.04 bash -c "
set -e

AOSP_DIR=/aosp
WORKSPACE=/workspace
GITHUB_REPO='anyang77/adb-custom'
CACHE_FILE='aosp-android13.tar.gz'

echo '=== Installing tools ==='
apt-get update -qq
apt-get install -y --no-install-recommends git curl python3 repo build-essential bc bison flex ccache liblz4-tool openjdk-11-jdk-headless > /dev/null

echo ''
echo '=== Configuring git ==='
git config --global user.email 'build@example.com' 2>/dev/null || true
git config --global user.name 'Builder' 2>/dev/null || true
git config --global gc.autodetach false 2>/dev/null || true
git config --global url.'https://android.googlesource.com/'.insteadOf 'ssh://android.googlesource.com/' 2>/dev/null || true
git config --global http.postBuffer 524288000 2>/dev/null || true

echo '=== Initializing AOSP ==='
mkdir -p \$AOSP_DIR
cd \$AOSP_DIR

if [ ! -d '.repo' ]; then
    repo init -u https://android.googlesource.com/platform/manifest \
              -b android-13.0.0_r1 --depth=1 -j 4 2>&1 | tail -5
fi

echo ''
echo '=== Syncing AOSP (this may take 30-60 minutes) ==='
ATTEMPT=0
MAX_ATTEMPTS=3

while [ \$ATTEMPT -lt \$MAX_ATTEMPTS ]; do
    ATTEMPT=\$((ATTEMPT + 1))
    echo \"Sync attempt \$ATTEMPT/\$MAX_ATTEMPTS\"

    if timeout 3600 repo sync -j 4 --no-tags --no-clone-bundle -q 2>&1 | tail -5; then
        if [ -f 'build/envsetup.sh' ]; then
            echo '✓ Sync successful'
            break
        fi
    fi

    if [ \$ATTEMPT -lt \$MAX_ATTEMPTS ]; then
        echo '⚠ Sync failed, retrying in 30 seconds...'
        sleep 30
    fi
done

if [ ! -f 'build/envsetup.sh' ]; then
    echo '❌ AOSP sync failed'
    exit 1
fi

echo ''
echo '=== Copying modified ADB ==='
rm -rf packages/modules/adb
cp -r \$WORKSPACE packages/modules/adb

echo ''
echo '=== Building ADB ==='
bash -c '
    set -e
    source build/envsetup.sh > /dev/null 2>&1
    lunch aosp_arm64-eng > /dev/null 2>&1
    m adbd -j\$(nproc) 2>&1 | tail -50
'

echo ''
echo '✓ Build completed'

echo ''
echo '=== Creating cache archive ==='
tar -czf \$CACHE_FILE .repo/ build/ system/ frameworks/ prebuilts/ packages/modules/adb/ external/ bionic/ --exclude='.repo/project-objects' --exclude='.repo/projects' 2>/dev/null || {
    echo '⚠ Warning: Cache creation may have skipped some files'
}

if [ -f \$CACHE_FILE ]; then
    SIZE=\$(du -h \$CACHE_FILE | cut -f1)
    echo \"✓ Cache created: \$SIZE\"
    cp \$CACHE_FILE \$WORKSPACE/
else
    echo '❌ Cache creation failed'
    exit 1
fi

echo ''
echo '=== Complete ==='
echo 'Cache file: \$WORKSPACE/\$CACHE_FILE'
"

if errorlevel 1 (
    echo.
    echo ❌ Build failed
    pause
    exit /b 1
)

echo.
echo === Uploading to GitHub ===
if exist "%PROJECT_DIR%\aosp-android13.tar.gz" (
    gh release delete aosp-cache --yes 2>nul
    timeout /t 2 /nobreak >nul

    gh release create aosp-cache "%PROJECT_DIR%\aosp-android13.tar.gz" ^
        -t "AOSP Android 13 Cache" ^
        -n "Pre-cached AOSP for faster builds" ^
        --prerelease

    if errorlevel 1 (
        echo ❌ Upload failed
        echo Please upload manually:
        echo   gh release create aosp-cache "%PROJECT_DIR%\aosp-android13.tar.gz" --prerelease
    ) else (
        echo ✓ Upload completed
    )
) else (
    echo ❌ Cache file not found
)

echo.
echo ✓ Complete!
echo.
echo Next: git push origin main
pause
