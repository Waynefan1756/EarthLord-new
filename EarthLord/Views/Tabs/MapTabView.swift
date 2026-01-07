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
                    currentUserId: authManager.currentUser?.id.uuidString
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // 未授权时显示占位视图
                unauthorizedView
            }

            // 顶部标题栏
            VStack {
                headerView

                // ⭐ 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                }

                // ⭐ 验证结果横幅（闭环后显示）
                if showValidationBanner {
                    validationResultBanner
                }

                // ⭐ 上传结果消息
                if showUploadMessage, let message = uploadMessage {
                    uploadMessageBanner(message: message)
                }

                Spacer()
            }

            // 右下角按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // ⭐ 确认登记按钮（只在验证通过时显示）
                        if locationManager.territoryValidationPassed {
                            confirmTerritoryButton
                        }

                        // 圈地按钮
                        claimLandButton

                        // 定位按钮
                        locationButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
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
                locationManager.stopPathTracking()
            } else {
                // 开始追踪
                locationManager.startPathTracking()
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

    /// 右下角定位按钮
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

    /// 速度警告横幅
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
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
