//
//  MockExplorationData.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//
//  探索模块测试假数据
//  用于UI开发和功能测试，包含POI、背包物品、物品定义、探索结果等数据
//

import Foundation
import CoreLocation

// MARK: - POI 兴趣点相关

/// POI 发现状态
enum POIDiscoveryStatus: String, Codable {
    case undiscovered = "undiscovered"  // 未发现（地图上不显示或显示为问号）
    case discovered = "discovered"       // 已发现（可以看到详情）
}

/// POI 搜索状态
enum POILootStatus: String, Codable {
    case hasLoot = "has_loot"       // 有物资可搜刮
    case looted = "looted"          // 已被搜空
    case noLoot = "no_loot"         // 本身无物资（如地标类POI）
}

/// POI 类型
enum POIType: String, Codable {
    case supermarket = "supermarket"    // 超市
    case hospital = "hospital"          // 医院
    case gasStation = "gas_station"     // 加油站
    case pharmacy = "pharmacy"          // 药店
    case factory = "factory"            // 工厂
    case warehouse = "warehouse"        // 仓库
    case residential = "residential"    // 住宅区

    /// 中文名称
    var displayName: String {
        switch self {
        case .supermarket: return "超市"
        case .hospital: return "医院"
        case .gasStation: return "加油站"
        case .pharmacy: return "药店"
        case .factory: return "工厂"
        case .warehouse: return "仓库"
        case .residential: return "住宅区"
        }
    }

    /// POI 图标名称
    var iconName: String {
        switch self {
        case .supermarket: return "cart.fill"
        case .hospital: return "cross.fill"
        case .gasStation: return "fuelpump.fill"
        case .pharmacy: return "pills.fill"
        case .factory: return "building.2.fill"
        case .warehouse: return "shippingbox.fill"
        case .residential: return "house.fill"
        }
    }
}

/// 兴趣点（Point of Interest）模型
struct POI: Identifiable, Codable {
    let id: String
    let name: String                        // POI 名称
    let type: POIType                       // POI 类型
    let coordinate: CLLocationCoordinate2D  // 坐标位置
    var discoveryStatus: POIDiscoveryStatus // 发现状态
    var lootStatus: POILootStatus           // 搜刮状态
    let dangerLevel: Int                    // 危险等级 1-5
    let description: String?                // 描述信息

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case latitude, longitude
        case discoveryStatus = "discovery_status"
        case lootStatus = "loot_status"
        case dangerLevel = "danger_level"
        case description
    }

    init(id: String, name: String, type: POIType, coordinate: CLLocationCoordinate2D,
         discoveryStatus: POIDiscoveryStatus, lootStatus: POILootStatus,
         dangerLevel: Int, description: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.discoveryStatus = discoveryStatus
        self.lootStatus = lootStatus
        self.dangerLevel = dangerLevel
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(POIType.self, forKey: .type)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        discoveryStatus = try container.decode(POIDiscoveryStatus.self, forKey: .discoveryStatus)
        lootStatus = try container.decode(POILootStatus.self, forKey: .lootStatus)
        dangerLevel = try container.decode(Int.self, forKey: .dangerLevel)
        description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(discoveryStatus, forKey: .discoveryStatus)
        try container.encode(lootStatus, forKey: .lootStatus)
        try container.encode(dangerLevel, forKey: .dangerLevel)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

// MARK: - 可探索POI（用于地理围栏搜刮）

import MapKit

/// 可探索的POI（从MKMapItem转换，用于地理围栏搜刮）
struct ExplorablePOI: Identifiable, Equatable {
    let id: String                          // UUID
    let name: String                        // POI名称
    let type: POIType                       // POI类型
    let coordinate: CLLocationCoordinate2D  // 坐标位置（WGS-84）
    var isScavenged: Bool                   // 是否已搜刮

    /// 围栏标识符（用于CLCircularRegion）
    var regionIdentifier: String {
        "poi_region_\(id)"
    }

    /// 从 MKMapItem 创建 ExplorablePOI
    /// - Parameter mapItem: MapKit搜索结果
    /// - Returns: 转换后的ExplorablePOI，如果信息不完整则返回nil
    static func from(mapItem: MKMapItem) -> ExplorablePOI? {
        guard let name = mapItem.name,
              let location = mapItem.placemark.location else {
            return nil
        }

        // 映射POI类型
        let poiType = mapPOIType(from: mapItem.pointOfInterestCategory)

        return ExplorablePOI(
            id: UUID().uuidString,
            name: name,
            type: poiType,
            coordinate: location.coordinate,
            isScavenged: false
        )
    }

    /// MKPointOfInterestCategory → POIType 映射
    /// - Parameter category: Apple的POI分类
    /// - Returns: 游戏中的POI类型
    private static func mapPOIType(from category: MKPointOfInterestCategory?) -> POIType {
        guard let category = category else { return .residential }

        switch category {
        case .store, .foodMarket:
            return .supermarket
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation, .evCharger:
            return .gasStation
        case .restaurant, .cafe, .bakery:
            return .supermarket  // 餐饮类归为超市（有食物）
        case .bank, .atm:
            return .warehouse    // 银行类归为仓库
        default:
            return .residential
        }
    }

    // MARK: - Equatable

    static func == (lhs: ExplorablePOI, rhs: ExplorablePOI) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 背包物品相关

/// 物品分类
enum ItemCategory: String, Codable, CaseIterable {
    case water = "water"            // 水类
    case food = "food"              // 食物
    case medical = "medical"        // 医疗用品
    case material = "material"      // 材料
    case tool = "tool"              // 工具
    case weapon = "weapon"          // 武器
    case misc = "misc"              // 杂项

    /// 中文名称
    var displayName: String {
        switch self {
        case .water: return "水类"
        case .food: return "食物"
        case .medical: return "医疗"
        case .material: return "材料"
        case .tool: return "工具"
        case .weapon: return "武器"
        case .misc: return "杂项"
        }
    }

    /// 分类图标
    var iconName: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "bolt.fill"
        case .misc: return "questionmark.square.fill"
        }
    }
}

