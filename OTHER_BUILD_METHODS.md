# 🔧 ADB ARM64 编译 - 其他轻量级方案

## 💡 除了 AOSP/Docker 还有这些办法

---

## 1️⃣ **GitHub Actions 远程编译** (最简单！)

完全在云端编译，无需本地配置

### 步骤：

**1. 创建 GitHub 仓库**
```bash
git init
git add .
git commit -m "Add modified ADB source"
git remote add origin https://github.com/YOUR_USERNAME/adb-custom.git
git push -u origin main
```

**2. 创建 .github/workflows/build.yml**

```yaml
name: Build ADB ARM64

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up build environment
      run: |
        sudo apt-get update
        sudo apt-get install -y openjdk-11-jdk python3 git repo

    - name: Initialize AOSP
      run: |
        mkdir -p ~/aosp && cd ~/aosp
        repo init -u https://android.googlesource.com/platform/manifest -b android-14 -q
        repo sync -j4 -q --fail-fast 2>&1 | tail -20

    - name: Copy modified ADB
      run: |
        cd ~/aosp
        rm -rf packages/modules/adb
        cp -r $GITHUB_WORKSPACE packages/modules/adb

    - name: Build ADB
      run: |
        cd ~/aosp
        source build/envsetup.sh > /dev/null
        lunch aosp_arm64-eng > /dev/null
        mmma packages/modules/adb -j$(nproc)

    - name: Upload artifact
      uses: actions/upload-artifact@v3
      with:
        name: adbd-arm64
        path: ~/aosp/out/target/product/generic_arm64/system/bin/adbd
        retention-days: 30
```

**3. Push 触发编译**
```bash
git push
```

**4. 查看编译结果**
- 打开 GitHub 仓库 → Actions
- 等待编译完成 (~40 分钟)
- 下载 Artifacts 中的 `adbd-arm64`

**优点：**
- ✅ 完全免费
- ✅ 无需本地配置
- ✅ 自动编译
- ✅ 云端存储

**缺点：**
- ⏱️ 编译需要 40-60 分钟
- 🌐 需要网络

---

## 2️⃣ **直接交叉编译** (最快！)

使用 NDK 工具链 + 简单的 Makefile，跳过完整 AOSP

### 创建 Makefile：

```makefile
NDK_PATH := /e/zygisk项目/android-ndk-r26b
CC := $(NDK_PATH)/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang
CXX := $(NDK_PATH)/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang++
AR := $(NDK_PATH)/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android-ar

CFLAGS := -O2 -Wall -D_GNU_SOURCE -DADB_HOST=0
CXXFLAGS := -O2 -Wall -std=c++17 -D_GNU_SOURCE -DADB_HOST=0 -fno-exceptions
LDFLAGS := -static-libstdc++

SOURCES := \
    adb.cpp \
    adb_io.cpp \
    adb_utils.cpp \
    transport.cpp \
    types.cpp \
    daemon/auth.cpp \
    daemon/main.cpp

OBJECTS := $(SOURCES:.cpp=.o)

TARGET := adbd

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(OBJECTS) $(LDFLAGS) -o $@
	@echo "✓ 编译完成: $@"
	@ls -lh $@

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -I. -I./daemon -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)

.PHONY: all clean
```

### 编译：
```bash
make clean && make
```

**时间：** 5 分钟
**输出：** `./adbd`

---

## 3️⃣ **使用 Nix** (如果你有 Linux)

```bash
# flake.nix
{
  description = "ADB ARM64 build environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            android-studio
            android-ndk
            gcc
            cmake
          ];
        };
      }
    );
}

# 使用:
nix flake update
nix develop
# 然后执行编译
```

---

## 4️⃣ **GitLab CI/CD** (同 GitHub Actions)

```yaml
# .gitlab-ci.yml
build_adb:
  image: ubuntu:22.04
  script:
    - apt-get update && apt-get install -y openjdk-11-jdk python3 git repo
    - mkdir -p ~/aosp && cd ~/aosp
    - repo init -u https://android.googlesource.com/platform/manifest -b android-14
    - repo sync -j4
    - cp -r $CI_PROJECT_DIR packages/modules/adb
    - source build/envsetup.sh
    - lunch aosp_arm64-eng
    - mmma packages/modules/adb
  artifacts:
    paths:
      - aosp/out/target/product/generic_arm64/system/bin/adbd
    expire_in: 30 days
```

---

## 5️⃣ **使用预编译 Docker 镜像** (5分钟启动)

```bash
# 无需编译 Dockerfile，直接用 AOSP 官方镜像
docker run -it \
  -v $(pwd):/workspace \
  ghcr.io/android/android-build-environment:latest

# 在容器内：
cd /workspace
mkdir -p ~/aosp && cd ~/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-14
repo sync -j4
cp -r /workspace packages/modules/adb
source build/envsetup.sh
lunch aosp_arm64-eng
mmma packages/modules/adb
```

---

## 6️⃣ **Bazel 编译** (如果 AOSP 支持)

```bash
# 在 AOSP 目录
bazel build //packages/modules/adb:adbd --platforms=//build/bazel/platforms:android_arm64
```

---

## 7️⃣ **交叉编译 + 最小依赖** (终极简化版)

只编译核心源文件，不编译完整 adb：

```bash
#!/bin/bash

NDK=/e/zygisk项目/android-ndk-r26b
CC=$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang
CXX=$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android30-clang++

# 只编译最小的源文件
$CXX -O2 -std=c++17 -D_GNU_SOURCE -DADB_HOST=0 \
  -I. -I./daemon \
  daemon/main.cpp daemon/auth.cpp \
  adb.cpp transport.cpp types.cpp \
  -o adbd

echo "✓ 完成: ./adbd"
ls -lh adbd
```

**编译时间：** 2-3 分钟

---

## 8️⃣ **预构建二进制** (最快！)

如果有人已经编译好了，直接下载：

```bash
# 从 GitHub Releases 下载 (如果存在)
curl -L https://github.com/YOUR_REPO/releases/download/v1.0/adbd-arm64 -o adbd
chmod +x adbd

# 或从其他渠道下载
```

---

## 对比表

| 方案 | 时间 | 难度 | 磁盘 | 网络 |
|-----|------|------|------|------|
| GitHub Actions | 40-60分钟 | ⭐ 最简 | 无 | 需要 |
| Docker | 30-60分钟 | ⭐⭐ | ~150GB | 需要 |
| WSL2 | 30-60分钟 | ⭐⭐ | ~150GB | 需要 |
| 直接Makefile | 5分钟 | ⭐⭐⭐ | 0 | 无 |
| 最小编译 | 2-3分钟 | ⭐⭐⭐⭐ | 0 | 无 |

---

## 🎯 **我的推荐** (按优先级)

### 1️⃣ **GitHub Actions** (首选)
```bash
# 最简单，完全自动化
git add .
git commit -m "ADB Custom Build"
git push
# 等 40 分钟，自动下载编译好的二进制
```

### 2️⃣ **最小编译** (最快)
```bash
bash minimal_build.sh
# 2-3 分钟完成
```

### 3️⃣ **Docker** (次选)
```bash
docker build -t adb-builder .
docker run -v $(pwd):/workspace adb-builder
```

---

## ✨ **创建最小编译脚本**

想要我给你写一个 5 分钟快速编译脚本吗？

或者想直接用 GitHub Actions 自动编译？

告诉我你想用哪个方案！
