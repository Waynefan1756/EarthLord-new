//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器
//  根据行走距离计算奖励等级，生成随机物品奖励
//

import Foundation

// MARK: - 奖励等级

/// 奖励等级枚举
enum RewardTier: String, Codable, CaseIterable {
    case none = "none"         // 0-200米：无奖励
    case bronze = "bronze"     // 200-500米：铜级
    case silver = "silver"     // 500-1000米：银级
    case gold = "gold"         // 1000-2000米：金级
    case diamond = "diamond"   // 2000米以上：钻石级

    /// 中文名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 等级图标
    var iconName: String {
        switch self {
        case .none: return "minus.circle"
        case .bronze: return "seal"
        case .silver: return "seal.fill"
        case .gold: return "star.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 等级颜色（十六进制）
    var colorHex: String {
        switch self {
        case .none: return "#9E9E9E"
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .diamond: return "#B9F2FF"
        }
    }

    /// 物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 稀有度概率分布 [common, uncommon, rare, epic, legendary]
    var rarityProbabilities: [Double] {
        switch self {
        case .none:
            return [0, 0, 0, 0, 0]
        case .bronze:
            return [0.70, 0.20, 0.10, 0, 0]          // 70%普通/20%优良/10%稀有
        case .silver:
            return [0.50, 0.25, 0.20, 0.05, 0]       // 50%普通/25%优良/20%稀有/5%史诗
        case .gold:
            return [0.30, 0.25, 0.25, 0.15, 0.05]    // 30%普通/25%优良/25%稀有/15%史诗/5%传说
        case .diamond:
            return [0.15, 0.20, 0.30, 0.25, 0.10]    // 15%普通/20%优良/30%稀有/25%史诗/10%传说
        }
    }

    /// 根据距离计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 对应的奖励等级
    static func fromDistance(_ distance: Double) -> RewardTier {
        switch distance {
        case ..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }

    /// 获取到达下一等级所需的距离
    /// - Parameter distance: 当前距离
    /// - Returns: (下一等级, 还需要的距离)，如果已是最高等级返回nil
    static func nextTierInfo(currentDistance distance: Double) -> (tier: RewardTier, remainingDistance: Double)? {
        switch distance {
        case ..<200:
            return (.bronze, 200 - distance)
        case 200..<500:
            return (.silver, 500 - distance)
        case 500..<1000:
            return (.gold, 1000 - distance)
        case 1000..<2000:
            return (.diamond, 2000 - distance)
        default:
            return nil  // 已是最高等级
        }
    }
}

// MARK: - 奖励生成器

/// 奖励生成器
/// 根据奖励等级生成随机物品
struct RewardGenerator {

    // MARK: - 生成奖励

    /// 生成探索奖励
    /// - Parameters:
    ///   - tier: 奖励等级
    ///   - source: 物品来源描述
    /// - Returns: 生成的物品列表
    static func generateRewards(tier: RewardTier, source: String = "探索奖励") -> [LootItem] {
        guard tier != .none else { return [] }

        var rewards: [LootItem] = []
        let itemCount = tier.itemCount

        for _ in 0..<itemCount {
            // 1. 根据概率选择稀有度
            let rarity = selectRarity(probabilities: tier.rarityProbabilities)

            // 2. 从该稀有度的物品池中随机选择一个物品
            guard let item = selectItem(rarity: rarity) else { continue }

            // 3. 生成品质（如果物品支持品质属性）
            let quality = generateQuality(for: item)

            // 4. 创建奖励物品
            let lootItem = LootItem(
                id: UUID().uuidString,
                itemId: item.id,
                quantity: 1,
                quality: quality
            )
            rewards.append(lootItem)
        }

        return rewards
    }

    /// 预览奖励信息（不实际生成，用于UI展示）
    /// - Parameter tier: 奖励等级
    /// - Returns: 预览描述文字
    static func previewRewards(tier: RewardTier) -> String {
        switch tier {
        case .none:
            return "行走超过200米才能获得奖励"
        case .bronze:
            return "可获得 1 件物品"
        case .silver:
            return "可获得 2 件物品"
        case .gold:
            return "可获得 3 件物品"
        case .diamond:
            return "可获得 5 件物品"
        }
    }

    // MARK: - 私有方法

    /// 根据概率选择稀有度
    /// - Parameter probabilities: 概率数组 [common, uncommon, rare, epic, legendary]
    /// - Returns: 选中的稀有度
    private static func selectRarity(probabilities: [Double]) -> ItemRarity {
        let random = Double.random(in: 0..<1)
        var cumulative: Double = 0

        let rarities: [ItemRarity] = [.common, .uncommon, .rare, .epic, .legendary]

        for (index, probability) in probabilities.enumerated() {
            cumulative += probability
            if random < cumulative {
                return rarities[index]
            }
        }

        // 默认返回普通稀有度
        return .common
    }

    /// 根据稀有度随机选择物品
    /// - Parameter rarity: 稀有度
    /// - Returns: 选中的物品定义
    private static func selectItem(rarity: ItemRarity) -> ItemDefinition? {
        let items = ItemDefinitions.getItems(rarity: rarity)
        guard !items.isEmpty else {
            // 如果该稀有度没有物品，降级到普通
            let commonItems = ItemDefinitions.getItems(rarity: .common)
            return commonItems.randomElement()
        }
        return items.randomElement()
    }

    /// 生成随机品质
    /// - Parameter item: 物品定义
    /// - Returns: 品质等级，如果物品不支持品质返回nil
    private static func generateQuality(for item: ItemDefinition) -> ItemQuality? {
        guard item.hasQuality else { return nil }

        // 品质概率分布：崭新10%、良好40%、磨损35%、损坏12%、报废3%
        let random = Double.random(in: 0..<1)

        switch random {
        case ..<0.10:
            return .pristine
        case 0.10..<0.50:
            return .good
        case 0.50..<0.85:
            return .worn
        case 0.85..<0.97:
            return .damaged
        default:
            return .ruined
        }
    }
}