/// 物品稀有度
enum ItemRarity: String, Codable, CaseIterable {
    case common = "common"          // 普通（灰色）
    case uncommon = "uncommon"      // 优良（绿色）
    case rare = "rare"              // 稀有（蓝色）
    case epic = "epic"              // 史诗（紫色）
    case legendary = "legendary"    // 传说（橙色）

    /// 中文名称
    var displayName: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "优良"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }

    /// 稀有度对应颜色（十六进制）
    var colorHex: String {
        switch self {
        case .common: return "#9E9E9E"
        case .uncommon: return "#4CAF50"
        case .rare: return "#2196F3"
        case .epic: return "#9C27B0"
        case .legendary: return "#FF9800"
        }
    }
}

/// 物品品质（耐久度/新旧程度）
enum ItemQuality: String, Codable {
    case pristine = "pristine"      // 崭新
    case good = "good"              // 良好
    case worn = "worn"              // 磨损
    case damaged = "damaged"        // 损坏
    case ruined = "ruined"          // 报废

    /// 中文名称
    var displayName: String {
        switch self {
        case .pristine: return "崭新"
        case .good: return "良好"
        case .worn: return "磨损"
        case .damaged: return "损坏"
        case .ruined: return "报废"
        }
    }

    /// 品质百分比（影响物品效果）
    var effectMultiplier: Double {
        switch self {
        case .pristine: return 1.0
        case .good: return 0.85
        case .worn: return 0.65
        case .damaged: return 0.4
        case .ruined: return 0.1
        }
    }
}

/// 物品定义（静态数据，定义物品的基础属性）
struct ItemDefinition: Identifiable, Codable {
    let id: String                  // 物品唯一标识符
    let name: String                // 中文名称
    let category: ItemCategory      // 物品分类
    let weight: Double              // 单位重量（千克）
    let volume: Double              // 单位体积（升）
    let rarity: ItemRarity          // 稀有度
    let description: String?        // 物品描述
    let isStackable: Bool           // 是否可堆叠
    let maxStack: Int               // 最大堆叠数量
    let hasQuality: Bool            // 是否有品质属性（消耗品通常没有）

    init(id: String, name: String, category: ItemCategory, weight: Double, volume: Double,
         rarity: ItemRarity, description: String? = nil, isStackable: Bool = true,
         maxStack: Int = 99, hasQuality: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.weight = weight
        self.volume = volume
        self.rarity = rarity
        self.description = description
        self.isStackable = isStackable
        self.maxStack = maxStack
        self.hasQuality = hasQuality
    }
}

/// 背包物品实例（玩家实际拥有的物品）
struct InventoryItem: Identifiable, Codable {
    let id: String                  // 实例唯一ID
    let itemId: String              // 对应物品定义ID
    var quantity: Int               // 数量
    var quality: ItemQuality?       // 品质（可选，部分物品没有品质）
    let obtainedAt: Date            // 获得时间
    let obtainedFrom: String?       // 获得来源（POI名称等）

