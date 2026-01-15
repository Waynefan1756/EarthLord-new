//
//  POISearchManager.swift
//  EarthLord
//
//  POI搜索管理器
//  使用MKLocalSearch搜索附近1公里内的真实POI
//

import Foundation
import MapKit
import CoreLocation
import Combine

/// POI搜索管理器
/// 负责调用MapKit搜索附近真实地点并转换为游戏可用的POI
@MainActor
class POISearchManager: ObservableObject {

    // MARK: - Published Properties

    /// 搜索结果列表
    @Published var searchResults: [ExplorablePOI] = []

    /// 是否正在搜索
    @Published var isSearching: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Constants

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// 最大返回POI数量（iOS围栏限制20个，预留5个余量）
    private let maxPOICount: Int = 15

    /// 搜索的POI类别列表
    private let searchCategories: [MKPointOfInterestCategory] = [
        .store,         // 商店
        .foodMarket,    // 超市
        .hospital,      // 医院
        .pharmacy,      // 药店
        .gasStation,    // 加油站
        .restaurant,    // 餐厅
        .cafe,          // 咖啡店
        .bank,          // 银行
        .bakery         // 面包店
    ]

    // MARK: - Private Properties

    private let logger = ExplorationLogger.shared

    // MARK: - Public Methods

    /// 搜索附近POI
    /// - Parameters:
    ///   - center: 搜索中心点坐标（WGS-84）
    ///   - maxCount: 最大返回POI数量（可选，默认使用maxPOICount）
    /// - Returns: 搜索到的POI列表
    func searchNearbyPOIs(center: CLLocationCoordinate2D, maxCount: Int? = nil) async throws -> [ExplorablePOI] {
        isSearching = true
        errorMessage = nil
        searchResults = []

        defer { isSearching = false }

        // 使用传入的maxCount或默认值，并限制在1-15范围内
        let effectiveMaxCount = min(max(maxCount ?? maxPOICount, 1), maxPOICount)

        logger.log("🔍 开始搜索附近POI", type: .info)
        logger.log("  中心点: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))", type: .info)
        logger.log("  搜索半径: \(Int(searchRadius))米", type: .info)
        logger.log("  目标数量: \(effectiveMaxCount)", type: .info)
        logger.log("  搜索类别数: \(searchCategories.count)", type: .info)

        var allPOIs: [ExplorablePOI] = []

        // 为每个类别执行搜索
        for category in searchCategories {
            // 达到数量限制后停止
            if allPOIs.count >= maxPOICount {
                logger.log("已达到POI搜索上限(\(maxPOICount))，停止搜索", type: .info)
                break
            }

            do {
                let pois = try await searchPOIs(center: center, category: category)
                allPOIs.append(contentsOf: pois)
                logger.log("搜索 \(category.rawValue) 找到 \(pois.count) 个结果", type: .info)
            } catch {
                // 单个类别搜索失败不影响整体
                logger.log("搜索 \(category.rawValue) 失败: \(error.localizedDescription)", type: .warning)
            }
        }

        // 去重（基于名称）
        let uniquePOIs = removeDuplicates(pois: allPOIs)

        // 按距离排序并截取（使用effectiveMaxCount）
        let sortedPOIs = sortByDistance(pois: uniquePOIs, from: center)
        var finalPOIs = Array(sortedPOIs.prefix(effectiveMaxCount))

        // ⭐ 备用方案：如果没有找到真实POI，生成测试POI
        if finalPOIs.isEmpty {
            logger.log("⚠️ MapKit未找到POI，生成测试POI", type: .warning)
            finalPOIs = generateFallbackPOIs(center: center, count: effectiveMaxCount)
        }

        searchResults = finalPOIs

        logger.log("POI搜索完成，找到 \(finalPOIs.count) 个POI（目标: \(effectiveMaxCount)）", type: .success)

        return finalPOIs
    }

    // MARK: - 备用POI生成

    /// 生成备用测试POI（当MapKit搜索无结果时使用）
    /// - Parameters:
    ///   - center: 中心点坐标
    ///   - count: 生成数量
    /// - Returns: 测试POI列表
    private func generateFallbackPOIs(center: CLLocationCoordinate2D, count: Int) -> [ExplorablePOI] {
        var pois: [ExplorablePOI] = []

        // 测试POI配置：名称、类型、相对于中心点的偏移（米）
        let testPOIConfigs: [(name: String, type: POIType, offsetLat: Double, offsetLon: Double)] = [
            ("荒废超市", .supermarket, 50, 30),
            ("破旧药房", .pharmacy, -40, 60),
            ("废弃加油站", .gasStation, 80, -20),
            ("废弃医院", .hospital, -60, -50),
            ("废弃工厂", .factory, 30, -70),
            ("荒废仓库", .warehouse, -80, 40),
            ("废弃住宅", .residential, 70, 70),
        ]

        // 1度纬度约111km，1度经度约111km*cos(lat)
        let metersPerDegreeLat = 111000.0
        let metersPerDegreeLon = 111000.0 * cos(center.latitude * .pi / 180.0)

        for i in 0..<min(count, testPOIConfigs.count) {
            let config = testPOIConfigs[i]

            // 计算偏移后的坐标
            let lat = center.latitude + (config.offsetLat / metersPerDegreeLat)
            let lon = center.longitude + (config.offsetLon / metersPerDegreeLon)

            let poi = ExplorablePOI(
                id: UUID().uuidString,
                name: config.name,
                type: config.type,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                isScavenged: false
            )
            pois.append(poi)

            logger.log("  生成测试POI: \(config.name) at (\(String(format: "%.6f", lat)), \(String(format: "%.6f", lon)))", type: .info)
        }

        return pois
    }

    // MARK: - Private Methods

    /// 搜索指定类别的POI
    /// - Parameters:
    ///   - center: 搜索中心点
    ///   - category: POI类别
    /// - Returns: 搜索到的POI列表
    private func searchPOIs(center: CLLocationCoordinate2D, category: MKPointOfInterestCategory) async throws -> [ExplorablePOI] {
        logger.log("  搜索类别: \(category.rawValue)", type: .info)

        let request = MKLocalPointsOfInterestRequest(center: center, radius: searchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        logger.log("  MapKit返回 \(response.mapItems.count) 个结果", type: .info)

        let pois = response.mapItems.compactMap { ExplorablePOI.from(mapItem: $0) }
        logger.log("  转换后有效POI: \(pois.count) 个", type: .info)

        return pois
    }

    /// 移除重复POI（基于名称去重）
    /// - Parameter pois: 原始POI列表
    /// - Returns: 去重后的POI列表
    private func removeDuplicates(pois: [ExplorablePOI]) -> [ExplorablePOI] {
        var seen: Set<String> = []
        var unique: [ExplorablePOI] = []

        for poi in pois {
            // 使用小写名称作为去重key
            let key = poi.name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(poi)
            }
        }

        return unique
    }

    /// 按距离排序POI
    /// - Parameters:
    ///   - pois: POI列表
    ///   - from: 参考点坐标
    /// - Returns: 按距离从近到远排序的POI列表
    private func sortByDistance(pois: [ExplorablePOI], from center: CLLocationCoordinate2D) -> [ExplorablePOI] {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return pois.sorted { poi1, poi2 in
            let loc1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let loc2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            return loc1.distance(from: centerLocation) < loc2.distance(from: centerLocation)
        }
    }
}
