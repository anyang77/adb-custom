@echo off
REM ADB AOSP 缓存下载和上传脚本 (Windows 版本)
REM 需要: Git, WSL2, GitHub CLI (gh)

setlocal enabledelayedexpansion

echo.
echo =========================================
echo ADB AOSP Cache Builder (Windows)
echo =========================================
echo.

REM 检查 WSL2
echo === Checking WSL2 ===
wsl --list --verbose >nul 2>&1
if errorlevel 1 (
    echo ❌ WSL2 not found
    echo Please install WSL2 first: https://learn.microsoft.com/en-us/windows/wsl/install
    pause
    exit /b 1
)
echo ✓ WSL2 found

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

REM 在 WSL2 中运行构建
echo.
echo === Running build in WSL2 ===
echo This will take 1-2 hours...
echo.

wsl bash -c "
set -e

AOSP_DIR=~/aosp
GITHUB_REPO='anyang77/adb-custom'
CACHE_FILE='aosp-android13.tar.gz'

echo '=== Installing tools ==='
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends git curl python3 repo build-essential bc bison flex ccache liblz4-tool > /dev/null

echo ''
echo '=== Configuring git ==='
git config --global user.email 'build@example.com' 2>/dev/null || true
git config --global user.name 'Builder' 2>/dev/null || true
git config --global gc.autodetach false 2>/dev/null || true
git config --global url.'https://android.googlesource.com/'.insteadOf 'ssh://android.googlesource.com/' 2>/dev/null || true
git config --global http.postBuffer 524288000 2>/dev/null || true

echo '=== Initializing AOSP ==='
mkdir -p $AOSP_DIR
cd $AOSP_DIR

if [ ! -d '.repo' ]; then
    repo init -u https://android.googlesource.com/platform/manifest \
              -b android-13.0.0_r1 --depth=1 -j 4 2>&1 | tail -5
fi

echo ''
echo '=== Syncing AOSP (this may take 30-60 minutes) ==='
ATTEMPT=0
MAX_ATTEMPTS=3

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo \"Sync attempt $ATTEMPT/$MAX_ATTEMPTS\"

    if timeout 3600 repo sync -j 4 --no-tags --no-clone-bundle -q 2>&1 | tail -5; then
        if [ -f 'build/envsetup.sh' ]; then
            echo '✓ Sync successful'
            break
        fi
    fi

    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
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
cp -r /mnt/c/Users/Administrator/Desktop/adb packages/modules/adb

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
tar -czf $CACHE_FILE .repo/ build/ system/ frameworks/ prebuilts/ packages/modules/adb/ external/ bionic/ --exclude='.repo/project-objects' --exclude='.repo/projects' 2>/dev/null || {
    echo '⚠ Warning: Cache creation may have skipped some files'
}

if [ -f $CACHE_FILE ]; then
    SIZE=\$(du -h $CACHE_FILE | cut -f1)
    echo \"✓ Cache created: $SIZE\"
else
    echo '❌ Cache creation failed'
    exit 1
fi

echo ''
echo '=== Uploading to GitHub ==='
if [ -x \$(command -v gh) ]; then
    # Delete old release if exists
    gh release delete aosp-cache -R $GITHUB_REPO --yes 2>/dev/null || true
    sleep 2

    # Create new release
    gh release create aosp-cache $CACHE_FILE \
        -R $GITHUB_REPO \
        -t 'AOSP Android 13 Cache' \
        -n 'Pre-cached AOSP for faster builds' \
        --prerelease 2>&1 | tail -10

    echo '✓ Upload completed'
else
    echo 'ℹ gh CLI not found in WSL2, please upload manually:'
    echo \"  gh release create aosp-cache $AOSP_DIR/$CACHE_FILE -R $GITHUB_REPO --prerelease\"
fi

echo ''
echo '=== Complete ==='
echo 'Next steps:'
echo '1. Push your code: git push origin main'
echo '2. GitHub Actions will automatically:'
echo '   - Download AOSP cache'
echo '   - Compile ADB'
echo '   - Create release'
" 2>&1

if errorlevel 1 (
    echo.
    echo ❌ Build failed
    pause
    exit /b 1
)

echo.
echo ✓ Complete!
echo.
echo Next: git push origin main
pause
