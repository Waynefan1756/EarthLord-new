//
//  ItemDefinitions.swift
//  EarthLord
//
//  物品定义静态数据
//  包含所有可获得物品的基础属性配置
//

import Foundation

/// 物品定义静态数据
/// 包含所有可获得物品的基础属性配置
struct ItemDefinitions {

    // MARK: - 所有物品定义

    /// 所有物品定义字典
    static let all: [String: ItemDefinition] = [
        // ========== Common (普通) ==========

        // 水类
        "item_water_bottle": ItemDefinition(
            id: "item_water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "500ml瓶装矿泉水，可以恢复口渴值。",
            isStackable: true,
            maxStack: 20,
            hasQuality: false
        ),
        "item_purified_water": ItemDefinition(
            id: "item_purified_water",
            name: "纯净水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "经过过滤的纯净水，安全可饮用。",
            isStackable: true,
            maxStack: 20,
            hasQuality: false
        ),

        // 食物
        "item_canned_food": ItemDefinition(
            id: "item_canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            description: "密封罐头，保质期很长，可以恢复饥饿值。",
            isStackable: true,
            maxStack: 15,
            hasQuality: false
        ),
        "item_biscuit": ItemDefinition(
            id: "item_biscuit",
            name: "饼干",
            category: .food,
            weight: 0.2,
            volume: 0.2,
            rarity: .common,
            description: "压缩饼干，热量密度高，便于携带。",
            isStackable: true,
            maxStack: 30,
            hasQuality: false
        ),

        // 医疗用品
        "item_bandage": ItemDefinition(
            id: "item_bandage",
            name: "绷带",
            category: .medical,
            weight: 0.1,
            volume: 0.1,
            rarity: .common,
            description: "医用绷带，可以止血和包扎伤口。",
            isStackable: true,
            maxStack: 30,
            hasQuality: false
        ),

        // 材料
        "item_wood": ItemDefinition(
            id: "item_wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            description: "普通木材，可用于建造和制作。",
            isStackable: true,
            maxStack: 50,
            hasQuality: true
        ),
        "item_scrap_metal": ItemDefinition(
            id: "item_scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 1.0,
            rarity: .common,
            description: "各种废旧金属零件，可以回收利用。",
            isStackable: true,
            maxStack: 50,
            hasQuality: true
        ),
        "item_scrap_cloth": ItemDefinition(
            id: "item_scrap_cloth",
            name: "废布料",
            category: .material,
            weight: 0.3,
            volume: 0.5,
            rarity: .common,
            description: "破旧的布料碎片，可用于制作或修补。",
            isStackable: true,
            maxStack: 50,
            hasQuality: false
        ),

        // 工具
        "item_rope": ItemDefinition(
            id: "item_rope",
            name: "绳子",
            category: .tool,
            weight: 0.8,
            volume: 0.5,
            rarity: .common,
            description: "结实的尼龙绳，用途广泛。",
            isStackable: true,
            maxStack: 10,
            hasQuality: true
        ),
        "item_matches": ItemDefinition(
            id: "item_matches",
            name: "火柴",
            category: .tool,
            weight: 0.05,
            volume: 0.02,
            rarity: .common,
            description: "一盒火柴，可以生火取暖或烹饪。",
            isStackable: true,
            maxStack: 20,
            hasQuality: false
        ),

        // ========== Uncommon (优良) ==========

        // 医疗用品
        "item_medicine": ItemDefinition(
            id: "item_medicine",
            name: "药品",
            category: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .uncommon,
            description: "通用药物，可以治疗轻微疾病和感染。",
            isStackable: true,
            maxStack: 20,
            hasQuality: false
        ),
        "item_first_aid_kit": ItemDefinition(
            id: "item_first_aid_kit",
            name: "急救包",
            category: .medical,
            weight: 0.8,
            volume: 0.6,
            rarity: .uncommon,
            description: "包含基本医疗用品的急救包，可以处理常见伤病。",
            isStackable: true,
            maxStack: 5,
            hasQuality: true
        ),

        // 工具
        "item_flashlight": ItemDefinition(
            id: "item_flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            description: "便携式手电筒，探索黑暗区域的必备工具。",
            isStackable: false,
            maxStack: 1,
            hasQuality: true
        ),
        "item_radio": ItemDefinition(
            id: "item_radio",
            name: "收音机",
            category: .tool,
            weight: 0.4,
            volume: 0.3,
            rarity: .uncommon,
            description: "便携收音机，可以收听紧急广播和幸存者信号。",
            isStackable: false,
            maxStack: 1,
            hasQuality: true
        ),

        // 材料
        "item_steel_pipe": ItemDefinition(
            id: "item_steel_pipe",
            name: "钢管",
            category: .material,
            weight: 2.5,
            volume: 1.5,
            rarity: .uncommon,
            description: "坚固的钢管，可用于制作武器或建筑。",
            isStackable: true,
            maxStack: 20,
            hasQuality: true
        ),

        // ========== Rare (稀有) ==========

        // 工具
        "item_toolbox": ItemDefinition(
            id: "item_toolbox",
            name: "工具箱",
            category: .tool,
            weight: 3.0,
            volume: 2.5,
            rarity: .rare,
            description: "包含各种常用工具的工具箱，修理和制作的好帮手。",
            isStackable: false,
            maxStack: 1,
            hasQuality: true
        ),
        "item_night_vision_battery": ItemDefinition(
            id: "item_night_vision_battery",
            name: "夜视仪电池",
            category: .tool,
            weight: 0.2,
            volume: 0.1,
            rarity: .rare,
            description: "专用电池，可为夜视设备供电。",
            isStackable: true,
            maxStack: 10,
            hasQuality: false
        ),

        // 材料
        "item_gasoline": ItemDefinition(
            id: "item_gasoline",
            name: "汽油桶",
            category: .material,
            weight: 5.0,
            volume: 5.0,
            rarity: .rare,
            description: "一桶汽油，可用于车辆燃料或发电机。",
            isStackable: true,
            maxStack: 5,
            hasQuality: false
        ),

        // ========== Epic (史诗) ==========

        // 医疗用品
        "item_antibiotics": ItemDefinition(
            id: "item_antibiotics",
            name: "抗生素",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .epic,
            description: "珍贵的抗生素药物，可以治疗严重感染。",
            isStackable: true,
            maxStack: 10,
            hasQuality: false
        ),

        // 工具
        "item_gas_mask": ItemDefinition(
            id: "item_gas_mask",
            name: "防毒面具",
            category: .tool,
            weight: 0.6,
            volume: 0.8,
            rarity: .epic,
            description: "可以过滤有毒气体和辐射尘埃的防护面具。",
            isStackable: false,
            maxStack: 1,
            hasQuality: true
        ),

        // 材料
        "item_generator_parts": ItemDefinition(
            id: "item_generator_parts",
            name: "发电机零件",
            category: .material,
            weight: 4.0,
            volume: 3.0,
            rarity: .epic,
            description: "发电机的关键零部件，可用于修复或组装发电机。",
            isStackable: true,
            maxStack: 5,
            hasQuality: true
        ),

        // ========== Legendary (传说) ==========

        // 工具
        "item_solar_charger": ItemDefinition(
            id: "item_solar_charger",
            name: "太阳能充电器",
            category: .tool,
            weight: 1.0,
            volume: 0.8,
            rarity: .legendary,
            description: "便携式太阳能充电器，可以在户外为电子设备充电。",
            isStackable: false,
            maxStack: 1,
            hasQuality: true
        ),
        "item_water_purifier": ItemDefinition(
            id: "item_water_purifier",
            name: "净水器",
            category: .tool,
            weight: 1.5,
            volume: 1.2,
            rarity: .legendary,
            description: "高效净水器，可以将污水转化为可饮用水。",
            isStackable: false,
            maxStack: 1,
            hasQuality: true
        ),

        // 医疗用品
        "item_military_medkit": ItemDefinition(
            id: "item_military_medkit",
            name: "军用急救包",
            category: .medical,
            weight: 1.5,
            volume: 1.0,
            rarity: .legendary,
            description: "军用级急救包，包含先进的医疗用品，可以处理严重创伤。",
            isStackable: false,
            maxStack: 1,
            hasQuality: true
        )
    ]

    // MARK: - 按稀有度分组（预计算，优化随机选择性能）

    /// 按稀有度分组的物品
    static let byRarity: [ItemRarity: [ItemDefinition]] = {
        var grouped: [ItemRarity: [ItemDefinition]] = [:]
        for rarity in ItemRarity.allCases {
            grouped[rarity] = all.values.filter { $0.rarity == rarity }
        }
        return grouped
    }()

    // MARK: - 辅助方法

    /// 获取物品定义
    /// - Parameter itemId: 物品ID
    /// - Returns: 物品定义，如果不存在返回nil
    static func get(_ itemId: String) -> ItemDefinition? {
        return all[itemId]
    }

    /// 获取指定稀有度的所有物品
    /// - Parameter rarity: 稀有度
    /// - Returns: 该稀有度的物品列表
    static func getItems(rarity: ItemRarity) -> [ItemDefinition] {
        return byRarity[rarity] ?? []
    }

    /// 获取指定分类的所有物品
    /// - Parameter category: 物品分类
    /// - Returns: 该分类的物品列表
    static func getItems(category: ItemCategory) -> [ItemDefinition] {
        return all.values.filter { $0.category == category }
    }
}
