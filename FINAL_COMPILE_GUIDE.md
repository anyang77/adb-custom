# 🚀 ADB ARM64 编译 - 完整指南

## ✅ 已完成

- ✓ 源码修改 (无授权 + 始终 Root)
- ✓ NDK 库下载完成 (25+ 个库文件)
- ✓ 编译脚本生成完成
- ✓ Docker 环境配置完成

---

## 📦 已下载的库文件

位置: `prebuilt_libs/lib/`

包含:
- libc.so / libc.a - C 标准库
- libc++_static.a - C++ 静态库
- libm.so - 数学库
- libz.so - 压缩库
- libdl.so - 动态链接库
- 以及其他 20+ 个 Android 库

---

## 🎯 编译方案 (3选1)

### 方案 A: Docker 编译 (⭐推荐 - 最简单)

**优点**:
- 一键编译
- 自动下载所有依赖
- 无需配置

**步骤**:

```bash
# 1. 确保 Docker 已安装
docker --version

# 2. 构建编译镜像
docker build -t adb-builder:arm64 .

# 3. 运行编译
docker run -it \
  -v $(pwd):/workspace/adb-src \
  -v $(pwd)/docker_output:/workspace/output \
  adb-builder:arm64

# 4. 编译输出
ls -lh docker_output/adbd
```

**编译时间**: 30-60 分钟 (首次)
**磁盘空间**: ~150GB (Docker 容器内)

---

### 方案 B: WSL2 编译 (⭐次选)

**前置条件**: Windows 上已安装 WSL2

**步骤**:

```bash
# 在 WSL2 Ubuntu 中执行:

# 1. 创建工作目录
mkdir -p ~/aosp && cd ~/aosp

# 2. 安装依赖
sudo apt-get install -y \
  openjdk-11-jdk \
  python3 git repo \
  build-essential \
  libssl-dev

# 3. 初始化 AOSP
repo init -u https://android.googlesource.com/platform/manifest \
  -b android-14 \
  -q

# 4. 同步源码 (这会下载 ~100GB, 根据网速需要 1-6 小时)
repo sync -j$(nproc) -q --fail-fast

# 5. 复制修改后的 ADB 代码
rm -rf packages/modules/adb
cp -r /mnt/c/Users/Administrator/Desktop/adb packages/modules/adb

# 6. 编译
source build/envsetup.sh
lunch aosp_arm64-eng
mmma packages/modules/adb -j$(nproc)

# 7. 查找输出
find out -name adbd -type f | head -1
# 典型位置: out/target/product/generic_arm64/system/bin/adbd
```

**编译时间**: 30-60 分钟 (首次)
**磁盘空间**: ~150GB (WSL 文件系统)

---

### 方案 C: 本地 Linux 编译

**前置条件**: Linux 机器 (Ubuntu 20.04+)

```bash
# 步骤同 WSL2 方案一样，但在原生 Linux 上
```

---

## 🔄 快速选择

### 你有 Docker? ➜ **使用方案 A**
```bash
docker build -t adb-builder:arm64 .
docker run -v $(pwd):/workspace/adb-src adb-builder:arm64
```

### 你有 WSL2? ➜ **使用方案 B**
```bash
# 在 WSL2 中运行上述 AOSP 编译步骤
```

### 你只有 Windows? ➜ **安装 Docker Desktop**
```bash
# 下载: https://www.docker.com/products/docker-desktop
```

---

## 📊 编译预期结果

### 输出文件

```
adbd (ARM64 可执行文件)
├─ 架构: ARM64 (aarch64)
├─ 格式: ELF 64-bit LSB executable
├─ 大小: ~1-3 MB (strip 后)
└─ 特性:
    ✓ 无授权检查
    ✓ 始终 Root
    ✓ 不依赖系统属性
```

### 验证编译输出

```bash
# 查看文件信息
file adbd
# 输出: ELF 64-bit LSB executable, ARM aarch64, ...

# 查看大小
ls -lh adbd

# 查看动态依赖
readelf -d adbd | grep NEEDED
```

---

## 📱 部署到设备

编译完成后:

```bash
# 1. 推送文件
adb push adbd /system/bin/

# 2. 设置权限
adb shell chmod 755 /system/bin/adbd

# 3. 重启设备
adb reboot

# 4. 验证
adb shell ps | grep adbd
# 输出应该是: root ... /system/bin/adbd
```

