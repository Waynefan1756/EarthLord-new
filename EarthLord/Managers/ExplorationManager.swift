//
//  ExplorationManager.swift
//  EarthLord
//
//  探索状态管理器
//  管理探索会话生命周期、GPS追踪、距离计算、速度检测、奖励生成
//

import Foundation
import CoreLocation
import Supabase
import Combine

// MARK: - 探索日志

/// 探索日志类型
enum ExplorationLogType: String {
    case info = "ℹ️"
    case success = "✅"
    case warning = "⚠️"
    case error = "❌"
    case gps = "📍"
    case speed = "🏃"
}

/// 探索日志管理器
class ExplorationLogger {
    static let shared = ExplorationLogger()
    private init() {}

    func log(_ message: String, type: ExplorationLogType = .info) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(type.rawValue) [探索] \(message)")
    }
}

// MARK: - 数据库模型

/// 探索会话数据库模型（用于与 Supabase 交互）
struct ExplorationSessionDB: Codable {
    let id: UUID
    let userId: UUID
    let startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
    var walkingDistance: Double
    var rewardTier: String?
    var status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case walkingDistance = "walking_distance"
        case rewardTier = "reward_tier"
        case status
        case createdAt = "created_at"
    }
}

/// 插入探索会话的请求模型
struct InsertExplorationSession: Codable {
    let userId: UUID
    let walkingDistance: Double
    let status: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case walkingDistance = "walking_distance"
        case status
    }
}

/// 更新探索会话的请求模型
struct UpdateExplorationSession: Codable {
    let endedAt: Date
    let durationSeconds: Int
    let walkingDistance: Double
    let rewardTier: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case walkingDistance = "walking_distance"
        case rewardTier = "reward_tier"
        case status
    }
}

/// 用户探索统计数据库模型
struct UserExplorationStatsDB: Codable {
    let userId: UUID
    var totalWalkingDistance: Double
    var totalExplorationCount: Int
    var totalItemsCollected: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalWalkingDistance = "total_walking_distance"
        case totalExplorationCount = "total_exploration_count"
        case totalItemsCollected = "total_items_collected"
    }
}

/// 更新用户探索统计的请求模型
struct UpdateUserExplorationStats: Codable {
    let totalWalkingDistance: Double
    let totalExplorationCount: Int
    let totalItemsCollected: Int

    enum CodingKeys: String, CodingKey {
        case totalWalkingDistance = "total_walking_distance"
        case totalExplorationCount = "total_exploration_count"
        case totalItemsCollected = "total_items_collected"
    }
}

// MARK: - 探索管理器

/// 探索状态管理器
@MainActor
class ExplorationManager: ObservableObject {

    // MARK: - Published Properties

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前探索会话 ID
    @Published var currentSessionId: UUID?

    /// 当前行走距离（米）
    @Published var currentDistance: Double = 0

    /// 当前奖励等级（实时计算）
    @Published var currentRewardTier: RewardTier = .none

    /// 探索开始时间
    @Published var startTime: Date?

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 错误信息
    @Published var errorMessage: String?

    /// 正在加载
    @Published var isLoading: Bool = false

    // MARK: - 速度检测相关

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 超速开始时间（用于计算超速持续时长）
    private var overSpeedStartTime: Date?

    /// 探索是否因超速失败
    @Published var explorationFailed: Bool = false

    /// 失败原因
    @Published var failureReason: String?

    // MARK: - POI 搜刮相关

    /// 附近POI列表
    @Published var nearbyPOIs: [ExplorablePOI] = []

    /// 是否显示POI搜刮弹窗
    @Published var showPOIPopup: Bool = false

    /// 当前可搜刮的POI
    @Published var currentScavengePOI: ExplorablePOI?

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 搜刮获得的物品
    @Published var scavengeLootItems: [LootItem] = []

    /// 本次探索搜刮的POI数量
    @Published var scavengedPOICount: Int = 0

    // MARK: - Dependencies

    private let supabaseClient: SupabaseClient
    private weak var locationManager: LocationManager?
    private weak var inventoryManager: InventoryManager?
    private weak var playerLocationService: PlayerLocationService?

    /// POI搜索管理器
    private let poiSearchManager = POISearchManager()

    /// 探索期间位置上报定时器
    private var explorationReportTimer: Timer?

    // MARK: - Private Properties

