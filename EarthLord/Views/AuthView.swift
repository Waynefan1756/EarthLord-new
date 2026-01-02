//
//  AuthView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/2.
//

import SwiftUI

enum AuthTab {
    case login
    case register
}

enum ForgotPasswordStep {
    case sendOTP
    case verifyOTP
    case setPassword
}

struct AuthView: View {
    // MARK: - State

    @StateObject private var authManager: AuthManager
    @State private var selectedTab: AuthTab = .login
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var otpCode: String = ""

    // 忘记密码
    @State private var showForgotPassword: Bool = false
    @State private var forgotPasswordStep: ForgotPasswordStep = .sendOTP
    @State private var forgotPasswordEmail: String = ""
    @State private var forgotPasswordOTP: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""

    // 倒计时
    @State private var countdown: Int = 0
    @State private var timer: Timer? = nil

    // Toast提示
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    // MARK: - Initialization

    init(authManager: AuthManager) {
        _authManager = StateObject(wrappedValue: authManager)
    }

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    ApocalypseTheme.background,
                    ApocalypseTheme.cardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // Logo 和标题
                    VStack(spacing: 16) {
                        Image(systemName: "globe.asia.australia.fill")
                            .font(.system(size: 80))
                            .foregroundColor(ApocalypseTheme.primary)
                            .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                        Text("地球新主")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.top, 60)

                    // Tab 切换
                    HStack(spacing: 0) {
                        TabButton(
                            title: "登录",
                            isSelected: selectedTab == .login
                        ) {
                            withAnimation {
                                selectedTab = .login
                                resetFields()
                            }
                        }

                        TabButton(
                            title: "注册",
                            isSelected: selectedTab == .register
                        ) {
                            withAnimation {
                                selectedTab = .register
                                resetFields()
                            }
                        }
                    }
                    .padding(.horizontal, 40)

                    // 内容区域
                    if selectedTab == .login {
                        loginView
                    } else {
                        registerView
                    }

                    // 分隔线
                    HStack {
                        Rectangle()
                            .fill(ApocalypseTheme.textMuted.opacity(0.3))
                            .frame(height: 1)

                        Text("或者使用以下方式登录")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .padding(.horizontal, 12)

                        Rectangle()
                            .fill(ApocalypseTheme.textMuted.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                    // 第三方登录
                    VStack(spacing: 12) {
                        // Apple 登录
                        Button(action: {
                            showToastMessage("Apple 登录即将开放")
                        }) {
                            HStack {
                                Image(systemName: "apple.logo")
                                    .font(.title3)
                                Text("使用 Apple 登录")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                        }

                        // Google 登录
                        Button(action: {
                            showToastMessage("Google 登录即将开放")
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                Text("使用 Google 登录")
                                    .font(.headline)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }

            // Loading 遮罩
            if authManager.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }

            // Toast 提示
            if showToast {
                VStack {
                    Spacer()

                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordView
        }
        .onChange(of: authManager.errorMessage) { _, newValue in
            if let error = newValue {
                showToastMessage(error)
            }
        }
    }

    // MARK: - 登录视图

    private var loginView: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $email,
                keyboardType: .emailAddress
            )

            // 密码输入
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $password
            )

            // 登录按钮
            Button(action: performLogin) {
                Text("登录")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)
            }
            .disabled(email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)

            // 忘记密码
            Button(action: {
                showForgotPassword = true
                forgotPasswordStep = .sendOTP
            }) {
                Text("忘记密码？")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 注册视图

    private var registerView: some View {
        VStack(spacing: 20) {
            if !authManager.otpSent {
                // 第一步：输入邮箱
                registerStep1
            } else if authManager.otpSent && !authManager.otpVerified {
                // 第二步：验证OTP
                registerStep2
            } else if authManager.otpVerified && authManager.needsPasswordSetup {
                // 第三步：设置密码
                registerStep3
            }
        }
        .padding(.horizontal, 40)
    }

    // 注册第一步：邮箱输入
    private var registerStep1: some View {
        VStack(spacing: 20) {
            Text("第一步：输入邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $email,
                keyboardType: .emailAddress
            )

            Button(action: sendRegisterOTP) {
                Text("发送验证码")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)
            }
            .disabled(email.isEmpty)
            .opacity(email.isEmpty ? 0.6 : 1.0)
        }
    }

    // 注册第二步：验证码输入
    private var registerStep2: some View {
        VStack(spacing: 20) {
            Text("第二步：验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("验证码已发送至 \(email)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $otpCode,
                keyboardType: .numberPad
            )

            Button(action: verifyRegisterOTP) {
                Text("验证")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)
            }
            .disabled(otpCode.count != 6)
            .opacity(otpCode.count != 6 ? 0.6 : 1.0)

            // 重发倒计时
            if countdown > 0 {
                Text("重新发送 (\(countdown)s)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button(action: sendRegisterOTP) {
                    Text("重新发送")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // 注册第三步：设置密码
    private var registerStep3: some View {
        VStack(spacing: 20) {
            Text("第三步：设置密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("请设置您的登录密码")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $password
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $confirmPassword
            )

            // 密码匹配提示
            if !password.isEmpty && !confirmPassword.isEmpty {
                HStack {
                    Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(password == confirmPassword ? ApocalypseTheme.success : ApocalypseTheme.danger)
                    Text(password == confirmPassword ? "密码匹配" : "密码不匹配")
                        .font(.caption)
                        .foregroundColor(password == confirmPassword ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: completeRegistration) {
                Text("完成注册")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.success,
                                ApocalypseTheme.success.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: ApocalypseTheme.success.opacity(0.3), radius: 10)
            }
            .disabled(!isPasswordValid)
            .opacity(isPasswordValid ? 1.0 : 0.6)
        }
    }

    // MARK: - 忘记密码视图

    private var forgotPasswordView: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    if forgotPasswordStep == .sendOTP {
                        forgotPasswordStep1View
                    } else if forgotPasswordStep == .verifyOTP {
                        forgotPasswordStep2View
                    } else {
                        forgotPasswordStep3View
                    }

                    Spacer()
                }
                .padding(40)

                if authManager.isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("忘记密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showForgotPassword = false
                        resetForgotPasswordFields()
                    }
                }
            }
        }
    }

