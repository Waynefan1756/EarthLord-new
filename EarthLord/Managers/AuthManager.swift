//
//  AuthManager.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/2.
//

import Foundation
import Combine
import Supabase

@MainActor
class AuthManager: ObservableObject {
    // MARK: - Published Properties

    /// 已登录且完成所有流程
    @Published var isAuthenticated: Bool = false

    /// OTP验证后需要设置密码
    @Published var needsPasswordSetup: Bool = false

    /// 当前用户
    @Published var currentUser: User? = nil

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// 验证码已发送
    @Published var otpSent: Bool = false

    /// 验证码已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    private let supabase: SupabaseClient

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase

        // 检查当前会话状态
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    /// 检查当前会话
    private func checkSession() async {
        do {
            let session = try await supabase.auth.session

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

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 获取用户资料
            if let user = try? await fetchUserProfile(userId: session.user.id) {
                currentUser = user
            }

            isAuthenticated = true
            needsPasswordSetup = false

        } catch {
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
            try await supabase.auth.resetPasswordForEmail(email)
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
                type: .recovery  // 重置密码使用 recovery 类型
            )

            otpVerified = true
            isAuthenticated = false  // 需要设置新密码才算完成

        } catch {
            errorMessage = "验证码错误或已过期：\(error.localizedDescription)"
            otpVerified = false
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

        } catch {
            errorMessage = "退出登录失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 第三方登录（占位）

    /// Apple 登录（待实现）
    func signInWithApple() async {
        errorMessage = "Apple 登录功能开发中..."
    }

    /// Google 登录（待实现）
    func signInWithGoogle() async {
        errorMessage = "Google 登录功能开发中..."
    }
}