---

## 🐛 故障排除

### Docker 相关

**问题**: Docker 找不到
```bash
# 解决: 下载并安装 Docker Desktop
# https://www.docker.com/products/docker-desktop
```

**问题**: 镜像构建失败
```bash
# 解决: 清理并重试
docker system prune -a
docker build --no-cache -t adb-builder:arm64 .
```

### WSL2 相关

**问题**: repo sync 超时
```bash
# 解决: 使用清华镜像
repo init -u https://mirrors.tsinghua.edu.cn/git/AOSP/platform/manifest -b android-14
```

**问题**: 磁盘空间不足
```bash
# 解决: 扩展 WSL2 虚拟磁盘
# WSL: WSL_UTF8=1 wsl --shutdown
# 在 PowerShell 中运行
```

### 编译相关

**问题**: "Cannot find modules"
```bash
# 解决: 确认 lunch 配置
lunch aosp_arm64-eng

# 确认 ADB 路径
ls -la packages/modules/adb/
```

**问题**: 编译超时
```bash
# 解决: 减少并发
mmma packages/modules/adb -j2
```

---

## ⚡ 加速编译

### 1. 使用 ccache
```bash
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)
ccache -M 50G  # 设置 cache 大小
```

### 2. 使用国内镜像
```bash
# 清华镜像
repo init -u https://mirrors.tsinghua.edu.cn/git/AOSP/platform/manifest
```

### 3. 跳过不必要的编译
```bash
# 仅编译 ADB
mmma packages/modules/adb -j$(nproc)

# 不编译整个 AOSP
# (这会快 10 倍)
```

---

## 📚 文件清单

### 核心文件
```
adb/
├─ daemon/
│  ├─ auth.cpp        ✓ 修改: auth_required = false
│  └─ main.cpp        ✓ 修改: should_drop_privileges() = false
├─ Android.mk         ✓ ndk-build 配置
├─ jni/
│  ├─ Android.mk
│  └─ Application.mk
├─ CMakeLists.txt     ✓ CMake 配置
└─ Dockerfile         ✓ Docker 编译
```

### 编译脚本
```
├─ build_arm64_aosp.sh       快速 AOSP 编译脚本
├─ build_ndk.sh             NDK 编译脚本
├─ build_ndk.bat            Windows NDK 脚本
├─ build_cmake.sh           CMake 编译脚本
├─ compile_interactive.py    交互式编译工具
└─ download_deps.py          依赖库下载工具
```

### 文档
```
├─ NDK_BUILD_GUIDE.md        NDK 编译详细指南
├─ BUILD_INSTRUCTIONS.txt    编译说明
├─ COMPILE_SUMMARY.md        编译摘要
└─ compile_wsl.sh            WSL 快速脚本
```

---

## ✨ 下一步

### 立即开始编译:

**1️⃣ 有 Docker**:
```bash
docker build -t adb-builder . && \
docker run -v $(pwd):/workspace/adb-src adb-builder
```

**2️⃣ 有 WSL2**:
```bash
# 在 WSL2 Ubuntu 中
bash /mnt/c/Users/Administrator/Desktop/adb/build_arm64_aosp.sh
```

**3️⃣ 纯 Linux**:
```bash
# 按照 AOSP 编译步骤
source build/envsetup.sh
lunch aosp_arm64-eng
mmma packages/modules/adb
```

---

## 📞 帮助

### 修改相关
- ✓ auth_required: `daemon/auth.cpp:66`
- ✓ should_drop_privileges: `daemon/main.cpp:66-69`
- ✓ 属性检查: `daemon/main.cpp:193-196`

### 编译相关
- 查看编译日志: `tail -100 out/verbose.log`
- 清理编译: `make clean`
- 重新编译: `mmma packages/modules/adb -B`

### 部署相关
- 推送: `adb push adbd /system/bin/`
- 重启: `adb reboot`
- 验证: `adb shell ps | grep adbd`

---

**编译日期**: 2026-01-11
**修改状态**: ✅ 完成
**架构**: ARM64 (aarch64)
**API 级别**: 30+
**库文件**: 已下载 (25+ 个)