    /// 上一个位置（包含时间戳）
    private var lastLocation: CLLocation?

    /// 上一次位置更新时间
    private var lastLocationTime: Date?

    /// 探索轨迹（公开供地图显示）
    @Published var explorationPath: [CLLocationCoordinate2D] = []

    /// 探索路径更新版本号（用于触发地图更新）
    @Published var explorationPathVersion: Int = 0

    /// 位置更新订阅
    private var locationCancellable: AnyCancellable?

    /// 时长更新定时器
    private var durationTimer: Timer?

    /// 速度检测定时器
    private var speedCheckTimer: Timer?

    /// 日志
    private let logger = ExplorationLogger.shared

    // MARK: - 常量配置

    /// 最大允许速度（km/h）
    private let maxSpeedKmh: Double = 30.0

    /// 超速后停止探索的时间（秒）
    private let overSpeedTimeoutSeconds: TimeInterval = 10.0

    /// 最大允许精度（米）- GPS精度太差的点会被忽略
    private let maxAccuracy: Double = 50

    /// 最大允许单次移动距离（米）- 防止GPS跳点
    private let maxSingleMoveDistance: Double = 100

    /// 最小记录距离（米）- 移动太小不记录
    private let minRecordDistance: Double = 5

    /// 最小时间间隔（秒）- 避免频繁计算
    private let minTimeInterval: TimeInterval = 2.0

    // MARK: - Initialization

    init(supabase: SupabaseClient, locationManager: LocationManager, inventoryManager: InventoryManager, playerLocationService: PlayerLocationService) {
        self.supabaseClient = supabase
        self.locationManager = locationManager
        self.inventoryManager = inventoryManager
        self.playerLocationService = playerLocationService
        logger.log("ExplorationManager 初始化完成", type: .info)
    }

    // MARK: - Public Methods

