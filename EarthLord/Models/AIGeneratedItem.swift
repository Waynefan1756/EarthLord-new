//
//  AIGeneratedItem.swift
//  EarthLord
//
//  AI 生成物品的数据模型
//  用于存储从 Edge Function 返回的 AI 生成物品
//

import Foundation

// MARK: - AI 生成物品

/// AI 生成的物品（来自 Edge Function）
struct AIGeneratedItem: Identifiable, Codable, Equatable {
    let id: String              // UUID
    let name: String            // 物品名称（如："生锈的急救箱"）
    let category: String        // 分类（food/water/medical/material/tool/weapon/misc）
    let rarity: String          // 稀有度（common/uncommon/rare/epic/legendary）
    let story: String           // 物品故事（30-60字）
    let quantity: Int           // 数量

    /// 转换分类为 ItemCategory 枚举
    var itemCategory: ItemCategory {
        ItemCategory(rawValue: category) ?? .misc
    }

    /// 转换稀有度为 ItemRarity 枚举
    var itemRarity: ItemRarity {
        ItemRarity(rawValue: rarity) ?? .common
    }

    // MARK: - Equatable

    static func == (lhs: AIGeneratedItem, rhs: AIGeneratedItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI 生成响应

/// Edge Function 返回的响应结构
struct AIGenerateResponse: Codable {
    let items: [AIGeneratedItem]
    let generatedAt: String
    let model: String
    let error: String?

    /// 是否成功
    var isSuccess: Bool {
        error == nil && !items.isEmpty
    }
}

// MARK: - AI 生成请求

/// 发送给 Edge Function 的请求结构
struct AIGenerateRequest: Codable {
    let poi: POIContext
    let itemCount: Int

    /// POI 上下文信息
    struct POIContext: Codable {
        let name: String
        let type: String
        let dangerLevel: Int
    }
}
