//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器：处理用户位置获取和权限请求
//

import Foundation
import CoreLocation
import Combine

// MARK: - LocationManager
/// GPS 定位管理器
/// 负责请求定位权限、获取用户位置、处理定位错误
class LocationManager: NSObject, ObservableObject {

    // MARK: - Properties

    /// CoreLocation 管理器
    private let locationManager = CLLocationManager()

    /// 用户当前位置（经纬度）
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - Path Tracking Properties

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 会用）
    @Published var isPathClosed: Bool = false

    /// 当前位置（私有，用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 采点定时器（每 2 秒检查一次）
    private var pathUpdateTimer: Timer?

    // MARK: - Path Closure Properties

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    // MARK: - 验证常量

    /// 最少路径点数（形成闭环的最低要求）
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算得到的面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - Speed Detection Properties

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 上次位置时间戳（用于计算速度）
    private var lastLocationTimestamp: Date?

    // MARK: - GPS Quality Monitoring

    /// GPS信号质量（0-100，0=最差，100=最好）
    @Published var gpsSignalQuality: Int = 100

    /// GPS漂移连续次数（用于检测持续的信号问题）
    private var consecutiveGpsDriftCount: Int = 0

    /// 最大允许连续漂移次数
    private let maxConsecutiveDrifts: Int = 5

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// 是否被拒绝授权
    var isDenied: Bool {
        return authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Initialization

    override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // 最高精度
        locationManager.distanceFilter = 10 // 移动10米才更新位置

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    /// 请求定位权限（使用App期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始定位
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "未获得定位权限"
            return
        }
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Path Tracking Methods

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            locationError = "未获得定位权限，无法开始圈地"
            return
        }

        // 标记开始追踪
        isTracking = true
        isPathClosed = false

        // 清空旧路径
        pathCoordinates.removeAll()
        pathUpdateVersion += 1

        // ⭐ 重置GPS监控状态
        consecutiveGpsDriftCount = 0
        gpsSignalQuality = 100
        speedWarning = nil
        isOverSpeed = false

        // 启动定时器（每 2 秒检查一次）
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("✅ 开始圈地追踪")
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)
    }

    /// 停止路径追踪
    func stopPathTracking() {
        isTracking = false

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        print("⏹️ 停止圈地追踪，共记录 \(pathCoordinates.count) 个点")
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // ⚠️ 重置所有状态（防止重复上传）
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        print("🗑️ 路径已清除")
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 确保有当前位置
        guard let location = currentLocation else {
            print("⚠️ 当前位置为空，跳过采点")
            return
        }

        // ⭐ GPS 精度检查：过滤精度太差的点
        if !validateGPSAccuracy(location) {
            print("⚠️ GPS 精度太差，跳过该点")
            return
        }

        // ⭐ 速度检测：防止作弊
        if !validateMovementSpeed(newLocation: location) {
            print("⚠️ 速度异常，跳过该点")
            return
        }

        // 如果是第一个点，直接记录
        if pathCoordinates.isEmpty {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = Date()
            print("📍 记录第 1 个点：\(location.coordinate.latitude), \(location.coordinate.longitude)")
            TerritoryLogger.shared.log("记录第 1 个点", type: .info)
            return
        }

        // 计算与上个点的距离
        guard let lastCoordinate = pathCoordinates.last else { return }
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)

        // 距离大于 10 米才记录新点
        if distance > 10 {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = Date()
            print("📍 记录第 \(pathCoordinates.count) 个点，距离上个点 \(String(format: "%.1f", distance)) 米")
            TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distance))m", type: .info)

            // ⭐ 检查是否形成闭环
            checkPathClosure()
        }
    }

    // MARK: - Path Closure Detection

    /// 检查路径是否形成闭环
    private func checkPathClosure() {
        // 已经闭环了，不再检查
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("⚪ 闭环检测：点数不足（需要 \(minimumPathPoints) 个，当前 \(pathCoordinates.count) 个）")
            return
        }

        // 获取起点和终点
        guard let startCoordinate = pathCoordinates.first,
              let endCoordinate = pathCoordinates.last else { return }

        // 计算起点和终点的距离
        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let endLocation = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
        let distance = startLocation.distance(from: endLocation)

        // 判断是否在闭环阈值内
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1
            print("✅ 闭环检测成功！起点到终点距离：\(String(format: "%.1f", distance)) 米")
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)

            // ⭐ 闭环成功后，自动触发领地验证
            let validationResult = validateTerritory()
            if validationResult.isValid {
                // 验证通过
                territoryValidationPassed = true
                territoryValidationError = nil
                calculatedArea = calculatePolygonArea()
            } else {
                // 验证失败
                territoryValidationPassed = false
                territoryValidationError = validationResult.errorMessage
                calculatedArea = 0
            }
        } else {
            print("⚪ 闭环检测：距离起点 \(String(format: "%.1f", distance)) 米（需要 ≤ \(closureDistanceThreshold) 米）")
            TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m)", type: .info)
        }
    }

    // MARK: - GPS Accuracy & Speed Detection

    /// GPS 精度检查
    /// - Parameter location: 位置对象
    /// - Returns: true = 精度可接受，false = 精度太差
    private func validateGPSAccuracy(_ location: CLLocation) -> Bool {
        // horizontalAccuracy < 0 表示无效定位
        guard location.horizontalAccuracy >= 0 else {
            print("⚠️ GPS 定位无效")
            updateGPSQuality(0)
            return false
        }

        // ⭐ 检查速度精度（iOS 提供的速度误差估计）
        // speedAccuracy < 0 表示速度无效或不可用
        let hasValidSpeed = location.speedAccuracy >= 0

        // horizontalAccuracy 表示精度半径（米）
        // 动态调整精度阈值：如果有有效的速度数据，可以放宽位置精度要求
        let accuracyThreshold: Double = hasValidSpeed ? 40 : 30

        if location.horizontalAccuracy > accuracyThreshold {
            print("⚠️ GPS 精度太差：±\(String(format: "%.1f", location.horizontalAccuracy))m，已忽略")
            TerritoryLogger.shared.log("GPS精度差 ±\(String(format: "%.1f", location.horizontalAccuracy))m", type: .warning)

            // 更新GPS信号质量（精度越差，质量越低）
            let quality = max(0, Int((1 - location.horizontalAccuracy / 100) * 100))
            updateGPSQuality(quality)

            return false
        }

        // ⭐ 如果速度精度太差（误差 > 10 m/s），也标记为信号不佳
        if hasValidSpeed && location.speedAccuracy > 10 {
            print("⚠️ GPS 速度精度差：±\(String(format: "%.1f", location.speedAccuracy)) m/s")
            TerritoryLogger.shared.log("GPS速度精度差 ±\(String(format: "%.1f", location.speedAccuracy))m/s", type: .warning)

            let quality = max(0, Int((1 - location.speedAccuracy / 20) * 100))
            updateGPSQuality(quality)

            return false
        }

        // 精度良好，更新信号质量
        let quality = max(50, Int((1 - location.horizontalAccuracy / 50) * 100))
        updateGPSQuality(quality)

        return true
    }

    /// 更新GPS信号质量指标
    /// - Parameter quality: 信号质量 (0-100)
    private func updateGPSQuality(_ quality: Int) {
        let clampedQuality = min(100, max(0, quality))

        DispatchQueue.main.async { [weak self] in
            self?.gpsSignalQuality = clampedQuality
        }
    }

    /// 验证移动速度（防作弊 + GPS漂移检测）
    /// - Parameter newLocation: 新位置
    /// - Returns: true = 速度正常，false = 速度异常（忽略该点）
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 第一个点，直接通过
        guard let lastTimestamp = lastLocationTimestamp,
              let lastCoordinate = pathCoordinates.last else {
            // 重置漂移计数器
            consecutiveGpsDriftCount = 0
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)

        // ⚠️ 时间间隔太短时不计算速度（GPS 精度不够）
        guard timeInterval >= 2.0 else {
            print("⏱️ 时间间隔太短（\(String(format: "%.1f", timeInterval))秒），跳过速度检测")
            return true
        }

        // 计算速度（km/h）
        let speedMeterPerSecond = distance / timeInterval
        let speedKmPerHour = speedMeterPerSecond * 3.6

        // ⭐ 多级速度检测逻辑
        if speedKmPerHour > 100 {
            // 🚨 超过 100 km/h：极端GPS漂移，必定是信号问题
            handleGpsDrift(speedKmPerHour: speedKmPerHour, severity: "极端")
            consecutiveGpsDriftCount += 1

            // 如果连续多次漂移，给用户明确提示
            if consecutiveGpsDriftCount >= maxConsecutiveDrifts {
                speedWarning = "GPS信号持续不稳定，建议移动至空旷区域"
                TerritoryLogger.shared.log("GPS信号持续不稳定（连续\(consecutiveGpsDriftCount)次漂移）", type: .error)
            }

            return false

        } else if speedKmPerHour > 50 {
            // ⚠️ 超过 50 km/h：明显的GPS漂移（可能是信号跳变）
            handleGpsDrift(speedKmPerHour: speedKmPerHour, severity: "严重")
            consecutiveGpsDriftCount += 1

            if consecutiveGpsDriftCount >= 3 {
                speedWarning = "GPS信号不稳定，建议稍后再试"
                TerritoryLogger.shared.log("GPS连续漂移\(consecutiveGpsDriftCount)次", type: .warning)
            }

            return false

        } else if speedKmPerHour > 20 {
            // ⚠️ 超过 20 km/h：可能在骑车/跑步，或轻微GPS漂移
            speedWarning = "速度较快（\(String(format: "%.1f", speedKmPerHour)) km/h），请减速至步行"
            isOverSpeed = true
            print("⚠️ 速度警告（\(String(format: "%.1f", speedKmPerHour)) km/h）")
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmPerHour)) km/h", type: .warning)

            // 轻微超速不计入漂移次数
            consecutiveGpsDriftCount = 0
            return true

        } else {
            // ✅ 速度正常（≤ 20 km/h）
            speedWarning = nil
            isOverSpeed = false
            consecutiveGpsDriftCount = 0 // 重置漂移计数器
            return true
        }
    }

    /// 处理GPS漂移情况
    /// - Parameters:
    ///   - speedKmPerHour: 计算出的速度
    ///   - severity: 严重程度描述
    private func handleGpsDrift(speedKmPerHour: Double, severity: String) {
        speedWarning = "GPS信号不稳定（\(severity)漂移 \(String(format: "%.0f", speedKmPerHour)) km/h）"
        isOverSpeed = true

        let logMessage = "GPS\(severity)漂移 \(String(format: "%.0f", speedKmPerHour)) km/h，已忽略异常点"
        TerritoryLogger.shared.log(logMessage, type: .warning)
        print("⚠️ \(logMessage)")

        // 降低GPS信号质量评分
        updateGPSQuality(max(0, gpsSignalQuality - 20))
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = CLLocation(
                latitude: pathCoordinates[i].latitude,
                longitude: pathCoordinates[i].longitude
            )
            let next = CLLocation(
                latitude: pathCoordinates[i + 1].latitude,
                longitude: pathCoordinates[i + 1].longitude
            )
            totalDistance += current.distance(from: next)
        }

        return totalDistance
    }

    /// 计算多边形面积（使用鞋带公式，考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true = 相交，false = 不相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                     p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        // CCW 辅助函数：判断三点是否逆时针
        // 输入：3 个坐标点（A, B, C）
        // 返回：叉积 > 0 则为 true（逆时针）
        func ccw(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            let crossProduct = (c.latitude - a.latitude) * (b.longitude - a.longitude) -
                               (b.latitude - a.latitude) * (c.longitude - a.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：
        // 两条线段相交 ⟺
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且
        // ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) &&
               ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测整条路径是否自相交
    /// - Returns: true = 有自交，false = 无自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount
                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 验证领地是否符合规则
    /// - Returns: (isValid: 是否通过, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        if pathCoordinates.count < minimumPathPoints {
            let errorMsg = "点数不足: \(pathCoordinates.count)个点 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(errorMsg) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("点数检查: \(pathCoordinates.count)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let errorMsg = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(errorMsg) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let errorMsg = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(errorMsg) ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // ✅ 所有验证通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态改变
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // 如果已授权，自动开始定位
        if isAuthorized {
            startUpdatingLocation()
        }
    }

    /// 位置更新成功
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // ⭐ 更新当前位置（Timer 需要用这个）
        currentLocation = location

        // 更新用户位置
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
        }
    }

    /// 位置更新失败
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "定位失败：\(error.localizedDescription)"
        }
    }
}