    // 忘记密码第一步
    private var forgotPasswordStep1View: some View {
        VStack(spacing: 20) {
            Text("请输入您的注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱",
                text: $forgotPasswordEmail,
                keyboardType: .emailAddress
            )

            Button(action: sendResetPasswordOTP) {
                Text("发送验证码")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(forgotPasswordEmail.isEmpty)
            .opacity(forgotPasswordEmail.isEmpty ? 0.6 : 1.0)
        }
    }

    // 忘记密码第二步
    private var forgotPasswordStep2View: some View {
        VStack(spacing: 20) {
            Text("验证码已发送至 \(forgotPasswordEmail)")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $forgotPasswordOTP,
                keyboardType: .numberPad
            )

            Button(action: verifyResetPasswordOTP) {
                Text("验证")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(forgotPasswordOTP.count != 6)
            .opacity(forgotPasswordOTP.count != 6 ? 0.6 : 1.0)

            if countdown > 0 {
                Text("重新发送 (\(countdown)s)")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button(action: sendResetPasswordOTP) {
                    Text("重新发送")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // 忘记密码第三步
    private var forgotPasswordStep3View: some View {
        VStack(spacing: 20) {
            Text("请设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $newPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $confirmNewPassword
            )

            if !newPassword.isEmpty && !confirmNewPassword.isEmpty {
                HStack {
                    Image(systemName: newPassword == confirmNewPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(newPassword == confirmNewPassword ? ApocalypseTheme.success : ApocalypseTheme.danger)
                    Text(newPassword == confirmNewPassword ? "密码匹配" : "密码不匹配")
                        .font(.caption)
                        .foregroundColor(newPassword == confirmNewPassword ? ApocalypseTheme.success : ApocalypseTheme.danger)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: resetPassword) {
                Text("重置密码")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.success,
                                ApocalypseTheme.success.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(!isNewPasswordValid)
            .opacity(isNewPasswordValid ? 1.0 : 0.6)
        }
    }

    // MARK: - Actions

    private func performLogin() {
        Task {
            await authManager.signIn(email: email, password: password)
        }
    }

    private func sendRegisterOTP() {
        Task {
            await authManager.signUpWithOTP(email: email)
            if authManager.otpSent {
                startCountdown()
            }
        }
    }

    private func verifyRegisterOTP() {
        Task {
            await authManager.verifyOTP(email: email, otp: otpCode)
        }
    }

    private func completeRegistration() {
        guard isPasswordValid else { return }

        Task {
            await authManager.setupPassword(password)
        }
    }

    private func sendResetPasswordOTP() {
        Task {
            await authManager.resetPassword(email: forgotPasswordEmail)
            if authManager.otpSent {
                forgotPasswordStep = .verifyOTP
                startCountdown()
            }
        }
    }

    private func verifyResetPasswordOTP() {
        Task {
            await authManager.verifyResetOTP(email: forgotPasswordEmail, otp: forgotPasswordOTP)
            if authManager.otpVerified {
                forgotPasswordStep = .setPassword
            }
        }
    }

    private func resetPassword() {
        guard isNewPasswordValid else { return }

        Task {
            await authManager.updatePassword(newPassword)
            if authManager.isAuthenticated {
                showForgotPassword = false
                resetForgotPasswordFields()
                showToastMessage("密码重置成功")
            }
        }
    }

    // MARK: - Helper Functions

    private func resetFields() {
        email = ""
        password = ""
        confirmPassword = ""
        otpCode = ""
        authManager.errorMessage = nil
    }

    private func resetForgotPasswordFields() {
        forgotPasswordEmail = ""
        forgotPasswordOTP = ""
        newPassword = ""
        confirmNewPassword = ""
        forgotPasswordStep = .sendOTP
    }

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    private var isPasswordValid: Bool {
        password.count >= 6 && password == confirmPassword
    }

    private var isNewPasswordValid: Bool {
        newPassword.count >= 6 && newPassword == confirmNewPassword
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)

                Rectangle()
                    .fill(isSelected ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Custom TextField

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Custom Secure Field

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            SecureField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    AuthView(authManager: AuthManager(supabase: supabase))
}
