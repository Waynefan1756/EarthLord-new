//
//  TradeManager.swift
//  EarthLord
//
//  交易管理器
//  管理玩家之间的异步挂单交易系统
//

import Foundation
import Supabase
import Combine

// MARK: - 评分更新模型

/// 更新买家评分（卖家给买家的评分）
private struct UpdateBuyerRating: Codable {
    let buyerRating: Int
    let buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case buyerRating = "buyer_rating"
        case buyerComment = "buyer_comment"
    }
}

/// 更新卖家评分（买家给卖家的评分）
private struct UpdateSellerRating: Codable {
    let sellerRating: Int
    let sellerComment: String?

    enum CodingKeys: String, CodingKey {
        case sellerRating = "seller_rating"
        case sellerComment = "seller_comment"
    }
}

/// 交易管理器
/// 管理玩家之间的异步挂单交易系统
@MainActor
class TradeManager: ObservableObject {

    // MARK: - Published Properties

    /// 我的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 可接受的挂单列表（其他玩家的 active 挂单）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Constants

    /// 默认挂单有效期（小时）
    static let defaultExpirationHours: Int = 72

    // MARK: - Dependencies

    private let supabaseClient: SupabaseClient
    private weak var inventoryManager: InventoryManager?
    private weak var authManager: AuthManager?

    // MARK: - Initialization

    init(supabase: SupabaseClient, inventoryManager: InventoryManager? = nil, authManager: AuthManager? = nil) {
        self.supabaseClient = supabase
        self.inventoryManager = inventoryManager
        self.authManager = authManager
    }

    /// 设置依赖（用于延迟注入）
    func setDependencies(inventoryManager: InventoryManager, authManager: AuthManager) {
        self.inventoryManager = inventoryManager
        self.authManager = authManager
    }

    // MARK: - 创建挂单

