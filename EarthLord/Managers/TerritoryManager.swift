//
//  TerritoryManager.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/7.
//

import Foundation
import CoreLocation
import Supabase

/// 领地管理器 - 负责上传和拉取领地数据
@MainActor
class TerritoryManager {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - 上传数据结构

    /// 领地上传数据结构（用于编码）
    private struct TerritoryUpload: Encodable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    // MARK: - 数据转换方法

    /// 将坐标数组转换为 path JSON 格式 [{"lat": x, "lon": y}, ...]
    /// - Parameter coordinates: 坐标数组
    /// - Returns: Path JSON 数组
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            return [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT 格式（用于 PostGIS）
    /// ⚠️ WKT 格式是「经度在前，纬度在后」
    /// ⚠️ 多边形必须闭合（首尾相同）
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 字符串，格式：SRID=4326;POLYGON((lon lat, lon lat, ...))
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保多边形闭合
        var points = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                points.append(first) // 添加首点以闭合多边形
            }
        }

        // 转换为 WKT 格式：经度在前，纬度在后
        let wktPoints = points.map { "\($0.longitude) \($0.latitude)" }.joined(separator: ", ")
        return "SRID=4326;POLYGON((\(wktPoints)))"
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLon: lons.min() ?? 0,
            maxLon: lons.max() ?? 0
        )
    }

    // MARK: - 上传领地

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 领地坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        do {
            // 获取当前用户 ID
            let session = try await supabase.auth.session
            let userId = session.user.id

            // 转换坐标数据
            let pathJSON = coordinatesToPathJSON(coordinates)
            let wktPolygon = coordinatesToWKT(coordinates)
            let bbox = calculateBoundingBox(coordinates)

            // 构建上传数据
            let territoryData = TerritoryUpload(
                userId: userId.uuidString,
                path: pathJSON,
                polygon: wktPolygon,
                bboxMinLat: bbox.minLat,
                bboxMaxLat: bbox.maxLat,
                bboxMinLon: bbox.minLon,
                bboxMaxLon: bbox.maxLon,
                area: area,
                pointCount: coordinates.count,
                startedAt: ISO8601DateFormatter().string(from: startTime),
                isActive: true
            )

            // 上传到 Supabase
            try await supabase
                .from("territories")
                .insert(territoryData)
                .execute()

            print("✅ 领地上传成功")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)

        } catch {
            print("❌ 领地上传失败: \(error.localizedDescription)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            throw error
        }
    }

    // MARK: - 拉取领地

    /// 加载所有激活的领地
    /// - Returns: 领地数组
    /// - Throws: 加载失败时抛出错误
    func loadAllTerritories() async throws -> [Territory] {
        let territories: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value

        print("✅ 成功加载 \(territories.count) 个领地")
        return territories
    }
}
