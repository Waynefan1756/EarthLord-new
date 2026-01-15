//
//  PlayerLocationService.swift
//  EarthLord
//
//  玩家位置服务
//  负责位置上报、附近玩家检测、密度计算
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - 玩家密度等级

/// 玩家密度等级，用于决定POI显示数量
enum PlayerDensityLevel: String, CaseIterable {
    case solo = "solo"           // 0人 - 独行者
    case low = "low"             // 1-5人 - 低密度
    case medium = "medium"       // 6-20人 - 中密度
    case high = "high"           // 20+人 - 高密度

    /// 显示名称
    var displayName: String {
        switch self {
        case .solo: return "独行者"
        case .low: return "低密度"
        case .medium: return "中密度"
        case .high: return "高密度"
        }
    }

    /// 建议的POI数量
    var recommendedPOICount: Int {
        switch self {
        case .solo: return 1
        case .low: return 3
        case .medium: return 6
        case .high: return 15
        }
    }

    /// 密度等级对应的颜色名称
    var colorName: String {
        switch self {
        case .solo: return "gray"
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }

    /// 根据附近玩家数量计算密度等级
    static func from(playerCount: Int) -> PlayerDensityLevel {
        switch playerCount {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - 玩家位置服务

/// 玩家位置服务
/// 负责位置上报、附近玩家查询、密度计算
@MainActor
class PlayerLocationService: ObservableObject {

    // MARK: - Published Properties

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var densityLevel: PlayerDensityLevel = .solo

    /// 最后上报时间
    @Published var lastReportTime: Date?

    /// 是否正在上报
    @Published var isReporting: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let supabaseClient: SupabaseClient
    private weak var locationManager: LocationManager?

    /// 定时上报计时器（30秒间隔）
    private var reportTimer: Timer?

    /// 位置订阅
    private var locationCancellable: AnyCancellable?

    /// 最后上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// 日志管理器
    private let logger = ExplorationLogger.shared

    // MARK: - 常量

    /// 上报间隔（秒）
    private let reportIntervalSeconds: TimeInterval = 30.0

    /// 触发上报的最小移动距离（米）
    private let minDistanceForReport: Double = 50.0

    /// 查询半径（米）
    private let queryRadiusMeters: Double = 1000.0

    /// 活跃时间窗口（分钟）
    private let activeMinutes: Int = 5

    // MARK: - 初始化

    init(supabase: SupabaseClient, locationManager: LocationManager) {
        self.supabaseClient = supabase
        self.locationManager = locationManager

        logger.log("[玩家定位] 服务初始化完成", type: .info)
    }

    deinit {
        // 在deinit中直接停止定时器，无需MainActor
        reportTimer?.invalidate()
        reportTimer = nil
        locationCancellable?.cancel()
        locationCancellable = nil
    }

    // MARK: - 公开方法

    /// 上报当前位置到服务器
    /// - Parameters:
    ///   - coordinate: 要上报的位置
    ///   - isOnline: 是否在线
    func reportLocation(_ coordinate: CLLocationCoordinate2D, isOnline: Bool = true) async {
        isReporting = true
        errorMessage = nil

        do {
            try await executeUpsertLocationRPC(
                client: supabaseClient,
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                isOnline: isOnline
            )

            lastReportedLocation = coordinate
            lastReportTime = Date()

            logger.log("[玩家定位] 位置上报成功: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))", type: .success)

        } catch {
            errorMessage = "位置上报失败: \(error.localizedDescription)"
            logger.log("[玩家定位] 位置上报失败: \(error.localizedDescription)", type: .error)
        }

        isReporting = false
    }

    /// 查询附近玩家数量
    /// - Parameter coordinate: 查询中心点
    /// - Returns: 附近玩家数量
    @discardableResult
    func queryNearbyPlayerCount(at coordinate: CLLocationCoordinate2D) async -> Int {
        logger.log("[玩家定位] 开始查询附近玩家，位置: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))", type: .info)

        do {
            let response = try await executeNearbyPlayerQueryRPC(
                client: supabaseClient,
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                radiusMeters: queryRadiusMeters,
                activeMinutes: activeMinutes
            )

            nearbyPlayerCount = response
            densityLevel = PlayerDensityLevel.from(playerCount: response)

            logger.log("[玩家定位] ✅ 附近玩家查询成功: \(response) 人，密度: \(densityLevel.displayName)", type: .success)

            return response

        } catch {
            logger.log("[玩家定位] ❌ 查询附近玩家失败: \(error.localizedDescription)", type: .error)
            logger.log("[玩家定位] 错误详情: \(error)", type: .error)
            return 0
        }
    }

    /// 获取建议的POI数量
    func getRecommendedPOICount() -> Int {
        return densityLevel.recommendedPOICount
    }

    /// 标记玩家离线
    func markOffline() async {
        do {
            try await executeMarkOfflineRPC(client: supabaseClient)
            logger.log("[玩家定位] 已标记为离线", type: .info)
        } catch {
            logger.log("[玩家定位] 标记离线失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - 定时上报

    /// 开始定时位置上报
    func startPeriodicReporting() {
        guard reportTimer == nil else { return }

        logger.log("[玩家定位] 开始定时上报 (间隔: \(Int(reportIntervalSeconds))秒)", type: .info)

        // 订阅位置更新，用于距离触发上报
        locationCancellable = locationManager?.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                Task { @MainActor in
                    await self?.checkDistanceAndReport(coordinate)
                }
            }

        // 启动定时器，用于时间触发上报
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.timerTriggeredReport()
            }
        }
    }

    /// 停止定时位置上报
    func stopPeriodicReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
        locationCancellable?.cancel()
        locationCancellable = nil

        logger.log("[玩家定位] 停止定时上报", type: .info)
    }

    // MARK: - 私有方法

    /// 检查距离并决定是否上报
    private func checkDistanceAndReport(_ coordinate: CLLocationCoordinate2D) async {
        guard let lastLocation = lastReportedLocation else {
            // 首次位置，立即上报
            await reportLocation(coordinate)
            return
        }

        // 计算与上次上报位置的距离
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let last = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let distance = current.distance(from: last)

        // 移动超过阈值时上报
        if distance >= minDistanceForReport {
            logger.log("[玩家定位] 移动 \(String(format: "%.1f", distance))m，触发上报", type: .gps)
            await reportLocation(coordinate)
        }
    }

    /// 定时器触发的上报
    private func timerTriggeredReport() async {
        guard let coordinate = locationManager?.userLocation else { return }
        await reportLocation(coordinate)
    }
}
