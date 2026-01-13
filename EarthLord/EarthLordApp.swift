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

    /// 定位管理器（全局共享）
    @StateObject private var locationManager = LocationManager()

    /// 背包管理器
    @StateObject private var inventoryManager: InventoryManager

    /// 探索管理器（延迟初始化，因为依赖其他Manager）
    @StateObject private var explorationManager: ExplorationManager

    /// 启动页是否完成
    @State private var splashFinished = false

    init() {
        // 创建共享实例
        let locManager = LocationManager()
        let invManager = InventoryManager(supabase: supabase)
        let expManager = ExplorationManager(
            supabase: supabase,
            locationManager: locManager,
            inventoryManager: invManager
        )

        _locationManager = StateObject(wrappedValue: locManager)
        _inventoryManager = StateObject(wrappedValue: invManager)
        _explorationManager = StateObject(wrappedValue: expManager)
    }

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
                        .environmentObject(locationManager)
                        .environmentObject(inventoryManager)
                        .environmentObject(explorationManager)
                } else {
                    // 3️⃣ 未登录 → 认证页
                    AuthView(authManager: authManager)
                        .transition(.opacity)
                        .environmentObject(languageManager)
                }
            }
            .environment(\.locale, languageManager.currentLocale)
            .animation(.easeInOut(duration: 0.3), value: splashFinished)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .id(languageManager.currentLocale.identifier)
        }
    }
}
