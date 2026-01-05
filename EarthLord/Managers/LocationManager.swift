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

    /// 最少路径点数（形成闭环的最低要求）
    private let minimumPathPoints: Int = 10

    // MARK: - Speed Detection Properties

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    /// 上次位置时间戳（用于计算速度）
    private var lastLocationTimestamp: Date?

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

        // ⭐ 速度检测：防止作弊
        if !validateMovementSpeed(newLocation: location) {
            print("⚠️ 速度超标，跳过该点")
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
        } else {
            print("⚪ 闭环检测：距离起点 \(String(format: "%.1f", distance)) 米（需要 ≤ \(closureDistanceThreshold) 米）")
            TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m)", type: .info)
        }
    }

    // MARK: - Speed Detection

    /// 验证移动速度（防作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: true = 速度正常，false = 速度超标
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 第一个点，直接通过
        guard let lastTimestamp = lastLocationTimestamp,
              let lastCoordinate = pathCoordinates.last else {
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)

        // 避免除零错误
        guard timeInterval > 0 else { return true }

        // 计算速度（km/h）
        let speedMeterPerSecond = distance / timeInterval
        let speedKmPerHour = speedMeterPerSecond * 3.6

        // 速度检测
        if speedKmPerHour > 30 {
            // 超过 30 km/h，暂停追踪
            speedWarning = "速度过快（\(String(format: "%.1f", speedKmPerHour)) km/h），已暂停圈地"
            isOverSpeed = true
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmPerHour)) km/h，已停止追踪", type: .error)
            stopPathTracking()
            print("🚫 速度过快（\(String(format: "%.1f", speedKmPerHour)) km/h），已暂停圈地")
            return false
        } else if speedKmPerHour > 15 {
            // 超过 15 km/h，警告但继续
            speedWarning = "速度较快（\(String(format: "%.1f", speedKmPerHour)) km/h），请减速"
            isOverSpeed = true
            print("⚠️ 速度警告（\(String(format: "%.1f", speedKmPerHour)) km/h）")
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmPerHour)) km/h", type: .warning)
            return true
        } else {
            // 速度正常
            speedWarning = nil
            isOverSpeed = false
            return true
        }
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
