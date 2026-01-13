//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  管理玩家背包物品，与 Supabase 同步
//

import Foundation
import Supabase
import Combine

// MARK: - 数据库模型

/// 背包物品数据库模型（用于与 Supabase 交互）
struct InventoryItemDB: Codable {
    let id: UUID
    let userId: UUID
    let itemId: String
    var quantity: Int
    var quality: String?
    let obtainedAt: Date
    let obtainedFrom: String?
    let explorationSessionId: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedAt = "obtained_at"
        case obtainedFrom = "obtained_from"
        case explorationSessionId = "exploration_session_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为 App 内使用的 InventoryItem 模型
    func toInventoryItem() -> InventoryItem {
        let itemQuality: ItemQuality? = quality.flatMap { ItemQuality(rawValue: $0) }
        return InventoryItem(
            id: id.uuidString,
            itemId: itemId,
            quantity: quantity,
            quality: itemQuality,
            obtainedAt: obtainedAt,
            obtainedFrom: obtainedFrom
        )
    }
}

/// 插入背包物品的请求模型
struct InsertInventoryItem: Codable {
    let userId: UUID
    let itemId: String
    let quantity: Int
    let quality: String?
    let obtainedFrom: String?
    let explorationSessionId: UUID?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case obtainedFrom = "obtained_from"
        case explorationSessionId = "exploration_session_id"
    }
}

// MARK: - 背包管理器

/// 背包管理器
/// 管理玩家背包物品，与 Supabase 同步
class InventoryManager: ObservableObject {

    // MARK: - Published Properties

    /// 背包物品列表
    @MainActor @Published var items: [InventoryItem] = []

    /// 是否正在加载
    @MainActor @Published var isLoading: Bool = false

    /// 错误信息
    @MainActor @Published var errorMessage: String?

    // MARK: - Constants

    /// 最大负重（kg）
    let maxWeight: Double = 100.0

    // MARK: - Computed Properties

    /// 总重量
    var totalWeight: Double {
        var weight: Double = 0
        for item in items {
            if let definition = ItemDefinitions.get(item.itemId) {
                weight += item.totalWeight(definition: definition)
            }
        }
        return weight
    }

    /// 总体积
    var totalVolume: Double {
        var volume: Double = 0
        for item in items {
            if let definition = ItemDefinitions.get(item.itemId) {
                volume += item.totalVolume(definition: definition)
            }
        }
        return volume
    }

    /// 负重百分比
    var weightPercentage: Double {
        return totalWeight / maxWeight
    }

    /// 是否超重
    var isOverweight: Bool {
        return weightPercentage > 1.0
    }

    // MARK: - Dependencies

    private let supabaseClient: SupabaseClient

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabaseClient = supabase
    }

    // MARK: - Public Methods

    /// 加载背包物品
    @MainActor
    func loadInventory() async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: [InventoryItemDB] = try await supabaseClient
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("obtained_at", ascending: false)
                .execute()
                .value

            items = response.map { $0.toInventoryItem() }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "加载背包失败: \(error.localizedDescription)"
            throw error
        }
    }

    /// 添加物品到背包（探索奖励）
    /// - Parameters:
    ///   - lootItems: 要添加的物品列表
    ///   - explorationSessionId: 关联的探索会话ID
    @MainActor
    func addItems(_ lootItems: [LootItem], explorationSessionId: UUID?) async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw InventoryError.notAuthenticated
        }

        for loot in lootItems {
            // 检查是否可以堆叠
            if let definition = ItemDefinitions.get(loot.itemId),
               definition.isStackable,
               let existingItem = findStackableItem(itemId: loot.itemId, quality: loot.quality) {
                // 更新现有物品数量
                let newQuantity = min(existingItem.quantity + loot.quantity, definition.maxStack)
                try await updateItemQuantity(itemId: existingItem.id, quantity: newQuantity)
            } else {
                // 创建新物品记录
                let insertItem = InsertInventoryItem(
                    userId: userId,
                    itemId: loot.itemId,
                    quantity: loot.quantity,
                    quality: loot.quality?.rawValue,
                    obtainedFrom: "探索奖励",
                    explorationSessionId: explorationSessionId
                )

                try await supabaseClient
                    .from("inventory_items")
                    .insert(insertItem)
                    .execute()
            }
        }

        // 重新加载背包
        try await loadInventory()
    }

    /// 使用物品
    /// - Parameters:
    ///   - inventoryItemId: 背包物品ID
    ///   - quantity: 使用数量
    @MainActor
    func useItem(inventoryItemId: String, quantity: Int = 1) async throws {
        guard let item = items.first(where: { $0.id == inventoryItemId }) else {
            throw InventoryError.itemNotFound
        }

        if item.quantity <= quantity {
            // 删除物品
            try await deleteItem(itemId: inventoryItemId)
        } else {
            // 减少数量
            try await updateItemQuantity(itemId: inventoryItemId, quantity: item.quantity - quantity)
        }

        // 重新加载背包
        try await loadInventory()
    }

    /// 丢弃物品
    /// - Parameters:
    ///   - inventoryItemId: 背包物品ID
    ///   - quantity: 丢弃数量
    @MainActor
    func discardItem(inventoryItemId: String, quantity: Int) async throws {
        try await useItem(inventoryItemId: inventoryItemId, quantity: quantity)
    }

    /// 按分类筛选物品
    /// - Parameter category: 物品分类
    /// - Returns: 该分类的物品列表
    func getItems(by category: ItemCategory) -> [InventoryItem] {
        return items.filter { item in
            guard let definition = ItemDefinitions.get(item.itemId) else { return false }
            return definition.category == category
        }
    }

    /// 搜索物品
    /// - Parameter keyword: 搜索关键词
    /// - Returns: 匹配的物品列表
    func searchItems(keyword: String) -> [InventoryItem] {
        guard !keyword.isEmpty else { return items }
        return items.filter { item in
            guard let definition = ItemDefinitions.get(item.itemId) else { return false }
            return definition.name.localizedCaseInsensitiveContains(keyword)
        }
    }

    // MARK: - Private Methods

    /// 查找可堆叠的现有物品
    private func findStackableItem(itemId: String, quality: ItemQuality?) -> InventoryItem? {
        return items.first { item in
            item.itemId == itemId && item.quality == quality
        }
    }

    /// 更新物品数量
    private func updateItemQuantity(itemId: String, quantity: Int) async throws {
        try await supabaseClient
            .from("inventory_items")
            .update(["quantity": quantity])
            .eq("id", value: itemId)
            .execute()
    }

    /// 删除物品
    private func deleteItem(itemId: String) async throws {
        try await supabaseClient
            .from("inventory_items")
            .delete()
            .eq("id", value: itemId)
            .execute()
    }
}

// MARK: - 错误类型

enum InventoryError: LocalizedError {
    case notAuthenticated
    case itemNotFound
    case insufficientQuantity
    case overweight

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .itemNotFound:
            return "物品不存在"
        case .insufficientQuantity:
            return "物品数量不足"
        case .overweight:
            return "背包超重"
        }
    }
}