    /// 计算总重量
    func totalWeight(definition: ItemDefinition) -> Double {
        return definition.weight * Double(quantity)
    }

    /// 计算总体积
    func totalVolume(definition: ItemDefinition) -> Double {
        return definition.volume * Double(quantity)
    }
}

// MARK: - 探索结果相关

/// 探索统计数据
struct ExplorationStats: Codable {
    let walkingDistance: Double         // 本次行走距离（米）
    let totalWalkingDistance: Double    // 累计行走距离（米）
    let walkingDistanceRank: Int        // 行走距离排名

    let duration: TimeInterval          // 探索时长（秒）
    let discoveredPOIs: Int             // 发现的POI数量
    let lootedPOIs: Int                 // 搜刮的POI数量

    /// 格式化行走距离
    var formattedWalkingDistance: String {
        if walkingDistance >= 1000 {
            return String(format: "%.2f 公里", walkingDistance / 1000)
        } else {
            return String(format: "%.0f 米", walkingDistance)
        }
    }

    /// 格式化时长
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        } else {
            return "\(minutes)分\(seconds)秒"
        }
    }
}

/// 单次探索获得的物品
struct LootItem: Identifiable, Codable {
    let id: String
    let itemId: String              // 物品定义ID
    let quantity: Int               // 获得数量
    let quality: ItemQuality?       // 品质
}

/// 探索结果（单次探索的完整结果）
struct ExplorationResult: Identifiable, Codable {
    let id: String
    let startTime: Date             // 开始时间
    let endTime: Date               // 结束时间
    let stats: ExplorationStats     // 统计数据
    let lootItems: [LootItem]       // 获得的物品列表
    let visitedPOIs: [String]       // 访问过的POI ID列表

    /// 探索时长
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

// MARK: - 假数据实例

/// 探索模块假数据
struct MockExplorationData {

    // MARK: POI 假数据

    /// 5个不同状态的兴趣点
    /// 用于测试POI列表展示、地图标记、搜刮功能等
    static let pois: [POI] = [
        // 废弃超市：已发现，有物资
        POI(
            id: "poi_001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
            discoveryStatus: .discovered,
            lootStatus: .hasLoot,
            dangerLevel: 2,
            description: "一家被遗弃的大型超市，货架上可能还有残留的物资。注意可能有流浪者出没。"
        ),

        // 医院废墟：已发现，已被搜空
        POI(
            id: "poi_002",
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 31.2350, longitude: 121.4800),
            discoveryStatus: .discovered,
            lootStatus: .looted,
            dangerLevel: 4,
            description: "曾经繁忙的医院，现在已成废墟。医疗物资早已被搜刮一空，但内部结构复杂，可能存在危险。"
        ),

        // 加油站：未发现
        POI(
            id: "poi_003",
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 31.2280, longitude: 121.4680),
            discoveryStatus: .undiscovered,
            lootStatus: .hasLoot,
            dangerLevel: 3,
            description: "路边的加油站，可能还有燃料和便利店物资。"
        ),

