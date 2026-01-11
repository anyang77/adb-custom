# 🚀 上传到 GitHub - 自动编译指南

## ✅ 已完成

- ✓ 初始化 Git 仓库
- ✓ 清理垃圾文件
- ✓ 添加 GitHub Actions workflow
- ✓ 创建第一次提交

## 📤 现在上传到 GitHub

### 步骤 1️⃣ 生成 GitHub Token

1. 访问：https://github.com/settings/tokens
2. 点击 "Generate new token" → "Generate new token (classic)"
3. 配置：
   - Note: `ADB Custom Build`
   - Expiration: `90 days`
   - Scopes: 勾选 `repo` (完整仓库访问)
4. 点击 "Generate token"
5. **复制 Token**（只显示一次！）

### 步骤 2️⃣ Push 到 GitHub

执行以下命令：

```bash
cd C:\Users\Administrator\Desktop\adb

git push -u origin main
```

当提示输入凭证时：
- **Username**: `anyang77`
- **Password**: 粘贴你从步骤 1 复制的 Token

### 步骤 3️⃣ 自动编译

Push 成功后，GitHub Actions 自动运行：

1. 访问：https://github.com/anyang77/adb-custom/actions
2. 查看编译进度
3. 编译耗时：40-60 分钟

### 步骤 4️⃣ 下载编译结果

编译完成后：

1. 访问：https://github.com/anyang77/adb-custom/releases
2. 下载 `adbd-arm64` 文件
3. 部署到设备：
   ```bash
   adb push adbd-arm64 /system/bin/adbd
   adb shell chmod 755 /system/bin/adbd
   adb reboot
   ```

---

## 🎯 快速命令

```bash
# 进入目录
cd C:\Users\Administrator\Desktop\adb

# Push 到 GitHub
git push -u origin main

# 输入凭证
# Username: anyang77
# Password: <你的 GitHub Token>
```

---

## ⚠️ 常见问题

### Q: "fatal: unable to access" 错误

**A**: Token 过期或错误。重新生成 Token。

### Q: "403 Forbidden" 错误

**A**: 仓库不存在。先在 GitHub 创建 `adb-custom` 仓库。

### Q: 编译失败

**A**: 查看 Actions 日志，通常是网络问题，重新运行即可。

### Q: 多久编译完成？

**A**: 40-60 分钟（GitHub Actions 的免费额度）

---

## 📋 检查清单

- [ ] 访问 https://github.com/settings/tokens 生成 Token
- [ ] 复制 Token 到剪贴板
- [ ] 执行 `git push -u origin main`
- [ ] 输入用户名和 Token
- [ ] 访问 https://github.com/anyang77/adb-custom/actions 查看编译
- [ ] 等待 40-60 分钟
- [ ] 访问 https://github.com/anyang77/adb-custom/releases 下载 adbd

---

## 📊 编译配置

- **架构**: ARM64 (aarch64)
- **API 级别**: 30 (Android 11+)
- **修改**:
  - ✓ auth_required = false (禁用授权)
  - ✓ should_drop_privileges() = false (强制 Root)
  - ✓ 无系统属性依赖
- **输出**: adbd_arm64 (~1-3 MB)

---

## 🔗 重要链接

- **仓库**: https://github.com/anyang77/adb-custom
- **Actions**: https://github.com/anyang77/adb-custom/actions
- **Releases**: https://github.com/anyang77/adb-custom/releases
- **GitHub Tokens**: https://github.com/settings/tokens

---

## ✨ 接下来

1. 生成 GitHub Token
2. 执行 `git push -u origin main`
3. 等待自动编译完成
4. 下载编译好的 adbd
5. 部署到设备

**现在就开始吧！** 👈
