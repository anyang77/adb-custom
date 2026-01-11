# 本地生成 AOSP 缓存并上传到 GitHub

这个脚本可以在本地一次性生成完整的 AOSP 缓存，然后上传到 GitHub，避免了 GitHub Actions 上 repo sync 的网络问题。

## 前置要求

### 1. 系统要求
- **网络**: 可靠的网络连接（下载 50+ GB）
- **磁盘**: 至少 150 GB 可用空间（AOSP 源码 + 编译输出 + 缓存包）
- **时间**: 1-2 小时（同步 + 编译 + 压缩）

### 2. 安装工具

#### Linux/macOS
```bash
# 安装 repo
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH="$HOME/bin:$PATH"

# 安装 GitHub CLI
# Linux: sudo apt install gh
# macOS: brew install gh
```

#### Windows (WSL2)
```bash
# 在 WSL2 中运行
sudo apt update
sudo apt install -y git curl python3
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

# GitHub CLI
curl -fsSL https://cli.github.com/install.sh | sudo bash
```

### 3. GitHub 认证
```bash
gh auth login
# 选择 GitHub.com
# 选择 HTTPS
# 选择 Y 使用浏览器登录
```

## 使用步骤

### 第 1 步：进入项目目录
```bash
cd /path/to/adb
```

### 第 2 步：运行缓存生成脚本
```bash
bash build_and_upload_cache.sh
```

脚本会自动：
1. ✓ 初始化 AOSP（若需要）
2. ✓ 同步源码（30-60 分钟，带重试）
3. ✓ 编译 ADB（10 分钟）
4. ✓ 生成缓存包（10-20 分钟）
5. ✓ 上传到 GitHub Releases（5-10 分钟）

**总耗时：1-2 小时（第一次）**

### 第 3 步：验证上传
访问 GitHub Releases 检查：
```
https://github.com/anyang77/adb-custom/releases
```

应该看到 `aosp-cache` 预发布版本，包含 `aosp-android13.tar.gz` 文件。

### 第 4 步：推送代码
```bash
git push origin main
```

GitHub Actions 会自动：
1. 检查缓存是否存在
2. 下载 AOSP 缓存
3. 编译 ADB
4. 创建 `v{run_number}` Release 包含 `adbd_arm64`

**之后的编译耗时：~15 分钟**

## 常见问题

### Q: 脚本卡在 "Syncing AOSP" 怎么办？

**A:** 这是正常的，repo sync 很慢。如果卡住超过 30 分钟：
1. 按 `Ctrl+C` 中断
2. 脚本会自动重试（最多 3 次）
3. 如果 3 次都失败，检查网络连接

### Q: 磁盘不足怎么办？

**A:** 需要清理空间。AOSP 的最小需求：
- 同步: 50 GB
- 编译输出: 30 GB
- 缓存包: 30 GB（临时）

**总计: ~150 GB**

可以用这个命令检查：
```bash
df -h /
```

### Q: 如何修改 ADB 代码？

**A:** 在脚本完成之前：
1. 编辑你的 ADB 源码（在当前项目中）
2. 脚本会自动复制到 AOSP 的 `packages/modules/adb`
3. 一起编译和上传缓存

### Q: 可以手动上传缓存吗？

**A:** 可以，如果脚本上传失败：
```bash
cd ~/aosp
gh release create aosp-cache aosp-android13.tar.gz \
  -R anyang77/adb-custom \
  -t "AOSP Android 13 Cache" \
  --prerelease
```

### Q: 下次能不能跳过生成缓存？

**A:** 如果缓存已经存在，GitHub Actions 会直接使用。如果需要更新缓存：
```bash
bash build_and_upload_cache.sh
```

## 脚本工作原理

```
Local:
  1. Sync AOSP (repo sync)
  2. Compile ADB (m adbd)
  3. Create cache (tar -czf)
  ↓
  Upload to GitHub Releases
  ↓
GitHub Actions (on push):
  1. Download cache (wget)
  2. Extract (tar -xzf)
  3. Compile ADB (m adbd)
  4. Create Release v{N} with adbd_arm64
```

## 下次修改 ADB 时的流程

假设你修改了 `daemon/auth.cpp`：

```bash
# 1. 编辑代码
vim daemon/auth.cpp

# 2. 提交到 git
git add daemon/auth.cpp
git commit -m "Modify auth"

# 3. 推送到 GitHub
git push origin main

# 4. GitHub Actions 自动：
#    - 下载缓存的 AOSP
#    - 编译新的 ADB
#    - 生成 Release
#
# 耗时: ~15 分钟 ✓
```

## 重要提示

⚠️ **缓存包很大 (~30 GB)**
- GitHub Releases 有存储限制
- 每次更新缓存会删除旧版本
- 建议不要频繁更新缓存

💡 **最佳实践**
1. 本地测试好 ADB 修改后再推送
2. 一次生成缓存后，就只用 GitHub Actions 快速编译
3. 如果修改了编译配置，才重新生成缓存

## 支持的平台

- ✓ Linux (Ubuntu/Debian/CentOS)
- ✓ macOS (Intel/Apple Silicon)
- ✓ Windows WSL2 (推荐)
- ✓ 其他 Unix 系统

## 需要帮助？

如果脚本出错，检查：
1. `gh auth status` - 确保已认证
2. `repo --version` - 确保已安装
3. `df -h /` - 检查磁盘空间
4. 网络连接

---

**准备好了？运行:**
```bash
bash build_and_upload_cache.sh
```
