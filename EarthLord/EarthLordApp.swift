//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 范有为 on 2026/1/1.
//

import SwiftUI

@main
struct EarthLordApp: App {
    /// 认证管理器
    @StateObject private var authManager = AuthManager(supabase: supabase)

    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !splashFinished {
                    // 1️⃣ 启动页
                    SplashView(
                        authManager: authManager,
                        isFinished: $splashFinished
                    )
                    .transition(.opacity)
                } else if authManager.isAuthenticated {
                    // 2️⃣ 已登录 → 主界面
                    MainTabView()
                        .transition(.opacity)
                        .environmentObject(authManager)
                        .environmentObject(languageManager)
                } else {
                    // 3️⃣ 未登录 → 认证页
                    AuthView(authManager: authManager)
                        .transition(.opacity)
                        .environmentObject(languageManager)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: splashFinished)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        }
    }
}
