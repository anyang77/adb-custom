# Windows 用户快速开始指南

## 步骤 1: 检查前置要求

你需要：
- ✅ WSL2（用于 Linux 环境）
- ✅ GitHub CLI (`gh` 命令）
- ✅ ~150GB 磁盘空间

检查是否安装：
```bash
wsl --list --verbose
where gh
```

如果没有安装，先安装：
```bash
# 安装 WSL2
wsl --install -d Ubuntu

# 安装 GitHub CLI (在 PowerShell 中)
winget install GitHub.cli
```

## 步骤 2: 登录 GitHub

```bash
gh auth login
```

选择：
- GitHub.com
- HTTPS
- Y (用浏览器登录)

## 步骤 3: 生成 AOSP 缓存

在项目目录运行：
```bash
build_cache_windows.bat
```

这会：
1. 在 WSL2 中运行 Linux 命令
2. 下载 AOSP 源码（30-60 分钟）
3. 编译 ADB（10-20 分钟）
4. 创建缓存文件（10-20 分钟）
5. 上传到 GitHub Releases

**总耗时: 1-2 小时**

## 步骤 4: 验证上传

登录 GitHub，检查 Releases 是否有 `aosp-cache` 预发布版本

## 步骤 5: 之后就可以快速编译了

编辑代码后：
```bash
git add .
git commit -m "改进 ADB"
git push origin main
```

GitHub Actions 会：
- 下载缓存（5 分钟）
- 编译 ADB（10 分钟）
- 创建 Release

**总耗时: ~15 分钟**

## 常见问题

**Q: 磁盘空间不足怎么办？**
A: 需要清理出 150GB 空间。可以删除大文件如：
- 虚拟机
- 下载文件夹
- 老项目

**Q: 脚本卡住了怎么办？**
A: 按 Ctrl+C 中止，再运行一次。脚本有重试机制。

**Q: 上传失败怎么办？**
A: 手动上传：
```bash
gh release create aosp-cache C:\path\to\aosp-android13.tar.gz --prerelease
```

**Q: 多少时间会完成？**
A: 大约 1-2 小时，取决于网络速度

## 需要帮助？

查看完整日志，检查是哪个步骤失败了。
