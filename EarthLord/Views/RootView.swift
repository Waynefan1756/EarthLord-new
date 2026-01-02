//
//  RootView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/1.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager(supabase: supabase)

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isAuthenticated {
                // 已登录 → 主界面
                MainTabView()
                    .transition(.opacity)
                    .environmentObject(authManager)
            } else {
                // 未登录 → 认证页
                AuthView(authManager: authManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
}

#Preview {
    RootView()
}
