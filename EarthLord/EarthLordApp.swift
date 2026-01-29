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

    /// 玩家位置服务（用于附近玩家检测）
    @StateObject private var playerLocationService: PlayerLocationService

    /// 建筑管理器
    @StateObject private var buildingManager: BuildingManager

    /// 启动页是否完成
    @State private var splashFinished = false

    /// App生命周期状态
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 创建共享实例
        let locManager = LocationManager()
        let invManager = InventoryManager(supabase: supabase)
        let playerLocService = PlayerLocationService(supabase: supabase, locationManager: locManager)
        let expManager = ExplorationManager(
            supabase: supabase,
            locationManager: locManager,
            inventoryManager: invManager,
            playerLocationService: playerLocService
        )
        let buildManager = BuildingManager(supabase: supabase, inventoryManager: invManager)

        _locationManager = StateObject(wrappedValue: locManager)
        _inventoryManager = StateObject(wrappedValue: invManager)
        _playerLocationService = StateObject(wrappedValue: playerLocService)
        _explorationManager = StateObject(wrappedValue: expManager)
        _buildingManager = StateObject(wrappedValue: buildManager)
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
                        .environmentObject(playerLocationService)
                        .environmentObject(buildingManager)
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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onAppear {
                handleAppLaunch()
            }
        }
    }

    // MARK: - App生命周期处理

    /// 处理App启动
    private func handleAppLaunch() {
        // 加载建筑模板（无论是否登录都可以加载）
        Task {
            try? await buildingManager.loadTemplates()
        }

        guard authManager.isAuthenticated else { return }

        Task {
            // 启动时上报位置
            if let location = locationManager.userLocation {
                await playerLocationService.reportLocation(location)
            }

            // 开始定时上报
            playerLocationService.startPeriodicReporting()
        }
    }

    /// 处理场景阶段变化
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard authManager.isAuthenticated else { return }

        switch phase {
        case .active:
            // App进入前台
            Task {
                if let location = locationManager.userLocation {
                    await playerLocationService.reportLocation(location)
                }
                playerLocationService.startPeriodicReporting()
            }

        case .background:
            // App进入后台
            Task {
                await playerLocationService.markOffline()
                playerLocationService.stopPeriodicReporting()
            }

        case .inactive:
            // 过渡状态，不处理
            break

        @unknown default:
            break
        }
    }
}