    /// 创建挂单
    /// - Parameters:
    ///   - offeringItems: 提供的物品列表（从背包选择）
    ///   - requestingItems: 索取的物品列表（期望获得的物品）
    ///   - message: 留言（可选）
    ///   - expirationHours: 有效期（小时），默认72小时
    /// - Returns: 创建的挂单
    func createOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        message: String? = nil,
        expirationHours: Int = defaultExpirationHours
    ) async throws -> TradeOffer {
        // 验证用户登录
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 获取用户名
        guard let username = authManager?.currentUser?.username else {
            throw TradeError.userProfileNotFound
        }

        guard let inventoryManager = inventoryManager else {
            throw TradeError.databaseError("InventoryManager 未初始化")
        }

        // 验证提供的物品在背包中存在且数量足够
        var insufficientItems: [String] = []
        var itemsToDeduct: [(inventoryItemId: String, quantity: Int)] = []

        for tradeItem in offeringItems {
            // 查找背包中匹配的物品
            let matchingItems = inventoryManager.items.filter { inventoryItem in
                inventoryItem.itemId == tradeItem.itemId &&
                (tradeItem.quality == nil || inventoryItem.quality?.rawValue == tradeItem.quality)
            }

            // 计算总数量
            let totalQuantity = matchingItems.reduce(0) { $0 + $1.quantity }

            if totalQuantity < tradeItem.quantity {
                insufficientItems.append(tradeItem.itemId)
            } else {
                // 记录需要扣除的物品（从第一个匹配的开始扣除）
                var remainingToDeduct = tradeItem.quantity
                for item in matchingItems {
                    if remainingToDeduct <= 0 { break }
                    let deductAmount = min(item.quantity, remainingToDeduct)
                    itemsToDeduct.append((inventoryItemId: item.id, quantity: deductAmount))
                    remainingToDeduct -= deductAmount
                }
            }
        }

        if !insufficientItems.isEmpty {
            throw TradeError.insufficientItems(insufficientItems)
        }

        // 扣除背包物品（物品锁定）
        for (inventoryItemId, quantity) in itemsToDeduct {
            try await inventoryManager.useItem(inventoryItemId: inventoryItemId, quantity: quantity)
        }

        // 计算过期时间
        let expiresAt = Date().addingTimeInterval(TimeInterval(expirationHours * 3600))

        // 创建挂单记录
        let insertOffer = InsertTradeOffer(
            ownerId: userId,
            ownerUsername: username,
            offeringItems: offeringItems,
            requestingItems: requestingItems,
            status: TradeOfferStatus.active.rawValue,
            message: message,
            expiresAt: expiresAt
        )

        do {
            let response: TradeOfferDB = try await supabaseClient
                .from("trade_offers")
                .insert(insertOffer)
                .select()
                .single()
                .execute()
                .value

            let offer = response.toTradeOffer()

            // 更新本地列表
            myOffers.insert(offer, at: 0)

            return offer
        } catch {
            // 如果创建失败，尝试退还物品（最佳努力）
            // 注意：这里可能会有一致性问题，生产环境应使用事务
            throw TradeError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - 取消挂单

    /// 取消挂单
    /// - Parameter offerId: 挂单ID
    func cancelOffer(offerId: String) async throws {
        // 验证用户登录
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        guard let inventoryManager = inventoryManager else {
            throw TradeError.databaseError("InventoryManager 未初始化")
        }

        // 获取挂单信息
        guard let offer = myOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        // 验证权限
        guard offer.ownerId == userId.uuidString else {
            throw TradeError.permissionDenied
        }

        // 验证状态
        guard offer.status == .active else {
            throw TradeError.offerNotActive
        }

        // 更新数据库状态（使用乐观锁）
        do {
            try await supabaseClient
                .from("trade_offers")
                .update(["status": TradeOfferStatus.cancelled.rawValue])
                .eq("id", value: offerId)
                .eq("status", value: TradeOfferStatus.active.rawValue)  // 乐观锁
                .execute()
        } catch {
            throw TradeError.databaseError(error.localizedDescription)
        }

        // 退还物品到背包
        let lootItems = offer.offeringItems.map { tradeItem in
            LootItem(
                id: UUID().uuidString,
                itemId: tradeItem.itemId,
                quantity: tradeItem.quantity,
                quality: tradeItem.quality.flatMap { ItemQuality(rawValue: $0) }
            )
        }

        try await inventoryManager.addItems(lootItems, explorationSessionId: nil)

        // 更新本地列表
        if let index = myOffers.firstIndex(where: { $0.id == offerId }) {
            myOffers[index].status = .cancelled
        }
    }

    // MARK: - 接受挂单

    /// 接受交易的数据库函数响应
    private struct AcceptTradeResponse: Codable {
        let success: Bool
        let error: String?
        let history_id: UUID?
        let seller_id: UUID?
    }

    /// 接受挂单（执行交易）- 使用数据库事务确保原子性
    /// - Parameter offerId: 挂单ID
    /// - Returns: 创建的交易历史记录
    func acceptOffer(offerId: String) async throws -> TradeHistory {
        // 验证用户登录
        guard let buyerId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 获取买家用户名
        guard let buyerUsername = authManager?.currentUser?.username else {
            throw TradeError.userProfileNotFound
        }

        guard let inventoryManager = inventoryManager else {
            throw TradeError.databaseError("InventoryManager 未初始化")
        }

        // 获取挂单信息（客户端预检查）
        guard let offer = availableOffers.first(where: { $0.id == offerId }) else {
            throw TradeError.offerNotFound
        }

        // 客户端预检查：不能接受自己的挂单
        guard offer.ownerId != buyerId.uuidString else {
            throw TradeError.cannotAcceptOwnOffer
        }

        // 客户端预检查：挂单状态
        guard offer.canBeAccepted else {
            if offer.isExpired {
                throw TradeError.offerExpired
            }
            throw TradeError.offerNotActive
        }

        // 验证买家背包中有足够的索取物品，并收集需要扣除的物品信息
        var insufficientItems: [String] = []
        var itemsToDeduct: [[String: Any]] = []

        for tradeItem in offer.requestingItems {
            let matchingItems = inventoryManager.items.filter { inventoryItem in
                inventoryItem.itemId == tradeItem.itemId &&
                (tradeItem.quality == nil || inventoryItem.quality?.rawValue == tradeItem.quality)
            }

            let totalQuantity = matchingItems.reduce(0) { $0 + $1.quantity }

            if totalQuantity < tradeItem.quantity {
                insufficientItems.append(tradeItem.itemId)
            } else {
                var remainingToDeduct = tradeItem.quantity
                for item in matchingItems {
                    if remainingToDeduct <= 0 { break }
                    let deductAmount = min(item.quantity, remainingToDeduct)
                    itemsToDeduct.append([
                        "inventory_item_id": item.id,
                        "quantity": deductAmount
                    ])
                    remainingToDeduct -= deductAmount
                }
            }
        }

        if !insufficientItems.isEmpty {
            throw TradeError.insufficientItems(insufficientItems)
        }

        // 转换为 JSON 字符串
        guard let itemsToDeductData = try? JSONSerialization.data(withJSONObject: itemsToDeduct),
              let itemsToDeductJson = String(data: itemsToDeductData, encoding: .utf8) else {
            throw TradeError.databaseError("无法序列化物品数据")
        }

        // 调用数据库事务函数
        let result: [AcceptTradeResponse] = try await supabaseClient
            .rpc("accept_trade_offer", params: [
                "p_offer_id": offerId,
                "p_buyer_id": buyerId.uuidString,
                "p_buyer_username": buyerUsername,
                "p_buyer_items_to_deduct": itemsToDeductJson
            ])
            .execute()
            .value

        guard let response = result.first else {
            throw TradeError.databaseError("数据库函数返回为空")
        }

        // 检查事务是否成功
        guard response.success else {
            let errorMsg = response.error ?? "未知错误"
            switch errorMsg {
            case "offer_not_found":
                throw TradeError.offerNotFound
            case "offer_not_active":
                throw TradeError.offerNotActive
            case "offer_expired":
                throw TradeError.offerExpired
            case "cannot_accept_own_offer":
                throw TradeError.cannotAcceptOwnOffer
            default:
                throw TradeError.databaseError(errorMsg)
            }
        }

        guard let historyId = response.history_id else {
            throw TradeError.databaseError("未返回交易历史ID")
        }

        // 刷新本地库存数据
        try await inventoryManager.loadInventory()

        // 获取完整的交易历史记录
        let historyResponse: TradeHistoryDB = try await supabaseClient
            .from("trade_history")
            .select()
            .eq("id", value: historyId.uuidString)
            .single()
            .execute()
            .value

        let history = historyResponse.toTradeHistory()

        // 更新本地列表
        availableOffers.removeAll { $0.id == offerId }
        tradeHistory.insert(history, at: 0)

        return history
    }

    // MARK: - 提交评价

    /// 提交交易评价
    /// - Parameters:
    ///   - historyId: 交易历史ID
    ///   - rating: 评分
    ///   - comment: 评语（可选）
    func submitRating(historyId: String, rating: TradeRating, comment: String? = nil) async throws {
        // 验证用户登录
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 获取交易历史
        guard let history = tradeHistory.first(where: { $0.id == historyId }) else {
            throw TradeError.historyNotFound
        }

        // 确定用户角色并设置对应的评分字段
        let isSeller = history.isSeller(userId: userId.uuidString)
        let isBuyer = history.isBuyer(userId: userId.uuidString)

        guard isSeller || isBuyer else {
            throw TradeError.permissionDenied
        }

        // 检查是否已评价
        if history.hasRated(myUserId: userId.uuidString) {
            throw TradeError.alreadyRated
        }

        // 更新数据库
        // 卖家给买家评分 -> buyer_rating
        // 买家给卖家评分 -> seller_rating
        do {
            if isSeller {
                let updateData = UpdateBuyerRating(
                    buyerRating: rating.rawValue,
                    buyerComment: comment
                )
                try await supabaseClient
                    .from("trade_history")
                    .update(updateData)
                    .eq("id", value: historyId)
                    .execute()
            } else {
                let updateData = UpdateSellerRating(
                    sellerRating: rating.rawValue,
                    sellerComment: comment
                )
                try await supabaseClient
                    .from("trade_history")
                    .update(updateData)
                    .eq("id", value: historyId)
                    .execute()
            }

            // 更新本地数据
            if let index = tradeHistory.firstIndex(where: { $0.id == historyId }) {
                if isSeller {
                    tradeHistory[index].buyerRating = rating
                    tradeHistory[index].buyerComment = comment
                } else {
                    tradeHistory[index].sellerRating = rating
                    tradeHistory[index].sellerComment = comment
                }
            }
        } catch {
            throw TradeError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - 查询方法

    /// 加载我的挂单
    func loadMyOffers() async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: [TradeOfferDB] = try await supabaseClient
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myOffers = response.map { $0.toTradeOffer() }

            // 检查并更新过期的挂单
            await checkAndUpdateExpiredOffers()

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "加载我的挂单失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 加载可接受的挂单（其他玩家的 active 挂单）
    func loadAvailableOffers() async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: [TradeOfferDB] = try await supabaseClient
                .from("trade_offers")
                .select()
                .eq("status", value: TradeOfferStatus.active.rawValue)
                .neq("owner_id", value: userId.uuidString)  // 排除自己的挂单
                .order("created_at", ascending: false)
                .execute()
                .value

            // 过滤掉已过期的（客户端检测）
            availableOffers = response
                .map { $0.toTradeOffer() }
                .filter { !$0.isExpired }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "加载可用挂单失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 加载交易历史
    func loadTradeHistory() async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            // 查询我作为卖家或买家的交易
            let response: [TradeHistoryDB] = try await supabaseClient
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .execute()
                .value

            tradeHistory = response.map { $0.toTradeHistory() }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "加载交易历史失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 刷新所有数据
    func refreshAll() async throws {
        try await loadMyOffers()
        try await loadAvailableOffers()
        try await loadTradeHistory()
    }

    // MARK: - 辅助方法

    /// 检查并更新过期的挂单
    private func checkAndUpdateExpiredOffers() async {
        let expiredOffers = myOffers.filter { $0.status == .active && $0.isExpired }

        for offer in expiredOffers {
            // 异步更新数据库状态
            Task {
                do {
                    try await supabaseClient
                        .from("trade_offers")
                        .update(["status": TradeOfferStatus.expired.rawValue])
                        .eq("id", value: offer.id)
                        .eq("status", value: TradeOfferStatus.active.rawValue)
                        .execute()

                    // 退还物品
                    if let inventoryManager = inventoryManager {
                        let lootItems = offer.offeringItems.map { tradeItem in
                            LootItem(
                                id: UUID().uuidString,
                                itemId: tradeItem.itemId,
                                quantity: tradeItem.quantity,
                                quality: tradeItem.quality.flatMap { ItemQuality(rawValue: $0) }
                            )
                        }
                        try await inventoryManager.addItems(lootItems, explorationSessionId: nil)
                    }

                    // 更新本地状态
                    await MainActor.run {
                        if let index = myOffers.firstIndex(where: { $0.id == offer.id }) {
                            myOffers[index].status = .expired
                        }
                    }
                } catch {
                    print("更新过期挂单失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - 用户评分统计

    /// 用户评分统计结果
    struct UserRatingStats {
        let userId: String
        let totalTrades: Int           // 总交易次数
        let asSellerCount: Int         // 作为卖家的次数
        let asBuyerCount: Int          // 作为买家的次数
        let averageSellerRating: Double? // 作为卖家的平均评分（被买家评分）
        let averageBuyerRating: Double?  // 作为买家的平均评分（被卖家评分）
        let overallRating: Double?       // 综合评分

        /// 显示用的星级（综合评分）
        var displayStars: String {
            guard let rating = overallRating else { return "暂无评分" }
            let stars = Int(rating.rounded())
            return String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
        }

        /// 格式化评分显示
        var formattedRating: String {
            guard let rating = overallRating else { return "暂无评分" }
            return String(format: "%.1f", rating)
        }
    }

    /// 获取用户的评分统计
    /// - Parameter userId: 用户ID（nil 表示当前用户）
    /// - Returns: 评分统计结果
    func getUserRatingStats(userId: String? = nil) async throws -> UserRatingStats {
        let targetUserId: String
        if let userId = userId {
            targetUserId = userId
        } else {
            guard let currentUserId = supabaseClient.auth.currentUser?.id else {
                throw TradeError.notAuthenticated
            }
            targetUserId = currentUserId.uuidString
        }

        // 查询用户相关的所有交易历史
        let response: [TradeHistoryDB] = try await supabaseClient
            .from("trade_history")
            .select()
            .or("seller_id.eq.\(targetUserId),buyer_id.eq.\(targetUserId)")
            .execute()
            .value

        let histories = response.map { $0.toTradeHistory() }

        // 统计作为卖家的交易（被买家评分）
        let sellerTrades = histories.filter { $0.sellerId == targetUserId }
        let sellerRatings = sellerTrades.compactMap { $0.sellerRating?.rawValue }
        let averageSellerRating = sellerRatings.isEmpty ? nil : Double(sellerRatings.reduce(0, +)) / Double(sellerRatings.count)

        // 统计作为买家的交易（被卖家评分）
        let buyerTrades = histories.filter { $0.buyerId == targetUserId }
        let buyerRatings = buyerTrades.compactMap { $0.buyerRating?.rawValue }
        let averageBuyerRating = buyerRatings.isEmpty ? nil : Double(buyerRatings.reduce(0, +)) / Double(buyerRatings.count)

        // 计算综合评分
        let allRatings = sellerRatings + buyerRatings
        let overallRating = allRatings.isEmpty ? nil : Double(allRatings.reduce(0, +)) / Double(allRatings.count)

        return UserRatingStats(
            userId: targetUserId,
            totalTrades: histories.count,
            asSellerCount: sellerTrades.count,
            asBuyerCount: buyerTrades.count,
            averageSellerRating: averageSellerRating,
            averageBuyerRating: averageBuyerRating,
            overallRating: overallRating
        )
    }

    // MARK: - 搜索与筛选

    /// 挂单筛选条件
    struct OfferFilter {
        var itemIds: [String]?           // 按物品ID筛选（提供或索取包含这些物品）
        var itemCategory: String?        // 按物品类别筛选
        var minQuantity: Int?            // 最小数量
        var ownerUsername: String?       // 按发布者用户名筛选
        var sortBy: SortOption = .newest // 排序方式

        enum SortOption {
            case newest      // 最新发布
            case oldest      // 最早发布
            case expiringFirst  // 即将过期
        }
    }

    /// 搜索可用挂单（带筛选）
    /// - Parameter filter: 筛选条件
    /// - Returns: 符合条件的挂单列表
    func searchAvailableOffers(filter: OfferFilter? = nil) async throws -> [TradeOffer] {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 基础查询
        let response: [TradeOfferDB] = try await supabaseClient
            .from("trade_offers")
            .select()
            .eq("status", value: TradeOfferStatus.active.rawValue)
            .neq("owner_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        var offers = response
            .map { $0.toTradeOffer() }
            .filter { !$0.isExpired }

        // 应用客户端筛选（因为 JSONB 筛选在 Supabase 中较复杂）
        if let filter = filter {
            // 按物品ID筛选
            if let itemIds = filter.itemIds, !itemIds.isEmpty {
                offers = offers.filter { offer in
                    let offeringIds = offer.offeringItems.map { $0.itemId }
                    let requestingIds = offer.requestingItems.map { $0.itemId }
                    return itemIds.contains { offeringIds.contains($0) || requestingIds.contains($0) }
                }
            }

            // 按物品类别筛选
            if let category = filter.itemCategory {
                offers = offers.filter { offer in
                    let hasOfferingCategory = offer.offeringItems.contains { item in
                        ItemDefinitions.get(item.itemId)?.category.rawValue == category
                    }
                    let hasRequestingCategory = offer.requestingItems.contains { item in
                        ItemDefinitions.get(item.itemId)?.category.rawValue == category
                    }
                    return hasOfferingCategory || hasRequestingCategory
                }
            }

            // 按最小数量筛选
            if let minQty = filter.minQuantity {
                offers = offers.filter { offer in
                    let maxOfferingQty = offer.offeringItems.map { $0.quantity }.max() ?? 0
                    return maxOfferingQty >= minQty
                }
            }

            // 按发布者用户名筛选
            if let username = filter.ownerUsername, !username.isEmpty {
                offers = offers.filter { offer in
                    offer.ownerUsername.localizedCaseInsensitiveContains(username)
                }
            }

            // 排序
            switch filter.sortBy {
            case .newest:
                offers.sort { $0.createdAt > $1.createdAt }
            case .oldest:
                offers.sort { $0.createdAt < $1.createdAt }
            case .expiringFirst:
                offers.sort { $0.remainingTime < $1.remainingTime }
            }
        }

        return offers
    }

    /// 获取包含指定物品的挂单（快捷方法）
    /// - Parameter itemId: 物品ID
    /// - Returns: 包含该物品的挂单列表
    func getOffersContainingItem(itemId: String) async throws -> [TradeOffer] {
        let filter = OfferFilter(itemIds: [itemId])
        return try await searchAvailableOffers(filter: filter)
    }

    // MARK: - 挂单详情

    /// 从服务器获取单个挂单的最新状态
    /// - Parameter offerId: 挂单ID
    /// - Returns: 挂单详情
    func getOfferDetail(offerId: String) async throws -> TradeOffer {
        let response: TradeOfferDB = try await supabaseClient
            .from("trade_offers")
            .select()
            .eq("id", value: offerId)
            .single()
            .execute()
            .value

        return response.toTradeOffer()
    }

    /// 刷新单个挂单状态
    /// - Parameter offerId: 挂单ID
    func refreshOffer(offerId: String) async throws {
        let offer = try await getOfferDetail(offerId: offerId)

        // 更新本地列表
        if let index = myOffers.firstIndex(where: { $0.id == offerId }) {
            myOffers[index] = offer
        }
        if let index = availableOffers.firstIndex(where: { $0.id == offerId }) {
            if offer.status == .active && !offer.isExpired {
                availableOffers[index] = offer
            } else {
                availableOffers.remove(at: index)
            }
        }
    }

    // MARK: - 统计信息

    /// 我的交易统计
    struct MyTradeStats {
        let activeOffers: Int           // 进行中的挂单数
        let completedTrades: Int        // 已完成的交易数
        let cancelledOffers: Int        // 已取消的挂单数
        let totalItemsTraded: Int       // 总交易物品数量
        let pendingRatings: Int         // 待评价的交易数
    }

    /// 获取我的交易统计
    func getMyTradeStats() async throws -> MyTradeStats {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 确保数据已加载
        if myOffers.isEmpty && tradeHistory.isEmpty {
            try await refreshAll()
        }

        let activeOffers = myOffers.filter { $0.status == .active && !$0.isExpired }.count
        let completedTrades = tradeHistory.count
        let cancelledOffers = myOffers.filter { $0.status == .cancelled }.count

        // 计算总交易物品数量
        let totalItemsTraded = tradeHistory.reduce(0) { total, history in
            let myItems = history.myItems(myUserId: userId.uuidString)
            return total + myItems.reduce(0) { $0 + $1.quantity }
        }

        // 计算待评价数量
        let pendingRatings = tradeHistory.filter { !$0.hasRated(myUserId: userId.uuidString) }.count

        return MyTradeStats(
            activeOffers: activeOffers,
            completedTrades: completedTrades,
            cancelledOffers: cancelledOffers,
            totalItemsTraded: totalItemsTraded,
            pendingRatings: pendingRatings
        )
    }
}
