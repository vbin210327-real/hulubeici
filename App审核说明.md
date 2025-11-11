# App审核说明 - 葫芦背词

## 关键问题：完全订阅制应用

葫芦背词的所有功能都需要订阅才能使用。为了让Apple审核人员能够测试应用，你需要在App Store Connect的审核信息中提供**沙盒测试账号**。

## 方案：使用沙盒测试账号

### 第一步：创建沙盒测试账号

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 点击右上角 "用户和访问"
3. 在左侧菜单选择 "沙盒" → "测试员"
4. 点击 "+" 按钮创建新测试员
5. 填写信息：
   - **名字**: AppReview
   - **姓氏**: Tester
   - **电子邮件**: 使用一个你能访问的测试邮箱（如 hulubeici.review@gmail.com）
     - ⚠️ 注意：不能使用真实Apple ID，必须是全新的测试邮箱
   - **密码**: 设置一个安全密码（审核人员会用这个登录）
   - **国家/地区**: 中国
   - **App Store地区**: 中国
6. 保存测试账号

### 第二步：在沙盒中订阅测试账号

由于审核人员需要看到付费功能，你需要预先在沙盒环境中为测试账号购买订阅：

1. 在iOS模拟器或测试设备上退出所有Apple ID
2. 打开你的应用
3. 进入订阅购买流程
4. 系统会提示使用沙盒测试账号登录
5. 使用刚创建的测试账号登录
6. 完成订阅购买（沙盒环境不会扣费）
7. 验证应用功能已解锁

⚠️ **重要**:
- 沙盒订阅会加速过期（如月订阅在5分钟后过期）
- 在提交审核前1-2小时再次购买订阅，确保审核期间订阅有效
- 如果需要，可以在App Review Notes中说明如何重新订阅

### 第三步：填写App Store Connect审核信息

在App Store Connect → 你的应用 → App信息 → App审核信息中填写：

#### 登录信息 (Sign-in Information)

**需要登录**: 是

**用户名**: hulubeici.review@gmail.com（你的沙盒测试账号）

**密码**: [填写你设置的密码]

#### 审核备注 (Notes)

使用以下模板（中英文双语）：

```
【订阅说明 / Subscription Information】

本应用采用完全订阅制，所有功能需要订阅后才能使用。我们已为审核团队准备沙盒测试账号。

This app requires an active subscription to access all features. We have prepared a sandbox test account for the review team.

【测试账号说明 / Test Account Instructions】

1. 应用会自动识别沙盒环境
2. 使用提供的测试账号登录后，订阅已激活
3. 如果订阅显示过期（沙盒订阅会加速过期），可以通过以下步骤重新订阅：
   - 在个人中心(Profile)点击"订阅管理"
   - 选择任意订阅套餐
   - 使用沙盒测试账号完成购买（不会产生实际费用）

1. The app automatically detects sandbox environment
2. The provided test account already has an active subscription
3. If subscription shows as expired (sandbox subscriptions expire faster), you can resubscribe by:
   - Tap "Subscription Management" in Profile tab
   - Select any subscription plan
   - Complete purchase with sandbox test account (no real charges)

【功能说明 / Feature Description】

主要功能包括：
- 多词书管理和学习
- 基于页面的学习进度追踪（每页10个单词）
- 单词显隐控制（自我测试）
- 学习统计和进度可视化
- iCloud同步（跨设备数据同步）

Main features:
- Multiple vocabulary book management and learning
- Page-based learning progress tracking (10 words per page)
- Word/meaning visibility controls (self-testing)
- Learning statistics and progress visualization
- iCloud sync (cross-device data synchronization)

【技术说明 / Technical Notes】

- iOS版本要求：17.0+
- 使用StoreKit 2进行订阅管理
- 使用CloudKit进行iCloud数据同步
- 订阅状态通过Apple Transaction API实时验证

- iOS version: 17.0+
- StoreKit 2 for subscription management
- CloudKit for iCloud data synchronization
- Subscription status verified via Apple Transaction API

【联系方式 / Contact】

如有任何问题，请联系：vbin210327@gmail.com
For any questions, please contact: vbin210327@gmail.com
```

### 第四步：可选 - 添加审核专用提示

如果你想让审核过程更顺畅，可以考虑在应用中添加一个审核环境检测提示：

在 `OnboardingView.swift` 或启动页面添加：

```swift
// 在view body中添加
#if DEBUG
if ProcessInfo.processInfo.environment["STORKIT_TEST_MODE"] != nil {
    Text("🔧 沙盒测试模式 | Sandbox Test Mode")
        .font(.caption)
        .foregroundColor(.orange)
        .padding(.top, 8)
}
#endif
```

但这不是必需的，因为沙盒账号已经有有效订阅。

## 潜在风险和应对

### 风险1：审核人员订阅过期

**问题**: 沙盒订阅在5分钟后会过期

**解决方案**:
- 在审核备注中明确说明如何重新订阅
- 提供清晰的订阅入口（个人中心 → 订阅管理）
- 确保应用在订阅过期时显示友好的订阅提示

### 风险2：被拒绝 - App功能不可测试

**问题**: Apple可能认为应用过于限制，无法评估核心功能

**解决方案**:
- 在审核备注中详细说明核心功能（已包含在上面模板中）
- 强调应用的教育价值（词汇学习）
- 如果被拒，可以考虑添加一个"演示模式"（仅供审核）

### 风险3：订阅群组准备不足

**问题**: 订阅产品未正确配置

**确认清单**:
- ✅ Plus Monthly (com.hulubeici.plus.monthly, ¥9/月) - Ready to Submit
- ✅ Pro Yearly (com.hulubeici.pro.yearly, ¥70/年) - Ready to Submit
- ✅ 订阅群组已创建并本地化
- ✅ 审核截图已上传

## 提交前检查清单

在点击"提交以供审核"前，确认：

- [ ] 沙盒测试账号已创建并记录密码
- [ ] 使用沙盒账号在应用中测试过订阅流程
- [ ] 订阅在测试中正常解锁所有功能
- [ ] App Store Connect中填写了测试账号信息
- [ ] 审核备注详细说明了订阅机制和测试步骤
- [ ] 隐私政策和服务条款链接正常访问
- [ ] 订阅产品状态均为"Ready to Submit"
- [ ] iCloud功能正常工作
- [ ] 所有截图和元数据已填写

## 时间线建议

1. **现在**: 创建沙盒测试账号
2. **归档前**: 使用沙盒账号测试订阅流程
3. **提交前1-2小时**: 重新为沙盒账号购买订阅（确保审核期间有效）
4. **提交**: 上传构建版本并提交审核
5. **审核中**: 保持邮件畅通，及时回复Apple的任何问题

## 常见问题

**Q: 沙盒测试账号需要验证邮箱吗？**
A: 不需要。沙盒账号是虚拟的，不需要邮箱验证。

**Q: 审核人员会看到真实付款吗？**
A: 不会。审核人员使用的是沙盒环境，所有交易都是模拟的。

**Q: 如果审核人员订阅过期怎么办？**
A: 在审核备注中已说明重新订阅的步骤。确保订阅入口清晰可见。

**Q: 需要为审核人员提供真实Apple ID吗？**
A: 不需要，也不应该。只提供沙盒测试账号。

---

完成以上步骤后，你的应用就可以安全地提交审核了。Apple审核团队会使用提供的沙盒账号测试所有功能。