        // 药店废墟：已发现，有物资
        POI(
            id: "poi_004",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 31.2320, longitude: 121.4720),
            discoveryStatus: .discovered,
            lootStatus: .hasLoot,
            dangerLevel: 1,
            description: "社区药店的残骸，规模不大但可能还有一些药品和医疗用品。"
        ),

        // 工厂废墟：未发现
        POI(
            id: "poi_005",
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 31.2400, longitude: 121.4850),
            discoveryStatus: .undiscovered,
            lootStatus: .hasLoot,
            dangerLevel: 5,
            description: "大型工业厂房，可能有大量材料和工具，但结构不稳定，非常危险。"
        )
    ]

    // MARK: 物品定义表

    /// 物品定义表
    /// 记录每种物品的基础属性，作为静态配置数据
    static let itemDefinitions: [String: ItemDefinition] = [
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
        )
    ]

    // MARK: 背包物品假数据

    /// 背包物品列表
    /// 用于测试背包UI、物品管理、重量计算等功能
    static let inventoryItems: [InventoryItem] = [
        // 矿泉水 x 5
        InventoryItem(
            id: "inv_001",
            itemId: "item_water_bottle",
            quantity: 5,
            quality: nil,  // 消耗品无品质
            obtainedAt: Date().addingTimeInterval(-3600),
            obtainedFrom: "废弃超市"
        ),

        // 罐头食品 x 3
        InventoryItem(
            id: "inv_002",
            itemId: "item_canned_food",
            quantity: 3,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-7200),
            obtainedFrom: "废弃超市"
        ),

        // 绷带 x 10
        InventoryItem(
            id: "inv_003",
            itemId: "item_bandage",
            quantity: 10,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-1800),
            obtainedFrom: "药店废墟"
        ),

        // 药品 x 4
        InventoryItem(
            id: "inv_004",
            itemId: "item_medicine",
            quantity: 4,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-1800),
            obtainedFrom: "药店废墟"
        ),

        // 木材 x 8（良好品质）
        InventoryItem(
            id: "inv_005",
            itemId: "item_wood",
            quantity: 8,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-5400),
            obtainedFrom: "野外采集"
        ),

        // 废金属 x 12（磨损品质）
        InventoryItem(
            id: "inv_006",
            itemId: "item_scrap_metal",
            quantity: 12,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-9000),
            obtainedFrom: "工厂废墟"
        ),

        // 手电筒 x 1（良好品质）
        InventoryItem(
            id: "inv_007",
            itemId: "item_flashlight",
            quantity: 1,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-86400),
            obtainedFrom: "初始装备"
        ),

        // 绳子 x 2（崭新品质）
        InventoryItem(
            id: "inv_008",
            itemId: "item_rope",
            quantity: 2,
            quality: .pristine,
            obtainedAt: Date().addingTimeInterval(-3600),
            obtainedFrom: "废弃超市"
        )
    ]

    // MARK: 探索结果假数据

    /// 单次探索结果示例
    /// 用于测试探索结束页面、统计展示、物品获取等功能
    static let explorationResult = ExplorationResult(
        id: "exp_001",
        startTime: Date().addingTimeInterval(-1800),  // 30分钟前
        endTime: Date(),
        stats: ExplorationStats(
            walkingDistance: 2500,              // 本次行走 2500 米
            totalWalkingDistance: 15000,        // 累计行走 15000 米
            walkingDistanceRank: 42,            // 排名第 42
            duration: 1800,                     // 30 分钟
            discoveredPOIs: 2,                  // 发现 2 个 POI
            lootedPOIs: 1                       // 搜刮 1 个 POI
        ),
        lootItems: [
            // 获得物品：木材 x 5
            LootItem(id: "loot_001", itemId: "item_wood", quantity: 5, quality: .good),
            // 获得物品：矿泉水 x 3
            LootItem(id: "loot_002", itemId: "item_water_bottle", quantity: 3, quality: nil),
            // 获得物品：罐头 x 2
            LootItem(id: "loot_003", itemId: "item_canned_food", quantity: 2, quality: nil)
        ],
        visitedPOIs: ["poi_001", "poi_004"]    // 访问了废弃超市和药店废墟
    )

    /// 探索统计数据示例
    /// 用于测试统计页面单独展示
    static let explorationStats = ExplorationStats(
        walkingDistance: 2500,
        totalWalkingDistance: 15000,
        walkingDistanceRank: 42,
        duration: 1800,
        discoveredPOIs: 2,
        lootedPOIs: 1
    )

    // MARK: 辅助方法

    /// 根据物品ID获取物品定义
    static func getItemDefinition(for itemId: String) -> ItemDefinition? {
        return itemDefinitions[itemId]
    }

    /// 计算背包总重量
    static func calculateTotalWeight() -> Double {
        var totalWeight: Double = 0
        for item in inventoryItems {
            if let definition = itemDefinitions[item.itemId] {
                totalWeight += item.totalWeight(definition: definition)
            }
        }
        return totalWeight
    }

    /// 计算背包总体积
    static func calculateTotalVolume() -> Double {
        var totalVolume: Double = 0
        for item in inventoryItems {
            if let definition = itemDefinitions[item.itemId] {
                totalVolume += item.totalVolume(definition: definition)
            }
        }
        return totalVolume
    }

    /// 按分类获取背包物品
    static func getInventoryItems(by category: ItemCategory) -> [InventoryItem] {
        return inventoryItems.filter { item in
            guard let definition = itemDefinitions[item.itemId] else { return false }
            return definition.category == category
        }
    }

    /// 获取已发现的POI列表
    static func getDiscoveredPOIs() -> [POI] {
        return pois.filter { $0.discoveryStatus == .discovered }
    }

    /// 获取有物资的POI列表
    static func getPOIsWithLoot() -> [POI] {
        return pois.filter { $0.lootStatus == .hasLoot && $0.discoveryStatus == .discovered }
    }
}
