//
//  AuthManager.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/2.
//

import Foundation
import Combine
import Supabase
import GoogleSignIn

@MainActor
class AuthManager: ObservableObject {
    // MARK: - Published Properties

    /// 已登录且完成所有流程
    @Published var isAuthenticated: Bool = false

    /// OTP验证后需要设置密码
    @Published var needsPasswordSetup: Bool = false

    /// 当前用户
    @Published var currentUser: User? = nil

    /// 当前用户邮箱
    @Published var currentUserEmail: String? = nil

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// 验证码已发送
    @Published var otpSent: Bool = false

    /// 验证码已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    /// 正在重置密码流程中
    @Published var isResettingPassword: Bool = false

    // MARK: - Private Properties

    private let supabase: SupabaseClient
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase

        // 检查当前会话状态
        Task {
            await checkSession()
            await listenToAuthStateChanges()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Session Management

    /// 检查当前会话
    func checkSession() async {
        do {
            let session = try await supabase.auth.session

            // 获取用户邮箱
            currentUserEmail = session.user.email

            // 获取用户资料
            if let user = try? await fetchUserProfile(userId: session.user.id) {
                currentUser = user
                isAuthenticated = true
                needsPasswordSetup = false
            }
        } catch {
            // 没有会话，保持未登录状态
            isAuthenticated = false
            currentUser = nil
            currentUserEmail = nil
        }
    }

    /// 监听认证状态变化
    private func listenToAuthStateChanges() async {
        authStateTask = Task {
            for await state in await supabase.auth.authStateChanges {
                guard !Task.isCancelled else { return }

                switch state.event {
                case .signedIn:
                    // 用户登录
                    if let userId = state.session?.user.id {
                        if let user = try? await fetchUserProfile(userId: userId) {
                            await MainActor.run {
                                currentUser = user
                                currentUserEmail = state.session?.user.email

                                // 如果正在重置密码流程中，不设置为已认证
                                if !isResettingPassword {
                                    isAuthenticated = true
                                    needsPasswordSetup = false
                                }
                            }
                        }
                    }

                case .signedOut:
                    // 用户登出
                    await MainActor.run {
                        isAuthenticated = false
                        currentUser = nil
                        currentUserEmail = nil
                        needsPasswordSetup = false
                        otpSent = false
                        otpVerified = false
                        isResettingPassword = false
                    }

                case .tokenRefreshed:
                    // Token 刷新，保持当前状态
                    break

                case .passwordRecovery:
                    // 密码恢复
                    break

                case .userUpdated:
                    // 用户信息更新
                    if let userId = state.session?.user.id {
                        if let user = try? await fetchUserProfile(userId: userId) {
                            await MainActor.run {
                                currentUser = user
                            }
                        }
                    }

                default:
                    break
                }
            }
        }
    }

    /// 获取用户资料
    private func fetchUserProfile(userId: UUID) async throws -> User {
        let profile: User = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return profile
    }

    // MARK: - 注册流程

    /// 1. 发送注册验证码
    func signUpWithOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: nil
            )

