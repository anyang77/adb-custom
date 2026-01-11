# 快速参考指南

## 三行快速开始

```bash
# 选择一个方式编译
bash build_adb_docker.sh      # Docker 方式（推荐）
bash build_adb_local.sh       # 本地方式

# 或者推送代码让 GitHub Actions 编译
git push origin main
```

## 编译方式选择

| 条件 | 推荐方式 |
|------|---------|
| 首次编译，无本地环境 | ☁️ GitHub Actions |
| 有 Docker 环境 | 🐳 Docker 编译 |
| 本地已有 AOSP/NDK | 🖥️ 本地编译 |
| 频繁修改代码调试 | 🖥️ 本地编译 |

## 文件速查

| 文件 | 用途 |
|------|------|
| `.github/workflows/build.yml` | GitHub Actions 编译配置 |
| `build_adb_docker.sh` | Docker 编译脚本 |
| `build_adb_local.sh` | 本地编译脚本 |
| `BUILD_GUIDE.md` | 完整编译指南 |
| `build.config` | 编译参数配置 |

## 常见命令

```bash
# 编译
bash build_adb_docker.sh

# 查看帮助
cat BUILD_GUIDE.md | less

# 查看编译日志
tail -f build.log

# 清理编译文件
rm -rf adbd_arm64 build.log

# 推送到设备
adb push adbd_arm64 /data/local/tmp/
adb shell chmod 755 /data/local/tmp/adbd_arm64
adb shell /data/local/tmp/adbd_arm64 --version
```

## 编译流程

```
修改代码
   ↓
提交 git
   ↓
选择编译方式
   ├─ push → GitHub Actions（推荐）
   ├─ bash build_adb_docker.sh（有 Docker）
   └─ bash build_adb_local.sh（本地环境）
   ↓
等待完成（1-2 小时）
   ↓
下载 adbd_arm64
   ↓
推送到设备
```

## 时间预估

| 操作 | 时间 | 备注 |
|------|------|------|
| AOSP 同步 | 30-60 min | 首次最长 |
| 编译 | 10-20 min | 取决于代码改动 |
| **总计** | **1-2 小时** | 首次 |
| 增量编译 | 10-30 min | 只改了代码 |

## 故障排查

**编译失败？**

1. 检查日志：查看 build.log 最后 50 行
2. 检查空间：`df -h` 至少需要 100GB
3. 检查网络：`ping android.googlesource.com`
4. 重新同步：删除 `~/aosp/.repo` 重新开始

**二进制不工作？**

1. 验证架构：`file adbd_arm64` 应显示 ARM64
2. 查看依赖：`readelf -d adbd_arm64`
3. 测试运行：`/data/local/tmp/adbd_arm64 --version`
4. 检查权限：`adb shell ls -l /system/bin/adbd`

## 性能优化

```bash
# 加速编译（使用 ccache）
export USE_CCACHE=1

# 并行编译（更多线程）
m adbd -j16

# 清理后编译
m adbd -j$(nproc) 2>&1 | tee build.log
```

## 版本控制

```bash
# 自动版本号
git tag v1.0.0
git push origin v1.0.0

# 查看历史编译
gh release list

# 下载特定版本
gh release download v1.0.0 -p adbd_arm64
```

## 更多帮助

- 完整指南：`cat BUILD_GUIDE.md`
- 编译配置：`cat build.config`
- GitHub Actions 日志：进入 Actions 标签查看详细日志
- 本地日志：`tail -f build.log`

---

**最后更新**: 2024-01-11
**维护者**: Build System
**支持平台**: Linux, macOS, WSL2, GitHub Actions
