# ADB ARM64 编译指南

新的编译方案提供了三种编译方式，从快速到完整。

## 方案对比

| 方案 | 环境 | 时间 | 难度 | 磁盘 | 推荐场景 |
|------|------|------|------|------|---------|
| **GitHub Actions** | ☁️ 云端 | 2-3h | 简单 | ∞ | 首次编译 + CI/CD |
| **本地 (Docker)** | 🐳 容器 | 2-3h | 简单 | 100GB+ | 有 Docker 环境 |
| **本地 (直接)** | 🖥️ 直接 | 2-3h | 中等 | 150GB+ | 本地开发调试 |

---

## 方案 1: GitHub Actions（推荐首选）

最简单和最可靠的方式，无需本地配置。

### 使用步骤

1. **修改代码**（可选）
   ```bash
   # 编辑你的代码
   vim daemon/main.cpp
   ```

2. **提交并推送**
   ```bash
   git add .
   git commit -m "修改 ADB 代码"
   git push origin main
   ```

3. **查看编译结果**
   - 打开 GitHub 仓库
   - 进入 Actions 标签
   - 点击最新的 Workflow Run
   - 等待编译完成（约 2-3 小时）
   - 编译完成后自动创建 Release

### 优势

✓ 无需本地 100GB 磁盘空间
✓ 无需安装 AOSP 工具链
✓ 自动处理所有依赖
✓ 编译日志完整可追溯
✓ 自动创建可下载的 Release

### 故障排查

如果编译失败：

1. **查看完整日志**
   - Actions → 具体 Workflow → 点击每个 Step 展开

2. **常见错误**

   - **超时 (timeout)**：增加 `timeout-minutes` 值
   - **同步失败**：检查网络，自动重试机制已内置
   - **内存不足**：GitHub Actions 有 7GB 内存，已优化

3. **重新触发编译**
   ```bash
   git push origin main  # 再次 push 即可
   # 或在 GitHub Actions 界面点击 "Re-run"
   ```

---

## 方案 2: 本地编译 (Docker)

需要 Docker，但不需要 100GB 磁盘在本机。

### 前置要求

