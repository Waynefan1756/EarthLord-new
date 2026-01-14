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
    /// - Parameter center: 搜索中心点坐标（WGS-84）
    /// - Returns: 搜索到的POI列表
    func searchNearbyPOIs(center: CLLocationCoordinate2D) async throws -> [ExplorablePOI] {
        isSearching = true
        errorMessage = nil
        searchResults = []

        defer { isSearching = false }

        logger.log("开始搜索附近POI，中心点: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))", type: .info)

        var allPOIs: [ExplorablePOI] = []

        // 为每个类别执行搜索
        for category in searchCategories {
            // 达到数量限制后停止
            if allPOIs.count >= maxPOICount {
                logger.log("已达到POI数量上限(\(maxPOICount))，停止搜索", type: .info)
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

        // 按距离排序并截取
        let sortedPOIs = sortByDistance(pois: uniquePOIs, from: center)
        let finalPOIs = Array(sortedPOIs.prefix(maxPOICount))

        searchResults = finalPOIs

        logger.log("POI搜索完成，找到 \(finalPOIs.count) 个唯一POI", type: .success)

        return finalPOIs
    }

    // MARK: - Private Methods

    /// 搜索指定类别的POI
    /// - Parameters:
    ///   - center: 搜索中心点
    ///   - category: POI类别
    /// - Returns: 搜索到的POI列表
    private func searchPOIs(center: CLLocationCoordinate2D, category: MKPointOfInterestCategory) async throws -> [ExplorablePOI] {
        let request = MKLocalPointsOfInterestRequest(center: center, radius: searchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.compactMap { ExplorablePOI.from(mapItem: $0) }
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
