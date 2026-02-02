//
//  BuildingModels.swift
//  EarthLord
//
//  建筑系统数据模型
//  包含建筑分类、状态、模板和玩家建筑模型
//

import Foundation

// MARK: - 建筑分类

/// 建筑分类
enum BuildingCategory: String, Codable, CaseIterable {
    case survival    // 生存类
    case storage     // 存储类
    case production  // 生产类
    case energy      // 能源类

    /// 显示名称
    var displayName: String {
        switch self {
        case .survival:
            return "生存"
        case .storage:
            return "存储"
        case .production:
            return "生产"
        case .energy:
            return "能源"
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .survival:
            return "heart.fill"
        case .storage:
            return "archivebox.fill"
        case .production:
            return "hammer.fill"
        case .energy:
            return "bolt.fill"
        }
    }
}

// MARK: - 建筑状态

/// 建筑状态
enum BuildingStatus: String, Codable {
    case constructing  // 建造中
    case active        // 已完成/激活

    /// 显示名称
    var displayName: String {
        switch self {
        case .constructing:
            return "建造中"
        case .active:
            return "已完成"
        }
    }
}

// MARK: - 建筑模板

/// 建筑模板（从JSON加载）
struct BuildingTemplate: Codable, Identifiable {
    let id: String                        // 如 "campfire"
    let name: String                      // 如 "篝火"
    let category: BuildingCategory
    let tier: Int                         // 等级 1-3
    let description: String
    let icon: String                      // SF Symbol
    let requiredResources: [String: Int]  // {"item_wood": 30, "item_stone": 20}
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    enum CodingKeys: String, CodingKey {
        case id, name, category, tier, description, icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }
}

// MARK: - 玩家建筑数据库模型

/// 玩家建筑数据库模型（用于与 Supabase 交互）
struct PlayerBuildingDB: Codable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: String
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为 App 内使用的 PlayerBuilding 模型
    func toPlayerBuilding(template: BuildingTemplate) -> PlayerBuilding {
        let buildingStatus = BuildingStatus(rawValue: status) ?? .constructing
        return PlayerBuilding(
            id: id.uuidString,
            template: template,
            territoryId: territoryId,
            status: buildingStatus,
            level: level,
            locationLat: locationLat,
            locationLon: locationLon,
            buildStartedAt: buildStartedAt,
            buildCompletedAt: buildCompletedAt
        )
    }
}

/// 插入玩家建筑的请求模型
struct InsertPlayerBuilding: Codable {
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
    }
}

// MARK: - 玩家建筑应用层模型

/// 玩家建筑（应用层模型）
struct PlayerBuilding: Identifiable {
    let id: String
    let template: BuildingTemplate
    let territoryId: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?

    /// 剩余建造时间（秒）
    var remainingBuildTime: TimeInterval? {
        guard status == .constructing else { return nil }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let remaining = TimeInterval(template.buildTimeSeconds) - elapsed
        return max(0, remaining)
    }

    /// 建造进度（0.0 - 1.0）
    var buildProgress: Double {
        guard status == .constructing else { return 1.0 }
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        let total = TimeInterval(template.buildTimeSeconds)
        return min(1.0, elapsed / total)
    }

    /// 是否建造完成
    var isConstructionComplete: Bool {
        if status == .active { return true }
        guard let remaining = remainingBuildTime else { return true }
        return remaining <= 0
    }

    /// 是否可以升级
    var canUpgrade: Bool {
        return status == .active && level < template.maxLevel
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        guard let remaining = remainingBuildTime, remaining > 0 else { return "已完成" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return minutes > 0 ? "\(minutes)分\(seconds)秒" : "\(seconds)秒"
    }
}

// MARK: - 资源检查结果

/// 资源检查结果
struct ResourceCheckResult {
    let canBuild: Bool
    let missingResources: [String: Int]  // 缺少的资源
    let availableResources: [String: Int]  // 当前拥有的资源

    /// 是否资源充足
    var hasEnoughResources: Bool {
        return missingResources.isEmpty
    }
}

// MARK: - 建筑错误类型

/// 建筑错误类型
enum BuildingError: LocalizedError {
    case notAuthenticated
    case templateNotFound
    case insufficientResources([String: Int])  // 缺少的资源
    case maxBuildingsReached(Int)
    case invalidStatus
    case alreadyCompleted
    case cannotUpgrade
    case buildingNotFound
    case templateLoadFailed
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .templateNotFound:
            return "建筑模板不存在"
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "资源不足: \(items)"
        case .maxBuildingsReached(let max):
            return "已达到最大建筑数量限制: \(max)"
        case .invalidStatus:
            return "建筑状态无效"
        case .alreadyCompleted:
            return "建筑已完成"
        case .cannotUpgrade:
            return "无法升级建筑"
        case .buildingNotFound:
            return "建筑不存在"
        case .templateLoadFailed:
            return "加载建筑模板失败"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        }
    }
}