    /// 开始探索
    func startExploration() async throws {
        guard !isExploring else {
            logger.log("已经在探索中，忽略重复调用", type: .warning)
            return
        }

        guard let userId = supabaseClient.auth.currentUser?.id else {
            logger.log("用户未登录，无法开始探索", type: .error)
            throw ExplorationError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil
        explorationFailed = false
        failureReason = nil

        logger.log("开始创建探索会话...", type: .info)

        do {
            // 1. 创建数据库会话记录
            let insertSession = InsertExplorationSession(
                userId: userId,
                walkingDistance: 0,
                status: "in_progress"
            )

            let response: [ExplorationSessionDB] = try await supabaseClient
                .from("exploration_sessions")
                .insert(insertSession)
                .select()
                .execute()
                .value

            guard let session = response.first else {
                logger.log("创建探索会话失败：数据库返回空", type: .error)
                throw ExplorationError.sessionCreationFailed
            }

            // 2. 初始化探索状态
            currentSessionId = session.id
            startTime = Date()
            currentDistance = 0
            currentDuration = 0
            currentRewardTier = .none
            currentSpeed = 0
            isOverSpeed = false
            speedWarning = nil
            overSpeedStartTime = nil
            explorationPath.removeAll()
            lastLocation = nil
            lastLocationTime = nil
            isExploring = true

            // 3. 开始监听位置更新
            startLocationTracking()

            // 4. 开始时长计时器
            startDurationTimer()

            // 5. 开始速度检测定时器
            startSpeedCheckTimer()

            // 6. 搜索附近POI并设置围栏（包含密度查询）
            await searchAndSetupPOIs()

            // 7. 开始探索期间的位置上报（每30秒）
            startExplorationReporting()

            isLoading = false

            logger.log("探索开始成功，会话ID: \(session.id)", type: .success)

        } catch {
            isLoading = false
            errorMessage = "开始探索失败: \(error.localizedDescription)"
            logger.log("开始探索失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// 结束探索
    /// - Returns: 探索结果
    func endExploration() async throws -> ExplorationResult {
        guard isExploring, let sessionId = currentSessionId, let startTime = startTime else {
            logger.log("没有进行中的探索，无法结束", type: .error)
            throw ExplorationError.noActiveSession
        }

        isLoading = true

        logger.log("正在结束探索...", type: .info)
        logger.log("最终距离: \(String(format: "%.1f", currentDistance))米", type: .info)

        do {
            // 1. 停止追踪
            stopLocationTracking()
            stopDurationTimer()
            stopSpeedCheckTimer()
            stopExplorationReporting()

            // 2. 上报最终位置
            if let location = locationManager?.userLocation {
                await playerLocationService?.reportLocation(location)
            }

            // 3. 计算最终数据
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let tier = RewardTier.fromDistance(currentDistance)

            logger.log("探索时长: \(Int(duration))秒, 奖励等级: \(tier.displayName)", type: .info)

            // 4. 生成奖励
            let lootItems = RewardGenerator.generateRewards(tier: tier, source: "探索奖励")
            logger.log("生成奖励物品: \(lootItems.count)件", type: .info)

            // 5. 更新数据库会话记录
            let updateSession = UpdateExplorationSession(
                endedAt: endTime,
                durationSeconds: Int(duration),
                walkingDistance: currentDistance,
                rewardTier: tier.rawValue,
                status: "completed"
            )

            try await supabaseClient
                .from("exploration_sessions")
                .update(updateSession)
                .eq("id", value: sessionId.uuidString)
                .execute()

            logger.log("数据库会话记录已更新", type: .success)

            // 6. 将物品添加到背包
            if !lootItems.isEmpty {
                try await inventoryManager?.addItems(lootItems, explorationSessionId: sessionId)
                logger.log("物品已添加到背包", type: .success)
            }

            // 7. 更新用户累计统计
            try await updateUserStats(distance: currentDistance, itemCount: lootItems.count)

            // 8. 创建探索结果（简化版，移除面积相关字段）
            let stats = ExplorationStats(
                walkingDistance: currentDistance,
                totalWalkingDistance: 0,
                walkingDistanceRank: 0,
                duration: duration,
                discoveredPOIs: 0,
                lootedPOIs: 0
            )

            let result = ExplorationResult(
                id: sessionId.uuidString,
                startTime: startTime,
                endTime: endTime,
                stats: stats,
                lootItems: lootItems,
                visitedPOIs: []
            )

            // 8. 重置状态
            resetExplorationState()

            isLoading = false

            logger.log("探索成功结束！距离: \(String(format: "%.1f", currentDistance))米, 等级: \(tier.displayName), 物品: \(lootItems.count)件", type: .success)

            return result

        } catch {
            isLoading = false
            errorMessage = "结束探索失败: \(error.localizedDescription)"
            logger.log("结束探索失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    /// 取消探索（不生成奖励）
    func cancelExploration() async {
        guard isExploring, let sessionId = currentSessionId else {
            logger.log("没有进行中的探索，无法取消", type: .warning)
            return
        }

        logger.log("正在取消探索...", type: .info)

        // 停止追踪
        stopLocationTracking()
        stopDurationTimer()
        stopSpeedCheckTimer()

        // 更新数据库状态为取消
        do {
            try await supabaseClient
                .from("exploration_sessions")
                .update(["status": "cancelled"])
                .eq("id", value: sessionId.uuidString)
                .execute()
            logger.log("数据库状态已更新为取消", type: .info)
        } catch {
            logger.log("取消探索更新数据库失败: \(error)", type: .error)
        }

        // 重置状态
        resetExplorationState()

        logger.log("探索已取消", type: .warning)
    }

    /// 因超速强制停止探索
    func forceStopDueToOverSpeed() async {
        guard isExploring, let sessionId = currentSessionId else { return }

        logger.log("因超速强制停止探索！", type: .error)

        // 停止追踪
        stopLocationTracking()
        stopDurationTimer()
        stopSpeedCheckTimer()

        // 更新数据库状态为失败
        do {
            try await supabaseClient
                .from("exploration_sessions")
                .update(["status": "cancelled"])
                .eq("id", value: sessionId.uuidString)
                .execute()
        } catch {
            logger.log("更新数据库失败: \(error)", type: .error)
        }

        // 设置失败状态
        explorationFailed = true
        failureReason = "速度超过30km/h持续10秒，探索失败"

        // 重置探索状态
        resetExplorationState()

        logger.log("探索因超速失败", type: .error)
    }

    // MARK: - Private Methods - Location Tracking

    /// 开始位置追踪
    private func startLocationTracking() {
        guard let locationManager = locationManager else {
            logger.log("LocationManager 不可用", type: .error)
            return
        }

        logger.log("开始GPS位置追踪", type: .gps)

        // 订阅位置更新
        locationCancellable = locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.handleLocationUpdate(coordinate)
            }
    }

    /// 停止位置追踪
    private func stopLocationTracking() {
        locationCancellable?.cancel()
        locationCancellable = nil
        logger.log("停止GPS位置追踪", type: .gps)
    }

    /// 处理位置更新
    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        let now = Date()
        let newLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // 如果是第一个点，直接记录
        guard let lastLoc = lastLocation, let lastTime = lastLocationTime else {
            lastLocation = newLocation
            lastLocationTime = now
            explorationPath.append(coordinate)
            logger.log("记录起始点: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))", type: .gps)
            return
        }

        // 计算时间间隔
        let timeInterval = now.timeIntervalSince(lastTime)

        // 时间间隔太短，跳过
        guard timeInterval >= minTimeInterval else {
            return
        }

        // 计算与上个点的距离（米）
        let distance = newLocation.distance(from: lastLoc)

        // 计算速度（km/h）
        let speedMps = distance / timeInterval  // 米/秒
        let speedKmh = speedMps * 3.6  // 转换为 km/h
        currentSpeed = speedKmh

        // 速度检测
        checkSpeed(speedKmh)

        // 过滤无效移动
        if distance < minRecordDistance {
            logger.log("移动距离太小 (\(String(format: "%.1f", distance))米)，忽略", type: .gps)
            return
        }

        if distance > maxSingleMoveDistance {
            logger.log("GPS跳点检测：距离 \(String(format: "%.1f", distance))米 超过阈值，忽略", type: .warning)
            return
        }

        // 如果超速，不计入距离
        if isOverSpeed {
            logger.log("超速中，本次移动不计入距离", type: .speed)
            lastLocation = newLocation
            lastLocationTime = now
            return
        }

        // 累加距离
        currentDistance += distance
        lastLocation = newLocation
        lastLocationTime = now
        explorationPath.append(coordinate)
        explorationPathVersion += 1

        // 更新奖励等级
        let newTier = RewardTier.fromDistance(currentDistance)
        if newTier != currentRewardTier {
            currentRewardTier = newTier
            logger.log("奖励等级提升: \(newTier.displayName)", type: .success)
        }

        logger.log("距离+\(String(format: "%.1f", distance))米, 总计: \(String(format: "%.1f", currentDistance))米, 速度: \(String(format: "%.1f", speedKmh))km/h", type: .gps)
    }

    // MARK: - Private Methods - Speed Detection

    /// 检测速度
    private func checkSpeed(_ speedKmh: Double) {
        if speedKmh > maxSpeedKmh {
            // 超速
            if !isOverSpeed {
                // 刚开始超速
                isOverSpeed = true
                overSpeedStartTime = Date()
                speedWarning = "速度过快！请减速至30km/h以下"
                logger.log("检测到超速: \(String(format: "%.1f", speedKmh))km/h，开始计时", type: .speed)
            }
        } else {
            // 速度正常
            if isOverSpeed {
                // 从超速恢复
                isOverSpeed = false
                overSpeedStartTime = nil
                speedWarning = nil
                logger.log("速度恢复正常: \(String(format: "%.1f", speedKmh))km/h", type: .speed)
            }
        }
    }

    /// 开始速度检测定时器
    private func startSpeedCheckTimer() {
        speedCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkOverSpeedTimeout()
            }
        }
        logger.log("速度检测定时器已启动", type: .info)
    }

    /// 停止速度检测定时器
    private func stopSpeedCheckTimer() {
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
        logger.log("速度检测定时器已停止", type: .info)
    }

    // MARK: - 探索期间位置上报

    /// 开始探索期间的位置上报（每30秒）
    private func startExplorationReporting() {
        explorationReportTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let location = self.locationManager?.userLocation else { return }
                await self.playerLocationService?.reportLocation(location)
            }
        }
        logger.log("探索位置上报已启动（间隔30秒）", type: .info)
    }

    /// 停止探索期间的位置上报
    private func stopExplorationReporting() {
        explorationReportTimer?.invalidate()
        explorationReportTimer = nil
        logger.log("探索位置上报已停止", type: .info)
    }

    /// 检查超速是否超时
    private func checkOverSpeedTimeout() {
        guard isOverSpeed, let overSpeedStart = overSpeedStartTime else {
            return
        }

        let overSpeedDuration = Date().timeIntervalSince(overSpeedStart)
        let remainingTime = overSpeedTimeoutSeconds - overSpeedDuration

        if remainingTime <= 0 {
            // 超时，强制停止
            logger.log("超速持续超过\(Int(overSpeedTimeoutSeconds))秒，强制停止探索", type: .error)
            Task {
                await forceStopDueToOverSpeed()
            }
        } else {
            // 更新警告信息
            speedWarning = "速度过快！\(Int(remainingTime))秒后探索将失败"
            logger.log("超速中，剩余时间: \(Int(remainingTime))秒", type: .speed)
        }
    }

    // MARK: - Private Methods - Timers

    /// 开始时长计时器
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.startTime else { return }
                self.currentDuration = Date().timeIntervalSince(startTime)
            }
        }
        logger.log("时长计时器已启动", type: .info)
    }

    /// 停止时长计时器
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        logger.log("时长计时器已停止", type: .info)
    }

    /// 重置探索状态
    private func resetExplorationState() {
        isExploring = false
        currentSessionId = nil
        startTime = nil
        currentDistance = 0
        currentDuration = 0
        currentRewardTier = .none
        currentSpeed = 0
        isOverSpeed = false
        speedWarning = nil
        overSpeedStartTime = nil
        explorationPath.removeAll()
        lastLocation = nil
        lastLocationTime = nil

        // 停止探索位置上报
        stopExplorationReporting()

        // 清理POI相关状态
        cleanupPOIs()

        logger.log("探索状态已重置", type: .info)
    }

    /// 更新用户累计统计
    private func updateUserStats(distance: Double, itemCount: Int) async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else { return }

        logger.log("更新用户累计统计...", type: .info)

        // 尝试获取现有统计
        let existingStats: [UserExplorationStatsDB] = try await supabaseClient
            .from("user_exploration_stats")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if let stats = existingStats.first {
            // 更新现有记录
            let updateData = UpdateUserExplorationStats(
                totalWalkingDistance: stats.totalWalkingDistance + distance,
                totalExplorationCount: stats.totalExplorationCount + 1,
                totalItemsCollected: stats.totalItemsCollected + itemCount
            )
            try await supabaseClient
                .from("user_exploration_stats")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()
            logger.log("累计统计已更新: 总距离+\(String(format: "%.1f", distance))米", type: .success)
        } else {
            // 创建新记录
            let newStats = UserExplorationStatsDB(
                userId: userId,
                totalWalkingDistance: distance,
                totalExplorationCount: 1,
                totalItemsCollected: itemCount
            )
            try await supabaseClient
                .from("user_exploration_stats")
                .insert(newStats)
                .execute()
            logger.log("创建新的累计统计记录", type: .success)
        }
    }

    // MARK: - POI 搜刮方法

    /// 搜索附近POI并设置围栏
    private func searchAndSetupPOIs() async {
        logger.log("开始搜索附近POI...", type: .info)

        // 等待位置可用（最多等待5秒）
        var location = locationManager?.userLocation
        var waitCount = 0
        while location == nil && waitCount < 10 {
            logger.log("等待位置获取... (\(waitCount + 1)/10)", type: .info)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            location = locationManager?.userLocation
            waitCount += 1
        }

        guard let location = location else {
            logger.log("❌ 等待5秒后仍无法获取用户位置，跳过POI搜索", type: .error)
            return
        }

        logger.log("当前位置: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))", type: .gps)

        do {
            // 1. 上报当前位置
            logger.log("正在上报位置...", type: .info)
            await playerLocationService?.reportLocation(location)
            logger.log("位置上报完成", type: .success)

            // 2. 查询附近玩家数量，获取密度等级
            logger.log("正在查询附近玩家数量...", type: .info)
            var nearbyCount = 0
            do {
                nearbyCount = await playerLocationService?.queryNearbyPlayerCount(at: location) ?? 0
                logger.log("附近玩家查询成功: \(nearbyCount) 人", type: .success)
            } catch {
                logger.log("附近玩家查询失败（使用默认值0）: \(error.localizedDescription)", type: .warning)
            }

            let density = PlayerDensityLevel.from(playerCount: nearbyCount)
            let poiCount = density.recommendedPOICount

            logger.log("密度等级: \(density.displayName)，推荐POI数量: \(poiCount)", type: .info)

            // 3. 根据密度搜索指定数量的POI
            logger.log("正在搜索POI（数量: \(poiCount)）...", type: .info)
            let pois = try await poiSearchManager.searchNearbyPOIs(center: location, maxCount: poiCount)
            nearbyPOIs = pois

            logger.log("✅ 找到 \(pois.count) 个附近POI", type: .success)
            for poi in pois {
                logger.log("  - \(poi.name) (\(poi.type.displayName))", type: .info)
            }

            // 4. 设置围栏监控
            logger.log("正在设置围栏监控...", type: .info)
            for poi in pois {
                locationManager?.startMonitoringPOI(poi)
            }
            logger.log("围栏监控设置完成，共 \(pois.count) 个", type: .success)

            // 5. 设置围栏进入回调
            locationManager?.onRegionEntered = { [weak self] regionId in
                Task { @MainActor in
                    self?.handleRegionEntered(regionId: regionId)
                }
            }

        } catch {
            logger.log("❌ 搜索POI失败: \(error.localizedDescription)", type: .error)
            logger.log("错误详情: \(error)", type: .error)
        }
    }

    /// 处理进入围栏事件
    private func handleRegionEntered(regionId: String) {
        // 查找对应的POI
        guard let poi = nearbyPOIs.first(where: { $0.regionIdentifier == regionId }),
              !poi.isScavenged else {
            return
        }

        logger.log("进入POI范围: \(poi.name)", type: .success)

        // 设置当前POI并显示弹窗
        currentScavengePOI = poi
        showPOIPopup = true
    }

    /// 执行搜刮
    func performScavenge() {
        guard let poi = currentScavengePOI else { return }

        logger.log("开始搜刮: \(poi.name)", type: .info)

        // 生成奖励（使用银级奖励作为POI搜刮的默认等级）
        let tier = RewardTier.silver
        let lootItems = RewardGenerator.generateRewards(tier: tier, source: poi.name)

        // 保存搜刮结果
        scavengeLootItems = lootItems

        // 标记POI已搜刮
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].isScavenged = true
        }

        // 更新搜刮计数
        scavengedPOICount += 1

        // 停止监控该围栏
        locationManager?.stopMonitoringPOI(identifier: poi.regionIdentifier)

        // 添加物品到背包
        Task {
            do {
                try await inventoryManager?.addItems(lootItems, explorationSessionId: currentSessionId)
                logger.log("物品已添加到背包: \(lootItems.count)件", type: .success)
            } catch {
                logger.log("添加物品失败: \(error)", type: .error)
            }
        }

        // 关闭接近弹窗，显示结果弹窗
        showPOIPopup = false
        showScavengeResult = true

        logger.log("搜刮完成，获得 \(lootItems.count) 件物品", type: .success)
    }

    /// 跳过搜刮
    func skipScavenge() {
        logger.log("跳过搜刮: \(currentScavengePOI?.name ?? "")", type: .info)
        showPOIPopup = false
        currentScavengePOI = nil
    }

    /// 关闭搜刮结果
    func closeScavengeResult() {
        showScavengeResult = false
        scavengeLootItems = []
        currentScavengePOI = nil
    }

    /// 清理POI和围栏
    private func cleanupPOIs() {
        locationManager?.stopMonitoringAllPOIs()
        locationManager?.onRegionEntered = nil
        nearbyPOIs.removeAll()
        currentScavengePOI = nil
        showPOIPopup = false
        showScavengeResult = false
        scavengeLootItems = []
        scavengedPOICount = 0
        logger.log("已清理所有POI和围栏", type: .info)
    }

    // MARK: - 格式化辅助方法

    /// 格式化距离显示
    var formattedDistance: String {
        if currentDistance >= 1000 {
            return String(format: "%.2f km", currentDistance / 1000)
        } else {
            return String(format: "%.0f m", currentDistance)
        }
    }

    /// 格式化时长显示
    var formattedDuration: String {
        let minutes = Int(currentDuration) / 60
        let seconds = Int(currentDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 格式化速度显示
    var formattedSpeed: String {
        return String(format: "%.1f km/h", currentSpeed)
    }
}

// MARK: - 错误类型

enum ExplorationError: LocalizedError {
    case notAuthenticated
    case noActiveSession
    case sessionCreationFailed
    case networkError
    case overSpeed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .noActiveSession:
            return "没有进行中的探索"
        case .sessionCreationFailed:
            return "创建探索会话失败"
        case .networkError:
            return "网络错误"
        case .overSpeed:
            return "速度超过限制"
        }
    }
}
