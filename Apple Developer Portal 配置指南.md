# Apple Developer Portal 配置指南

本指南将帮助您在 Apple Developer Portal 中配置葫芦背词所需的 iCloud Container 和相关证书。

---

## 前提条件

- ✅ 拥有 Apple Developer 账号（个人或公司）
- ✅ 已支付年度会员费用（$99 或 ¥688）
- ✅ 已登录 Apple Developer Portal

---

## 步骤 1：登录 Apple Developer Portal

1. 访问 [developer.apple.com/account](https://developer.apple.com/account)
2. 使用您的 Apple ID 登录
3. 进入 **"Certificates, Identifiers & Profiles"**（证书、标识符和描述文件）

---

## 步骤 2：创建/确认 App ID

### 2.1 检查 App ID 是否已存在

1. 点击左侧 **"Identifiers"**（标识符）
2. 在列表中查找 `com.hulubeici`

### 2.2 如果不存在，创建新的 App ID

1. 点击右上角 **"+"** 按钮
2. 选择 **"App IDs"**，点击 **"Continue"**
3. 选择 **"App"**，点击 **"Continue"**

4. **填写 App ID 信息**：

   - **Description**（描述）：`Hulu Beici`
     - 这是您看到的名称，可以随意填写

   - **Bundle ID**（套装 ID）：选择 **"Explicit"**
     - 填写：`com.hulubeici`
     - ⚠️ **重要**：必须与 Xcode 项目中的 Bundle ID 完全一致
     - ⚠️ **注意**：创建后无法修改！

5. **勾选 Capabilities**（功能）：

   必须勾选：
   - ✅ **iCloud**
     - 勾选 **"Include CloudKit support"**
   - ✅ **Push Notifications**（如果使用推送通知）
   - ✅ **In-App Purchase**（应用内购买）
   - ✅ **Sign in with Apple**（如果使用）

6. 点击 **"Continue"**
7. 检查信息无误后，点击 **"Register"**

### 2.3 如果已存在，编辑 App ID

1. 点击 App ID `com.hulubeici`
2. 向下滚动到 **"Capabilities"** 部分
3. 确保勾选：
   - ✅ iCloud（包含 CloudKit support）
   - ✅ Push Notifications
   - ✅ In-App Purchase
4. 点击 **"Save"**

---

## 步骤 3：创建 iCloud Container

### 3.1 进入 Containers 页面

1. 点击左侧 **"Identifiers"**
2. 在顶部下拉菜单中选择 **"iCloud Containers"**
3. 点击右上角 **"+"** 按钮

### 3.2 填写 iCloud Container 信息

- **Description**（描述）：`Hulu Beici iCloud Container`
  - 这是您看到的名称，可以随意填写

- **Identifier**（标识符）：`iCloud.com.hulubeici`
  - ⚠️ **重要**：必须以 `iCloud.` 开头
  - ⚠️ **重要**：后缀必须与代码中的 `iCloudContainerID` 完全一致
  - ⚠️ **注意**：创建后无法修改！

### 3.3 完成创建

1. 点击 **"Continue"**
2. 检查信息无误后，点击 **"Register"**
3. iCloud Container 创建成功！

---

## 步骤 4：关联 iCloud Container 到 App ID

### 4.1 返回 App IDs 页面

1. 点击左侧 **"Identifiers"**
2. 在顶部下拉菜单中选择 **"App IDs"**
3. 点击 `com.hulubeici`

### 4.2 配置 iCloud

1. 找到 **"iCloud"** 选项
2. 确保已勾选
3. 点击右侧的 **"Edit"**（编辑）或 **"Configure"**（配置）按钮

4. 在弹出的窗口中：
   - 选择 **"Include CloudKit support"**
   - 在 **"Containers"** 列表中，勾选 `iCloud.com.hulubeici`
   - 点击 **"Save"**

5. 返回 App ID 详情页，点击右上角 **"Save"**

---

## 步骤 5：创建/更新 Provisioning Profile

### 5.1 什么是 Provisioning Profile？

Provisioning Profile 是一个配置文件，包含：
- App ID
- 证书（Certificate）
- 设备列表（Development）
- 权限配置（Entitlements）

### 5.2 创建 Development Profile（用于开发测试）

1. 点击左侧 **"Profiles"**（描述文件）
2. 点击右上角 **"+"** 按钮
3. 选择 **"iOS App Development"**，点击 **"Continue"**

4. **选择 App ID**：
   - 选择 `com.hulubeici`
   - 点击 **"Continue"**

5. **选择证书**：
   - 勾选您的开发证书
   - 如果没有证书，需要先创建一个
   - 点击 **"Continue"**

6. **选择设备**：
   - 勾选您要测试的设备
   - 或选择 **"Select All"**
   - 点击 **"Continue"**

7. **命名 Profile**：
   - 填写名称：`Hulu Beici Development`
   - 点击 **"Generate"**

8. **下载 Profile**：
   - 点击 **"Download"**
   - 双击下载的 `.mobileprovision` 文件安装到 Xcode

### 5.3 创建 Distribution Profile（用于 App Store）

重复上述步骤，但选择：
- **Profile 类型**：**"App Store"**（而不是 iOS App Development）
- **证书类型**：选择您的 Distribution 证书
- **Profile 名称**：`Hulu Beici App Store`

---

## 步骤 6：更新 Xcode 项目配置

### 6.1 打开 Xcode 项目

1. 打开 `葫芦背词.xcodeproj`
2. 选择项目导航器中的项目根节点
3. 选择 **"葫芦背词"** target

### 6.2 配置 Signing & Capabilities

1. 点击 **"Signing & Capabilities"** 标签页

2. **Automatically manage signing**（自动管理签名）：
   - 如果勾选：Xcode 会自动下载和管理 Profile
   - 如果不勾选：需要手动选择 Provisioning Profile

3. **Team**：
   - 选择您的 Apple Developer Team

4. **Bundle Identifier**：
   - 确认显示为 `com.hulubeici`

5. **Provisioning Profile**（如果手动管理）：
   - Debug：选择 `Hulu Beici Development`
   - Release：选择 `Hulu Beici App Store`

### 6.3 验证 iCloud 配置

1. 在 **"Signing & Capabilities"** 标签页
2. 确认有 **"iCloud"** 功能卡片
3. 如果没有，点击 **"+ Capability"**，添加 **"iCloud"**

4. 在 iCloud 卡片中：
   - 勾选 **"CloudKit"**
   - 在 **"Containers"** 列表中，应该显示 `iCloud.com.hulubeici`
   - 确保已勾选

5. 如果看到红色错误或警告：
   - 点击 **"Fix Issue"** 按钮
   - 或手动点击 **"Refresh"** 刷新

### 6.4 验证 Push Notifications

1. 确认有 **"Push Notifications"** 功能卡片
2. 如果没有，点击 **"+ Capability"**，添加 **"Push Notifications"**

### 6.5 验证 In-App Purchase

1. 确认有 **"In-App Purchase"** 功能卡片
2. 如果没有，点击 **"+ Capability"**，添加 **"In-App Purchase"**

---

## 步骤 7：测试 iCloud 同步

### 7.1 在真机上测试

1. 将 iPhone/iPad 连接到 Mac
2. 在 Xcode 中选择您的设备
3. 点击 **"Run"**（▶️）构建并运行

4. 打开 App，检查：
   - 能否正常启动
   - 添加一个自定义单词本
   - 等待几秒，查看是否同步到 iCloud

### 7.2 验证 iCloud 同步

**在 iPhone 上**：

1. 打开 **"设置"**
2. 点击顶部的 **[您的姓名]**
3. 点击 **"iCloud"**
4. 滚动到底部，点击 **"管理储存空间"**
5. 找到 **"葫芦背词"**
6. 检查是否有数据占用（应该有几 KB）

**在 Xcode 控制台**：

查找以下日志：
```
[iCloud] Uploaded data successfully
[iCloud] Pull completed: found 1 record(s)
```

如果看到错误：
```
[iCloud] Failed to upload: ...
```
请检查：
- iCloud Container 是否正确创建
- App ID 是否正确关联
- 设备是否登录了 iCloud 账号

---

## 步骤 8：配置 Push Notifications（可选）

如果您计划使用推送通知：

### 8.1 创建 APNs 证书/密钥

**方法 1：使用 APNs Authentication Key（推荐）**

1. 在 Developer Portal，点击左侧 **"Keys"**（密钥）
2. 点击右上角 **"+"** 按钮
3. **Key Name**：`Hulu Beici APNs Key`
4. 勾选 **"Apple Push Notifications service (APNs)"**
5. 点击 **"Continue"** → **"Register"**
6. **下载密钥文件**（`.p8`）
   - ⚠️ **重要**：只能下载一次，请妥善保管
7. 记录 **Key ID** 和 **Team ID**

**方法 2：使用 APNs SSL 证书**

1. 点击左侧 **"Certificates"**（证书）
2. 点击右上角 **"+"** 按钮
3. 选择 **"Apple Push Notification service SSL (Sandbox & Production)"**
4. 选择 App ID：`com.hulubeici`
5. 上传 CSR（证书签名请求）文件
6. 下载并安装证书

---

## 步骤 9：常见问题排查

### Q1: Xcode 提示 "Failed to create provisioning profile"

**原因**：
- App ID 配置不正确
- 没有勾选 iCloud 或 Push Notifications
- Team 选择错误

**解决方案**：
1. 检查 Developer Portal 中的 App ID 配置
2. 确保所有必需的 Capabilities 已启用
3. 在 Xcode 中点击 **"Try Again"** 或 **"Fix Issue"**
4. 如果还不行，取消勾选 **"Automatically manage signing"**，手动选择 Profile

### Q2: iCloud 同步失败

**可能原因**：
- iCloud Container 未创建或标识符不匹配
- App ID 未关联 iCloud Container
- 设备未登录 iCloud
- 代码中的 Container ID 与 Portal 不一致

**解决方案**：
1. 确认 Container ID：代码中 `iCloudContainerID = "iCloud.com.hulubeici"`
2. 确认 Portal 中的 Container 标识符完全一致
3. 确认 App ID 已关联此 Container
4. 在设备设置中检查 iCloud 登录状态

### Q3: 订阅功能无法使用

**可能原因**：
- App ID 未启用 In-App Purchase
- 未在 App Store Connect 创建订阅产品
- Product ID 不匹配

**解决方案**：
1. 确认 App ID 已勾选 **"In-App Purchase"**
2. 在 App Store Connect 创建订阅产品（参见另一份指南）
3. 确认代码中的 Product ID 与 App Store Connect 一致

### Q4: 真机运行失败，提示签名错误

**解决方案**：
1. 在 Xcode 中删除旧的 Provisioning Profile：
   ```
   ~/Library/MobileDevice/Provisioning Profiles/
   ```
2. 重新下载 Profile
3. 清理项目：Product → Clean Build Folder (⇧⌘K)
4. 重新构建

### Q5: "You don't have permission to access this resource"

**原因**：您的 Apple Developer 账号权限不足

**解决方案**：
- 如果是公司账号，联系账号持有人（Account Holder）授予权限
- 需要的权限：App Manager 或 Admin

---

## 步骤 10：检查清单

在继续上架前，请确认：

### Developer Portal 配置

- ✅ App ID `com.hulubeici` 已创建
- ✅ 已启用 iCloud（包含 CloudKit）
- ✅ 已启用 Push Notifications
- ✅ 已启用 In-App Purchase
- ✅ iCloud Container `iCloud.com.hulubeici` 已创建
- ✅ iCloud Container 已关联到 App ID
- ✅ Development Provisioning Profile 已创建并下载
- ✅ Distribution Provisioning Profile 已创建并下载

### Xcode 配置

- ✅ Bundle ID 为 `com.hulubeici`
- ✅ Team 已选择
- ✅ Provisioning Profile 已配置
- ✅ iCloud Capability 已添加，Container 已勾选
- ✅ Push Notifications Capability 已添加
- ✅ In-App Purchase Capability 已添加
- ✅ Entitlements 文件中 aps-environment 为 `production`

### 测试验证

- ✅ App 可以在真机上运行
- ✅ iCloud 同步功能正常（可在设置中查看 iCloud 存储）
- ✅ 订阅购买流程可以触发（沙盒测试）
- ✅ 没有签名或权限相关的错误

---

## 下一步

完成 Developer Portal 配置后，您需要：

1. ✅ 在 App Store Connect 创建订阅产品（参见《App Store Connect 订阅配置指南》）
2. ✅ 准备 App 截图和描述
3. ✅ Archive 并上传 App 到 App Store Connect
4. ✅ 提交审核

---

## 有用的链接

- [Apple Developer Portal](https://developer.apple.com/account)
- [iCloud 配置文档](https://developer.apple.com/documentation/cloudkit/setting_up_cloudkit)
- [App ID 配置指南](https://developer.apple.com/help/account/manage-identifiers/register-an-app-id/)
- [Provisioning Profile 指南](https://developer.apple.com/help/account/manage-profiles/create-a-development-provisioning-profile/)
- [证书管理](https://developer.apple.com/help/account/create-certificates/)

---

**祝您配置顺利！🎉**

如有问题，请参考 Apple 官方文档或联系 Apple Developer 技术支持。
