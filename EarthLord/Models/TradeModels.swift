//
//  TradeModels.swift
//  EarthLord
//
//  交易系统数据模型
//  包含挂单、交易历史、评分等模型定义
//

import Foundation

// MARK: - 挂单状态

/// 挂单状态
enum TradeOfferStatus: String, Codable, CaseIterable {
    case active = "active"          // 进行中
    case completed = "completed"    // 已完成
    case cancelled = "cancelled"    // 已取消
    case expired = "expired"        // 已过期

    /// 显示名称
    var displayName: String {
        switch self {
        case .active:
            return "进行中"
        case .completed:
            return "已完成"
        case .cancelled:
            return "已取消"
        case .expired:
            return "已过期"
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .active:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .expired:
            return "exclamationmark.circle.fill"
        }
    }

    /// 颜色名称
    var colorName: String {
        switch self {
        case .active:
            return "green"
        case .completed:
            return "blue"
        case .cancelled:
            return "gray"
        case .expired:
            return "orange"
        }
    }
}

// MARK: - 交易评分

/// 交易评分 (1-5)
enum TradeRating: Int, Codable, CaseIterable {
    case terrible = 1   // 很差
    case poor = 2       // 较差
    case average = 3    // 一般
    case good = 4       // 良好
    case excellent = 5  // 优秀

    /// 显示名称
    var displayName: String {
        switch self {
        case .terrible:
            return "很差"
        case .poor:
            return "较差"
        case .average:
            return "一般"
        case .good:
            return "良好"
        case .excellent:
            return "优秀"
        }
    }

    /// 星级图标（用于显示）
    var stars: String {
        return String(repeating: "★", count: rawValue) + String(repeating: "☆", count: 5 - rawValue)
    }
}

// MARK: - 交易物品

/// 交易物品条目
struct TradeItem: Codable, Identifiable, Equatable {
    let id: String              // 唯一标识（用于UI）
    let itemId: String          // 物品定义ID
    let quantity: Int           // 数量
    let quality: String?        // 品质（可选）

    init(id: String = UUID().uuidString, itemId: String, quantity: Int, quality: String? = nil) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
    }

    /// 获取物品定义
    var definition: ItemDefinition? {
        return ItemDefinitions.get(itemId)
    }

    /// 显示名称
    var displayName: String {
        guard let def = definition else { return itemId }
        var name = def.name
        if let q = quality, let itemQuality = ItemQuality(rawValue: q) {
            name += " (\(itemQuality.displayName))"
        }
        return "\(name) x\(quantity)"
    }
}

// MARK: - 挂单数据库模型

/// 挂单数据库模型（用于与 Supabase 交互）
struct TradeOfferDB: Codable {
    let id: UUID
    let ownerId: UUID
    let ownerUsername: String
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    let status: String
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    let completedAt: Date?
    let completedByUserId: UUID?
    let completedByUsername: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case completedByUsername = "completed_by_username"
    }

    /// 转换为应用层模型
    func toTradeOffer() -> TradeOffer {
        let offerStatus = TradeOfferStatus(rawValue: status) ?? .active
        return TradeOffer(
            id: id.uuidString,
            ownerId: ownerId.uuidString,
            ownerUsername: ownerUsername,
            offeringItems: offeringItems,
            requestingItems: requestingItems,
            status: offerStatus,
            message: message,
            createdAt: createdAt,
            expiresAt: expiresAt,
            completedAt: completedAt,
            completedByUserId: completedByUserId?.uuidString,
            completedByUsername: completedByUsername
        )
    }
}

/// 插入挂单的请求模型
struct InsertTradeOffer: Codable {
    let ownerId: UUID
    let ownerUsername: String
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    let status: String
    let message: String?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case message
        case expiresAt = "expires_at"
    }
}

// MARK: - 挂单应用层模型

/// 挂单（应用层模型）
struct TradeOffer: Identifiable {
    let id: String
    let ownerId: String
    let ownerUsername: String
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]
    var status: TradeOfferStatus
    let message: String?
    let createdAt: Date
    let expiresAt: Date
    var completedAt: Date?
    var completedByUserId: String?
    var completedByUsername: String?

    /// 是否已过期
    var isExpired: Bool {
        return Date() > expiresAt
    }

    /// 剩余时间（秒）
    var remainingTime: TimeInterval {
        let remaining = expiresAt.timeIntervalSince(Date())
        return max(0, remaining)
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        let remaining = remainingTime
        if remaining <= 0 {
            return "已过期"
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)天"
        } else if hours > 0 {
            return "\(hours)小时\(minutes)分"
        } else {
            return "\(minutes)分钟"
        }
    }

    /// 是否可以被接受（active 且未过期）
    var canBeAccepted: Bool {
        return status == .active && !isExpired
    }

    /// 是否可以被取消（active 状态）
    var canBeCancelled: Bool {
        return status == .active
    }

    /// 提供物品的总价值描述
    var offeringDescription: String {
        return offeringItems.map { $0.displayName }.joined(separator: ", ")
    }

    /// 索取物品的总价值描述
    var requestingDescription: String {
        return requestingItems.map { $0.displayName }.joined(separator: ", ")
    }
}

