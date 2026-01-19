//
//  MapTabView.swift
//  EarthLord
//
//  地图页面：显示真实地图、用户位置、定位权限管理
//

import SwiftUI
import CoreLocation

struct MapTabView: View {

    // MARK: - Properties

    /// 定位管理器（从 App 注入的全局实例）
    @EnvironmentObject var locationManager: LocationManager

    /// 认证管理器（从 App 注入的全局实例）
    @EnvironmentObject var authManager: AuthManager

    /// 探索管理器（从 App 注入的全局实例）
    @EnvironmentObject var explorationManager: ExplorationManager

    /// 玩家位置服务（从 App 注入的全局实例）
    @EnvironmentObject var playerLocationService: PlayerLocationService

    /// 领地管理器
    private let territoryManager = TerritoryManager(supabase: supabase)

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 上传状态
    @State private var isUploading = false
    @State private var uploadMessage: String? = nil
    @State private var showUploadMessage = false

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String?
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe
    @State private var trackingStartTime: Date?

    // MARK: - 探索功能状态
    @State private var showExplorationResult: Bool = false
    @State private var currentExplorationResult: ExplorationResult?

    /// 当前用户 ID
    private var currentUserId: String? {
        authManager.currentUser?.id.uuidString
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景地图
            if locationManager.isAuthorized {
                MapViewRepresentable(
                    userLocation: $locationManager.userLocation,
                    hasLocatedUser: $hasLocatedUser,
                    trackingPath: $locationManager.pathCoordinates,
                    pathUpdateVersion: locationManager.pathUpdateVersion,
                    isTracking: locationManager.isTracking,
                    isPathClosed: locationManager.isPathClosed,
                    territories: territories,
                    currentUserId: authManager.currentUser?.id.uuidString,
                    explorationPath: explorationManager.explorationPath,
                    explorationPathVersion: explorationManager.explorationPathVersion,
                    isExploring: explorationManager.isExploring,
                    nearbyPOIs: explorationManager.nearbyPOIs
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // 未授权时显示占位视图
                unauthorizedView
            }

            // 顶部标题栏
            VStack {
                headerView

                // ⭐ 探索状态栏（探索中时显示）
                if explorationManager.isExploring {
                    explorationStatusBar
                }

                // ⭐ 速度警告横幅（圈地功能）
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                // ⭐ 探索速度警告横幅
                if explorationManager.isOverSpeed || explorationManager.explorationFailed {
                    explorationSpeedWarningBanner
                }

                // ⭐ 验证结果横幅（闭环后显示）
                if showValidationBanner {
                    validationResultBanner
                }

                // ⭐ 上传结果消息
                if showUploadMessage, let message = uploadMessage {
                    uploadMessageBanner(message: message)
                }

                // ⭐ Day 19: 碰撞警告横幅（分级颜色）
                if showCollisionWarning, let warning = collisionWarning {
                    collisionWarningBanner(message: warning, level: collisionWarningLevel)
                }

                Spacer()
            }

            // 底部按钮组
            VStack {
                Spacer()

                // ⭐ 确认登记按钮（只在验证通过时显示，居中）
                if locationManager.territoryValidationPassed {
                    confirmTerritoryButton
                        .padding(.bottom, 12)
                }

                // 三个按钮水平排列
                HStack(spacing: 16) {
                    // 左：圈地按钮
                    claimLandButton

                    // 中：定位按钮
                    locationButton

                    // 右：探索按钮
                    exploreButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }

            // 权限被拒绝时的提示卡片
            if locationManager.isDenied {
                deniedPermissionCard
            }
        }
        .onAppear {
            // 页面出现时检查权限
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }

            // 加载领地
            Task {
                await loadTerritories()
            }
        }
        // 探索结果弹窗
        .sheet(isPresented: $showExplorationResult) {
            if let result = currentExplorationResult {
                ExplorationResultView(result: result)
            }
        }
        // POI接近弹窗
        .sheet(isPresented: $explorationManager.showPOIPopup) {
            if let poi = explorationManager.currentScavengePOI {
                POIProximityPopup(
                    poi: poi,
                    onScavenge: {
                        // 异步调用 AI 生成搜刮
                        Task {
                            await explorationManager.performScavenge()
                        }
                    },
                    onSkip: {
                        explorationManager.skipScavenge()
                    }
                )
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
            }
        }
        // 搜刮结果弹窗（传统物品，降级方案）
        .sheet(isPresented: $explorationManager.showScavengeResult) {
            if let poi = explorationManager.currentScavengePOI {
                ScavengeResultView(
                    poiName: poi.name,
                    poiType: poi.type,
                    lootItems: explorationManager.scavengeLootItems,
                    onClose: {
                        explorationManager.closeScavengeResult()
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        // AI 搜刮结果弹窗
        .sheet(isPresented: $explorationManager.showAIScavengeResult) {
            if let poi = explorationManager.currentScavengePOI {
                AIScavengeResultView(
                    poiName: poi.name,
                    poiType: poi.type,
                    dangerLevel: poi.dangerLevel,
                    items: explorationManager.aiGeneratedItems,
                    onClose: {
                        explorationManager.closeAIScavengeResult()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        // ⭐ 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// 顶部标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("地图")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let location = locationManager.userLocation {
                    Text("坐标: \(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Text("定位中...")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // ⭐ GPS信号质量指示器（只在追踪时显示）
            if locationManager.isTracking {
                gpsQualityIndicator
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    ApocalypseTheme.background.opacity(0.9),
                    ApocalypseTheme.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// 探索状态栏
    private var explorationStatusBar: some View {
        VStack(spacing: 6) {
            // 第一行：探索中 + 距离 + 时长
            HStack(spacing: 16) {
                // 探索中状态
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14))
                    Text("探索中")
                        .font(.system(size: 14, weight: .semibold))
                }

                // 距离
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12))
                    Text(explorationManager.formattedDistance)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                }

                // 时长
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(explorationManager.formattedDuration)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                }

                // 附近幸存者
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(densityColor)
                    Text("\(playerLocationService.nearbyPlayerCount)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(densityColor)
                }

                Spacer()

                // 结束探索按钮
                Button(action: {
                    Task {
                        await toggleExploration()
                    }
                }) {
                    Text("结束探索")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(12)
                }
            }

            // 第二行：距离下一等级的提示
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 12))
                Text(distanceToNextTierText)
                    .font(.system(size: 12))
                Spacer()
            }
            .opacity(0.9)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isExploring)
    }

    /// 根据密度等级返回对应颜色
    private var densityColor: Color {
        switch playerLocationService.densityLevel {
        case .solo:
            return .gray
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    /// 距离下一等级的提示文本
    private var distanceToNextTierText: String {
        let currentDistance = explorationManager.currentDistance
        let currentTier = explorationManager.currentRewardTier

        switch currentTier {
        case .none:
            let remaining = 200 - currentDistance
            return "距铜级还差 \(Int(max(0, remaining)))m"
        case .bronze:
            let remaining = 500 - currentDistance
            return "距银级还差 \(Int(max(0, remaining)))m"
        case .silver:
            let remaining = 1000 - currentDistance
            return "距金级还差 \(Int(max(0, remaining)))m"
        case .gold:
            let remaining = 2000 - currentDistance
            return "距钻石级还差 \(Int(max(0, remaining)))m"
        case .diamond:
            return "已达最高等级 🎉"
        }
    }

    /// GPS信号质量指示器
    private var gpsQualityIndicator: some View {
        HStack(spacing: 6) {
            // 信号图标（根据质量显示不同状态）
            Image(systemName: gpsSignalIcon)
                .font(.system(size: 16))
                .foregroundColor(gpsSignalColor)

            // 信号质量文字
            Text(gpsSignalText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(gpsSignalColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            gpsSignalColor.opacity(0.15)
        )
        .cornerRadius(12)
    }

    // GPS信号图标
    private var gpsSignalIcon: String {
        let quality = locationManager.gpsSignalQuality
        if quality >= 70 {
            return "antenna.radiowaves.left.and.right"
        } else if quality >= 40 {
            return "wifi.exclamationmark"
        } else {
            return "wifi.slash"
        }
    }

    // GPS信号文字
    private var gpsSignalText: String {
        let quality = locationManager.gpsSignalQuality
        if quality >= 70 {
            return "信号良好"
        } else if quality >= 40 {
            return "信号一般"
        } else {
            return "信号较差"
        }
    }

    // GPS信号颜色
    private var gpsSignalColor: Color {
        let quality = locationManager.gpsSignalQuality
        if quality >= 70 {
            return .green
        } else if quality >= 40 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.danger
        }
    }

    /// 确认登记领地按钮
    private var confirmTerritoryButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                }

                Text(isUploading ? "上传中..." : "确认登记")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(isUploading)
    }

    /// 圈地按钮
    private var claimLandButton: some View {
        Button(action: {
            if locationManager.isTracking {
                // 停止追踪
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                        .font(.system(size: 14, weight: .semibold))

                    if locationManager.isTracking {
                        Text("\(locationManager.pathCoordinates.count) 个点")
                            .font(.system(size: 11))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(locationManager.isTracking ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            // 重新居中到用户位置
            if let location = locationManager.userLocation {
                // 通过重置 hasLocatedUser，可以在 MapViewRepresentable 中再次居中
                // 但当前实现中，需要手动实现这个功能
                print("📍 用户点击定位按钮")
            }
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
    }

    /// 探索按钮
    private var exploreButton: some View {
        Button(action: {
            Task {
                await toggleExploration()
            }
        }) {
            HStack(spacing: 8) {
                if explorationManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: explorationManager.isExploring ? "stop.fill" : "binoculars.fill")
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(explorationManager.isExploring ? "结束探索" : "探索")
                        .font(.system(size: 14, weight: .semibold))

                    // 探索中显示实时距离
                    if explorationManager.isExploring {
                        Text("\(explorationManager.formattedDistance) | \(explorationManager.currentRewardTier.displayName)")
                            .font(.system(size: 11))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(explorationManager.isExploring ? ApocalypseTheme.success : ApocalypseTheme.info)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .disabled(explorationManager.isLoading)
    }

    /// 切换探索状态
    private func toggleExploration() async {
        if explorationManager.isExploring {
            // 结束探索
            do {
                let result = try await explorationManager.endExploration()
                currentExplorationResult = result
                showExplorationResult = true
            } catch {
                print("结束探索失败: \(error)")
            }
        } else {
            // 开始探索
            do {
                try await explorationManager.startExploration()
            } catch {
                print("开始探索失败: \(error)")
            }
        }
    }

    /// 未授权时的占位视图
    private var unauthorizedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("需要定位权限")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("允许《地球新主》访问您的位置\n才能显示您在末日世界中的坐标")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                locationManager.requestPermission()
            }) {
                Text("请求定位权限")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }

    /// 权限被拒绝时的提示卡片
    private var deniedPermissionCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text("定位权限被拒绝")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("请在系统设置中允许定位")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()
            }

            Button(action: {
                // 打开系统设置页面
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("前往设置")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }

    /// 速度警告横幅（圈地功能）
    private var speedWarningBanner: some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            // 警告文字
            Text(locationManager.speedWarning ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            // 根据是否还在追踪显示不同颜色
            locationManager.isTracking
                ? ApocalypseTheme.warning  // 警告但还在追踪：黄色
                : ApocalypseTheme.danger   // 已暂停追踪：红色
        )
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // 3 秒后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    locationManager.speedWarning = nil
                }
            }
        }
    }

    /// 探索速度警告横幅
    private var explorationSpeedWarningBanner: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: explorationManager.explorationFailed ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                // 警告文字
                if explorationManager.explorationFailed {
                    Text(explorationManager.failureReason ?? "探索失败")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else if let warning = explorationManager.speedWarning {
                    Text(warning)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    Text("速度过快")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }

                // 当前速度
                if explorationManager.isOverSpeed && !explorationManager.explorationFailed {
                    Text(String(format: "当前: %.1f km/h | 限速: 30 km/h", explorationManager.currentSpeed))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            // 速度显示
            if explorationManager.isOverSpeed && !explorationManager.explorationFailed {
                Text(String(format: "%.0f", explorationManager.currentSpeed))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            explorationManager.explorationFailed
                ? ApocalypseTheme.danger   // 已失败：红色
                : ApocalypseTheme.warning  // 警告中：黄色
        )
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isOverSpeed)
        .animation(.easeInOut(duration: 0.3), value: explorationManager.explorationFailed)
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 上传结果消息横幅
    private func uploadMessageBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(message.contains("成功") ? Color.green : Color.red)
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
    }

    // MARK: - Methods

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            uploadMessage = "领地验证未通过，无法上传"
            showUploadMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showUploadMessage = false
            }
            return
        }

        // 检查是否有路径数据
        guard !locationManager.pathCoordinates.isEmpty else {
            uploadMessage = "路径数据为空，无法上传"
            showUploadMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showUploadMessage = false
            }
            return
        }

        isUploading = true

        do {
            // 上传领地
            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: Date()
            )

            // 上传成功
            uploadMessage = "领地登记成功！"
            showUploadMessage = true

            // ⚠️ 关键：上传成功后必须停止追踪！
            stopCollisionMonitoring()  // Day 19: 停止碰撞监控
            locationManager.stopPathTracking()

            // 刷新领地列表
            await loadTerritories()

            // 隐藏消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showUploadMessage = false
            }

        } catch {
            // 上传失败
            uploadMessage = "上传失败: \(error.localizedDescription)"
            showUploadMessage = true

            // 隐藏消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showUploadMessage = false
            }
        }

        isUploading = false
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            territoryManager.territories = territories
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