- **Linux / macOS / WSL2**
- **Docker**（[安装指南](https://docs.docker.com/get-docker/)）
- **100GB+ 可用空间**

### 使用步骤

```bash
# 1. 进入项目目录
cd /path/to/adb

# 2. 运行编译脚本
bash build_adb_docker.sh

# 3. 等待完成（2-3 小时）
# 输出: ./adbd_arm64
```

### 脚本功能

- ✓ 自动创建 Docker 容器
- ✓ 自动下载和配置 AOSP
- ✓ 自动编译 adbd
- ✓ 自动清理临时文件
- ✓ 详细的进度输出

### 进度监控

编译过程分为几个阶段：

```
==> Preparing workspace
==> Starting Docker container
==> Installing dependencies (1-2 min)
==> Initializing AOSP (2-3 min)
==> Syncing AOSP sources (30-60 min) ← 最长
==> Copying ADB sources (1 min)
==> Building ADB ARM64 (10-20 min)
==> Extracting binary (1 min)
```

### 故障排查

| 问题 | 解决方案 |
|------|---------|
| Docker 容器启动失败 | `docker ps` 检查 Docker 是否运行 |
| 同步超时 | 脚本已内置重试，等待即可 |
| 磁盘不足 | `df -h /tmp` 检查空间 |
| 编译出错 | 查看完整日志：`docker logs <container_id>` |

---

## 方案 3: 本地编译 (直接)

完整的本地编译，适合频繁开发调试。

### 前置要求

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
    openjdk-11-jdk \
    git curl \
    python3 python3-dev python3-distutils \
    build-essential libssl-dev \
    bc bison flex ccache liblz4-tool

# 安装 repo
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH="$HOME/bin:$PATH"
```

**macOS:**
```bash
brew install openjdk@11 git python3
brew tap android-platform-tools/adb
```

**WSL2:**
```bash
# 在 WSL2 Ubuntu 中运行 Ubuntu 的命令
```

### 使用步骤

```bash
# 1. 进入项目目录
cd /path/to/adb

# 2. 运行编译脚本
bash build_adb_local.sh

# 3. 等待完成（2-3 小时）
# 输出: ./adbd_arm64
```

### 编译过程详解

脚本会自动执行：

1. **检查工具** (1 min)
   - 验证 git, repo, java, gcc 已安装

2. **初始化 AOSP** (3 min)
   - `repo init -u https://android.googlesource.com/platform/manifest -b android-13.0.0_r1`

3. **同步源码** (30-60 min)
   - `repo sync -j4 --no-tags --no-clone-bundle`
   - 如果失败会自动重试 3 次

4. **复制 ADB** (1 min)
   - 将修改的代码复制到 AOSP

5. **编译** (10-20 min)
   - `lunch aosp_arm64-eng`
   - `m adbd -j$(nproc)`

### 进度追踪

编译日志保存在 `./build.log`：

```bash
# 实时查看日志
tail -f build.log

# 查看编译错误
grep -i "error" build.log
```

### 故障排查

| 问题 | 解决方案 |
|------|---------|
| repo sync 超时 | 脚本内置 3 次重试，耐心等待 |
| 编译错误 | 检查 `build.log` 最后 50 行 |
| Java 版本错误 | 确保 Java 11: `java -version` |
| Python 错误 | 需要 Python 3: `python3 --version` |

---

## 输出文件

所有方案都会生成 `adbd_arm64`：

```bash
file adbd_arm64
# Output: ELF 64-bit LSB shared object, ARM aarch64

ls -lh adbd_arm64
# Output: -rwxr-xr-x adbd_arm64 (~15-20MB)
```

### 验证二进制

```bash
# 检查架构
file adbd_arm64

# 检查依赖
readelf -d adbd_arm64 | grep NEEDED

# 查看符号
nm adbd_arm64 | grep main
```

---

## 部署到设备

编译完成后，推送到 Android 设备：

```bash
# 1. 连接设备
adb devices

# 2. 推送二进制
adb push adbd_arm64 /data/local/tmp/adbd_test

# 3. 测试（不覆盖原始 adbd）
adb shell chmod 755 /data/local/tmp/adbd_test
adb shell /data/local/tmp/adbd_test --version

# 4. 如果测试成功，覆盖原始版本
adb push adbd_arm64 /system/bin/adbd
adb shell chmod 755 /system/bin/adbd
adb reboot
```

---

## 常见问题 (FAQ)

### Q: 编译时间这么长是正常的吗？

**A:** 是的，这是正常的：
- 首次同步 AOSP：30-60 分钟（取决于网络）
- 编译 ADB：10-20 分钟
- **总计：1-2 小时**

下次修改代码时会快得多，因为只需重新编译，不需要重新同步。

### Q: 我可以只编译 adbd，不需要整个 AOSP 吗？

**A:** 不行，ADB 依赖很多 AOSP 库（libandroid-base, libc++, 等等），必须在 AOSP 环境中编译。

### Q: 如何缓存 AOSP 以加快后续编译？

**A:** 有两种方式：

1. **方案 1 & 2**：AOSP 自动保存在本地，下次编译会重用
2. **GitHub Actions**：可以添加工件缓存（需要额外配置）

### Q: 我可以交叉编译到其他架构吗？

**A:** 可以的，修改 `lunch` 命令：
- ARM64：`lunch aosp_arm64-eng`
- ARM32：`lunch aosp_arm-eng`
- x86_64：`lunch aosp_x86_64-eng`
- x86：`lunch aosp_x86-eng`

### Q: 如何只编译特定的代码而不是整个 ADB？

**A:** 使用增量编译：

```bash
# 修改代码后，只重新编译
m adbd -j$(nproc)

# 不需要重新同步 AOSP
```

### Q: 编译失败怎么办？

**A:** 按优先级检查：

1. **网络问题**
   ```bash
   ping android.googlesource.com
   ```

2. **磁盘不足**
   ```bash
   df -h /
   ```

3. **工具版本问题**
   ```bash
   java -version  # 需要 11
   python3 --version  # 需要 3.6+
   ```

4. **查看完整错误**
   - GitHub Actions：查看 Log
   - 本地：查看 `build.log`

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `.github/workflows/build-docker.yml` | GitHub Actions 编译流程 |
| `build_adb_docker.sh` | 本地 Docker 编译脚本 |
| `build_adb_local.sh` | 本地直接编译脚本 |
| `Makefile.quick` | 快速编译脚本（已弃用） |
| `build_and_upload_cache.sh` | AOSP 缓存脚本（已弃用） |

---

## 获取帮助

### 编译问题

1. 查看 GitHub Actions 日志
2. 查看本地 `build.log`
3. 在仓库创建 Issue

### 代码问题

请参考 AOSP ADB 源码：
- https://android.googlesource.com/platform/packages/modules/adb
- 文档：https://source.android.com/docs

---

## 许可证

Apache License 2.0 - 详见 NOTICE 文件

---

**更新日期**: 2024-01-11
**维护者**: Your Name
**支持的 Android 版本**: 13+
