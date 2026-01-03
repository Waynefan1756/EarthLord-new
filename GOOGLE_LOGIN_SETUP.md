# Google 登录配置说明

## 配置 URL Schemes（必须完成）

由于项目使用新版 Xcode 格式，Info.plist 配置在项目设置中。请按照以下步骤手动添加 URL Schemes：

### 步骤：

1. **在 Xcode 中打开项目**

2. **选择项目根节点**
   - 在左侧文件列表中，点击最顶部的蓝色项目图标 "EarthLord"

3. **选择 Target**
   - 在中间面板选择 "EarthLord" Target

4. **进入 Info 标签页**
   - 点击顶部的 "Info" 标签

5. **添加 URL Types**
   - 滚动到底部找到 "URL Types" 部分
   - 如果没有这个部分，点击底部的 "+" 添加一个新部分
   - 展开 "URL Types"

6. **添加新的 URL Type**
   - 点击 "+" 按钮添加新项
   - 设置以下值：
     - **Identifier**: `com.googleusercontent.apps.978524027700-8rej32bbb1otn10mis79nc9q0su0u069`
     - **URL Schemes**: `com.googleusercontent.apps.978524027700-8rej32bbb1otn10mis79nc9q0su0u069`
     - **Role**: `Editor`

### 配置截图参考：

```
URL Types
└── Item 0
    ├── Identifier: com.googleusercontent.apps.978524027700-8rej32bbb1otn10mis79nc9q0su0u069
    ├── URL Schemes
    │   └── Item 0: com.googleusercontent.apps.978524027700-8rej32bbb1otn10mis79nc9q0su0u069
    └── Role: Editor
```

### 验证配置：

配置完成后，URL Scheme 应该是：
```
com.googleusercontent.apps.978524027700-8rej32bbb1otn10mis79nc9q0su0u069
```

这个值是你的 Google Client ID 的反向格式。

---

## 代码实现说明

### 已实现的功能：

1. **AuthManager.signInWithGoogle()**
   - 完整的 Google 登录流程
   - 与 Supabase 集成
   - 详细的中文调试日志

2. **AuthView Google 登录按钮**
   - 已连接到 `signInWithGoogle()` 方法
   - 点击后会启动 Google 登录流程

### 调试日志：

执行 Google 登录时，你会在 Xcode 控制台看到以下日志：

```
🔐 开始 Google 登录流程...
✅ 成功获取根视图控制器
✅ Google 登录配置完成，Client ID: 978524027700-8rej32bbb1otn10mis79nc9q0su0u069.apps.googleusercontent.com
📱 启动 Google 登录界面...
✅ 成功获取 Google ID Token
✅ 成功获取 Google Access Token
🔄 使用 Google 令牌登录 Supabase...
✅ Supabase 登录成功
📧 用户邮箱: [用户邮箱]
✅ 成功获取用户资料
🎉 Google 登录流程完成
```

### 可能的错误：

1. **无法获取根视图控制器**
   - 检查应用是否正常运行

2. **无法获取 Google ID Token**
   - 检查 URL Schemes 配置是否正确

3. **Supabase 登录失败**
   - 检查 Supabase Google Provider 配置
   - 确认 Client ID 已添加到 Authorized Client IDs
   - 确认 Skip nonce check 已启用

---

## 测试步骤：

1. **配置 URL Schemes**（按照上面的步骤）

2. **清理并重新编译**
   ```bash
   Product -> Clean Build Folder (Shift + Command + K)
   Product -> Build (Command + B)
   ```

3. **运行应用**

4. **点击 "使用 Google 登录" 按钮**

5. **在 Google 登录页面选择账户**

6. **查看 Xcode 控制台日志**

7. **成功登录后应该看到主界面**

---

## 故障排除：

### 问题 1: 点击 Google 登录按钮没有反应
- 检查 URL Schemes 是否正确配置
- 查看 Xcode 控制台日志

### 问题 2: Google 登录页面无法打开
- 确认设备/模拟器可以访问网络
- 检查 Client ID 是否正确

### 问题 3: 登录成功但 Supabase 认证失败
- 检查 Supabase Dashboard 中 Google Provider 配置
- 确认 Authorized Client IDs 包含你的 Client ID
- 确认 Skip nonce check 已启用

---

## 重要提示：

⚠️ **URL Schemes 配置是必须的**，没有这个配置，Google 登录回调将无法工作。

⚠️ **测试时请使用真实的 Google 账号**，不要使用测试账号。

✅ **所有关键步骤都有中文日志**，方便调试。