            otpSent = true
        } catch {
            errorMessage = "发送验证码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 2. 验证OTP（此时已登录但没密码）
    func verifyOTP(email: String, otp: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: otp,
                type: .email
            )

            // 验证成功，用户已登录
            otpVerified = true
            needsPasswordSetup = true
            isAuthenticated = false  // 必须设置密码后才算完成认证

            // 尝试获取用户资料（可能还没创建）
            if let user = try? await fetchUserProfile(userId: session.user.id) {
                currentUser = user
            }

        } catch {
            errorMessage = "验证码错误或已过期：\(error.localizedDescription)"
            otpVerified = false
        }

        isLoading = false
    }

    /// 3. 设置密码（注册流程强制步骤）
    func setupPassword(_ password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 获取当前会话
            let session = try await supabase.auth.session

            // 获取用户资料
            if let user = try? await fetchUserProfile(userId: session.user.id) {
                currentUser = user
            }

            // 完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false
            otpSent = false

        } catch {
            errorMessage = "设置密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 登录流程

    /// 邮箱 + 密码登录
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        print("🔐 开始登录流程...")
        print("📧 邮箱: \(email)")

        do {
            print("📡 正在连接 Supabase...")
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            print("✅ Supabase 认证成功")
            print("🆔 用户 ID: \(session.user.id)")

            // 获取用户资料
            print("📋 正在获取用户资料...")
            if let user = try? await fetchUserProfile(userId: session.user.id) {
                currentUser = user
                print("✅ 用户资料获取成功")
            } else {
                print("⚠️ 用户资料不存在（profiles 表中没有记录）")
            }

            isAuthenticated = true
            needsPasswordSetup = false
            print("🎉 登录流程完成")

        } catch let error as NSError {
            print("❌ 登录失败")
            print("❌ 错误域: \(error.domain)")
            print("❌ 错误代码: \(error.code)")
            print("❌ 错误描述: \(error.localizedDescription)")
            print("❌ 错误详情: \(error)")
            errorMessage = "登录失败：\(error.localizedDescription)"
            isAuthenticated = false
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 1. 发送重置密码验证码
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 使用 OTP 方式发送验证码（而不是重置链接）
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: nil
            )
            otpSent = true
        } catch {
            errorMessage = "发送重置密码验证码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 2. 验证重置密码OTP（此时已登录）
    func verifyResetOTP(email: String, otp: String) async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await supabase.auth.verifyOTP(
                email: email,
                token: otp,
                type: .email  // 使用 email 类型（与 signInWithOTP 对应）
            )

            otpVerified = true
            isResettingPassword = true  // 标记正在重置密码
            isAuthenticated = false     // 需要设置新密码才算完成

        } catch {
            errorMessage = "验证码错误或已过期：\(error.localizedDescription)"
            otpVerified = false
            isResettingPassword = false
        }

        isLoading = false
    }

    /// 3. 更新新密码
    func updatePassword(_ newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 获取当前会话
            let session = try await supabase.auth.session

            // 获取用户资料
            if let user = try? await fetchUserProfile(userId: session.user.id) {
                currentUser = user
            }

            // 完成密码重置
            isResettingPassword = false  // 重置密码流程完成
            isAuthenticated = true
            otpVerified = false
            otpSent = false

        } catch {
            errorMessage = "更新密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 退出登录

    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            isResettingPassword = false

        } catch {
            errorMessage = "退出登录失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 删除账户

    /// 删除用户账户（调用边缘函数）
    func deleteAccount() async throws {
        print("📱 开始删除账户流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前会话的 access token
            let session = try await supabase.auth.session
            let accessToken = session.accessToken
            print("✅ 成功获取访问令牌")

            // 构建请求 URL
            guard let url = URL(string: "https://mlxrahhsuulzrssjtafq.supabase.co/functions/v1/delete-account") else {
                print("❌ 无法构建请求 URL")
                throw NSError(domain: "DeleteAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
            }
            print("🌐 请求 URL: \(url.absoluteString)")

            // 创建请求
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            print("📤 准备发送删除请求...")

            // 发送请求
            let (data, response) = try await URLSession.shared.data(for: request)

            // 检查响应
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的 HTTP 响应")
                throw NSError(domain: "DeleteAccount", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
            }

            print("📥 收到响应，状态码: \(httpResponse.statusCode)")

            // 解析响应数据
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 响应内容: \(responseString)")
            }

            // 检查状态码
            guard httpResponse.statusCode == 200 else {
                // 尝试解析错误信息
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    print("❌ 删除账户失败: \(error)")
                    throw NSError(domain: "DeleteAccount", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: error])
                }
                print("❌ 删除账户失败，状态码: \(httpResponse.statusCode)")
                throw NSError(domain: "DeleteAccount", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "删除账户失败"])
            }

            print("✅ 账户删除成功")

            // 删除成功后，清空本地状态
            await MainActor.run {
                isAuthenticated = false
                needsPasswordSetup = false
                currentUser = nil
                currentUserEmail = nil
                otpSent = false
                otpVerified = false
                isResettingPassword = false
                isLoading = false
            }

            print("🎉 删除账户流程完成")

        } catch {
            print("❌ 删除账户时发生错误: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "删除账户失败：\(error.localizedDescription)"
                isLoading = false
            }
            throw error
        }
    }

    // MARK: - 第三方登录（占位）

    /// Apple 登录（待实现）
    func signInWithApple() async {
        errorMessage = "Apple 登录功能开发中..."
    }

    /// Google 登录
    func signInWithGoogle() async {
        print("🔐 开始 Google 登录流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 获取根视图控制器
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ 无法获取根视图控制器")
                throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取视图控制器"])
            }
            print("✅ 成功获取根视图控制器")

            // 配置 Google 登录
            let clientID = "978524027700-8rej32bbb1otn10mis79nc9q0su0u069.apps.googleusercontent.com"
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            print("✅ Google 登录配置完成，Client ID: \(clientID)")

            // 执行 Google 登录
            print("📱 启动 Google 登录界面...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ 无法获取 ID Token")
                throw NSError(domain: "GoogleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法获取 Google ID Token"])
            }
            print("✅ 成功获取 Google ID Token")

            let accessToken = result.user.accessToken.tokenString
            print("✅ 成功获取 Google Access Token")

            // 使用 Google ID Token 登录 Supabase
            print("🔄 使用 Google 令牌登录 Supabase...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            print("✅ Supabase 登录成功")

            // 获取用户邮箱
            currentUserEmail = session.user.email
            print("📧 用户邮箱: \(currentUserEmail ?? "未设置")")

            // 获取或创建用户资料
            if let user = try? await fetchUserProfile(userId: session.user.id) {
                print("✅ 成功获取用户资料")
                currentUser = user
            } else {
                print("⚠️ 用户资料不存在，可能需要创建")
                // 如果 profiles 表中没有记录，这里可以选择创建
            }

            // 设置认证状态
            isAuthenticated = true
            needsPasswordSetup = false
            print("🎉 Google 登录流程完成")

        } catch let error as NSError {
            print("❌ Google 登录失败: \(error.localizedDescription)")
            if error.domain == "com.google.GIDSignIn" && error.code == -5 {
                // 用户取消登录
                errorMessage = "已取消 Google 登录"
                print("ℹ️ 用户取消了登录")
            } else {
                errorMessage = "Google 登录失败：\(error.localizedDescription)"
            }
            isAuthenticated = false
        }

        isLoading = false
    }
}