// MARK: - 交易历史数据库模型

/// 交易历史数据库模型（用于与 Supabase 交互）
struct TradeHistoryDB: Codable {
    let id: UUID
    let offerId: UUID
    let sellerId: UUID
    let sellerUsername: String
    let buyerId: UUID
    let buyerUsername: String
    let sellerItems: [TradeItem]
    let buyerItems: [TradeItem]
    let completedAt: Date
    let sellerRating: Int?
    let buyerRating: Int?
    let sellerComment: String?
    let buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case sellerItems = "seller_items"
        case buyerItems = "buyer_items"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }

    /// 转换为应用层模型
    func toTradeHistory() -> TradeHistory {
        return TradeHistory(
            id: id.uuidString,
            offerId: offerId.uuidString,
            sellerId: sellerId.uuidString,
            sellerUsername: sellerUsername,
            buyerId: buyerId.uuidString,
            buyerUsername: buyerUsername,
            sellerItems: sellerItems,
            buyerItems: buyerItems,
            completedAt: completedAt,
            sellerRating: sellerRating.flatMap { TradeRating(rawValue: $0) },
            buyerRating: buyerRating.flatMap { TradeRating(rawValue: $0) },
            sellerComment: sellerComment,
            buyerComment: buyerComment
        )
    }
}

/// 插入交易历史的请求模型
struct InsertTradeHistory: Codable {
    let offerId: UUID
    let sellerId: UUID
    let sellerUsername: String
    let buyerId: UUID
    let buyerUsername: String
    let sellerItems: [TradeItem]
    let buyerItems: [TradeItem]

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case sellerUsername = "seller_username"
        case buyerId = "buyer_id"
        case buyerUsername = "buyer_username"
        case sellerItems = "seller_items"
        case buyerItems = "buyer_items"
    }
}

// MARK: - 交易历史应用层模型

/// 交易历史（应用层模型）
struct TradeHistory: Identifiable {
    let id: String
    let offerId: String
    let sellerId: String
    let sellerUsername: String
    let buyerId: String
    let buyerUsername: String
    let sellerItems: [TradeItem]
    let buyerItems: [TradeItem]
    let completedAt: Date
    var sellerRating: TradeRating?
    var buyerRating: TradeRating?
    var sellerComment: String?
    var buyerComment: String?

    /// 格式化完成时间
    var formattedCompletedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: completedAt)
    }

    /// 检查用户是否是卖家
    func isSeller(userId: String) -> Bool {
        return sellerId == userId
    }

    /// 检查用户是否是买家
    func isBuyer(userId: String) -> Bool {
        return buyerId == userId
    }

    /// 获取交易对方用户名
    func counterpartyUsername(myUserId: String) -> String {
        if isSeller(userId: myUserId) {
            return buyerUsername
        } else {
            return sellerUsername
        }
    }

    /// 获取我方提供的物品
    func myItems(myUserId: String) -> [TradeItem] {
        if isSeller(userId: myUserId) {
            return sellerItems
        } else {
            return buyerItems
        }
    }

    /// 获取对方提供的物品
    func counterpartyItems(myUserId: String) -> [TradeItem] {
        if isSeller(userId: myUserId) {
            return buyerItems
        } else {
            return sellerItems
        }
    }

    /// 检查我是否已评价
    func hasRated(myUserId: String) -> Bool {
        if isSeller(userId: myUserId) {
            return buyerRating != nil  // 卖家给买家评分
        } else {
            return sellerRating != nil  // 买家给卖家评分
        }
    }

    /// 获取对方给我的评分
    func ratingReceived(myUserId: String) -> TradeRating? {
        if isSeller(userId: myUserId) {
            return sellerRating  // 买家给卖家的评分
        } else {
            return buyerRating  // 卖家给买家的评分
        }
    }
}

// MARK: - 交易错误类型

/// 交易错误类型
enum TradeError: LocalizedError {
    case notAuthenticated
    case userProfileNotFound
    case offerNotFound
    case offerExpired
    case offerNotActive
    case cannotAcceptOwnOffer
    case insufficientItems([String])      // 缺少的物品ID
    case inventoryItemNotFound(String)    // 找不到的物品ID
    case permissionDenied
    case alreadyRated
    case historyNotFound
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .userProfileNotFound:
            return "用户资料不存在"
        case .offerNotFound:
            return "挂单不存在"
        case .offerExpired:
            return "挂单已过期"
        case .offerNotActive:
            return "挂单状态无效"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .insufficientItems(let items):
            let names = items.compactMap { ItemDefinitions.get($0)?.name ?? $0 }
            return "物品不足: \(names.joined(separator: ", "))"
        case .inventoryItemNotFound(let itemId):
            let name = ItemDefinitions.get(itemId)?.name ?? itemId
            return "背包中找不到物品: \(name)"
        case .permissionDenied:
            return "没有权限执行此操作"
        case .alreadyRated:
            return "已经评价过此交易"
        case .historyNotFound:
            return "交易记录不存在"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        }
    }
}
