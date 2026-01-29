//
//  BuildingManager.swift
//  EarthLord
//
//  建筑管理器
//  管理建筑模板加载、建造、升级和数据同步
//

import Foundation
import Supabase
import Combine

// MARK: - 建筑管理器

/// 建筑管理器
/// 管理建筑模板加载、建造、升级和数据同步
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - Published Properties

    /// 建筑模板字典
    @Published var templates: [String: BuildingTemplate] = [:]

    /// 当前领地的建筑列表
    @Published var buildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let supabaseClient: SupabaseClient
    private weak var inventoryManager: InventoryManager?
    private var buildCheckTimer: Timer?

    // MARK: - Initialization

    init(supabase: SupabaseClient, inventoryManager: InventoryManager? = nil) {
        self.supabaseClient = supabase
        self.inventoryManager = inventoryManager
    }

    deinit {
        buildCheckTimer?.invalidate()
    }

    // MARK: - Template Loading

    /// 从 JSON 文件加载建筑模板
    func loadTemplates() async throws {
        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("[建筑] ❌ 找不到 building_templates.json 文件")
            throw BuildingError.templateLoadFailed
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let templateList = try decoder.decode([BuildingTemplate].self, from: data)

            // 转换为字典
            var templateDict: [String: BuildingTemplate] = [:]
            for template in templateList {
                templateDict[template.id] = template
            }
            templates = templateDict

            print("[建筑] ✅ 成功加载 \(templates.count) 个建筑模板")
        } catch {
            print("[建筑] ❌ 加载建筑模板失败: \(error)")
            throw BuildingError.templateLoadFailed
        }
    }

    /// 获取指定分类的模板
    func getTemplates(for category: BuildingCategory) -> [BuildingTemplate] {
        return templates.values.filter { $0.category == category }
    }

    /// 获取指定ID的模板
    func getTemplate(_ templateId: String) -> BuildingTemplate? {
        return templates[templateId]
    }

    // MARK: - Resource Checking

    /// 检查是否有足够资源建造
    /// - Parameter template: 建筑模板
    /// - Returns: 资源检查结果
    func checkResources(for template: BuildingTemplate) -> ResourceCheckResult {
        guard let inventoryManager = inventoryManager else {
            return ResourceCheckResult(
                canBuild: false,
                missingResources: template.requiredResources,
                availableResources: [:]
            )
        }

        var missingResources: [String: Int] = [:]
        var availableResources: [String: Int] = [:]

        for (itemId, requiredQty) in template.requiredResources {
            // 统计背包中该物品的总数量
            let totalOwned = inventoryManager.items
                .filter { $0.itemId == itemId }
                .reduce(0) { $0 + $1.quantity }

            availableResources[itemId] = totalOwned

            if totalOwned < requiredQty {
                missingResources[itemId] = requiredQty - totalOwned
            }
        }

        return ResourceCheckResult(
            canBuild: missingResources.isEmpty,
            missingResources: missingResources,
            availableResources: availableResources
        )
    }

    /// 检查是否可以建造
    /// - Parameters:
    ///   - templateId: 建筑模板ID
    ///   - territoryId: 领地ID
    /// - Returns: (是否可建造, 错误信息)
    func canBuild(templateId: String, territoryId: String) -> (Bool, String?) {
        // 检查模板是否存在
        guard let template = templates[templateId] else {
            return (false, "建筑模板不存在")
        }

        // 检查该领地该类型建筑数量是否达到上限
        let existingCount = buildings.filter { $0.template.id == templateId }.count
        if existingCount >= template.maxPerTerritory {
            return (false, "该类型建筑数量已达上限 (\(template.maxPerTerritory))")
        }

        // 检查资源
        let resourceCheck = checkResources(for: template)
        if !resourceCheck.hasEnoughResources {
            let missingItems = resourceCheck.missingResources.map { itemId, qty in
                let itemName = ItemDefinitions.get(itemId)?.name ?? itemId
                return "\(itemName) x\(qty)"
            }.joined(separator: ", ")
            return (false, "资源不足: \(missingItems)")
        }

        return (true, nil)
    }

    // MARK: - Construction

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 建筑模板ID
    ///   - territoryId: 领地ID
    ///   - locationLat: 位置纬度（可选）
    ///   - locationLon: 位置经度（可选）
    func startConstruction(
        templateId: String,
        territoryId: String,
        locationLat: Double? = nil,
        locationLon: Double? = nil
    ) async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw BuildingError.notAuthenticated
        }

        guard let template = templates[templateId] else {
            throw BuildingError.templateNotFound
        }

        // 检查是否可以建造
        let (canBuild, errorMsg) = self.canBuild(templateId: templateId, territoryId: territoryId)
        if !canBuild {
            throw BuildingError.insufficientResources([:])
        }

        // 扣除资源
        try await deductResources(for: template)

        // 创建建筑记录
        let insertBuilding = InsertPlayerBuilding(
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: locationLat,
            locationLon: locationLon
        )

        do {
            try await supabaseClient
                .from("player_buildings")
                .insert(insertBuilding)
                .execute()

            print("[建筑] ✅ 开始建造: \(template.name)")

            // 重新加载建筑列表
            try await loadBuildings(for: territoryId)

            // 启动建造完成检查定时器
            startBuildCheckTimer(territoryId: territoryId)

        } catch {
            print("[建筑] ❌ 创建建筑记录失败: \(error)")
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    /// 扣除建造所需资源
    private func deductResources(for template: BuildingTemplate) async throws {
        guard let inventoryManager = inventoryManager else {
            throw BuildingError.insufficientResources(template.requiredResources)
        }

        for (itemId, requiredQty) in template.requiredResources {
            var remaining = requiredQty

            // 获取所有匹配的物品（按获取时间排序，先扣旧的）
            let matchingItems = inventoryManager.items
                .filter { $0.itemId == itemId }
                .sorted { $0.obtainedAt < $1.obtainedAt }

            for item in matchingItems where remaining > 0 {
                let deductAmount = min(item.quantity, remaining)
                try await inventoryManager.useItem(inventoryItemId: item.id, quantity: deductAmount)
                remaining -= deductAmount
            }

            if remaining > 0 {
                throw BuildingError.insufficientResources([itemId: remaining])
            }
        }

        print("[建筑] ✅ 资源扣除完成")
    }

    // MARK: - Construction Completion

    /// 完成建造
    /// - Parameter buildingId: 建筑ID
    func completeConstruction(buildingId: String) async throws {
        guard let building = buildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        guard building.status == .constructing else {
            throw BuildingError.alreadyCompleted
        }

        guard building.isConstructionComplete else {
            throw BuildingError.invalidStatus
        }

        do {
            try await supabaseClient
                .from("player_buildings")
                .update([
                    "status": BuildingStatus.active.rawValue,
                    "build_completed_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: buildingId)
                .execute()

            print("[建筑] ✅ 建造完成: \(building.template.name)")

            // 更新本地状态
            if let index = buildings.firstIndex(where: { $0.id == buildingId }) {
                buildings[index].status = .active
                buildings[index].buildCompletedAt = Date()
            }

        } catch {
            print("[建筑] ❌ 更新建筑状态失败: \(error)")
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    /// 检查并自动完成已到时间的建筑
    func checkAndCompleteBuildings() async {
        let constructingBuildings = buildings.filter { $0.status == .constructing && $0.isConstructionComplete }

        for building in constructingBuildings {
            do {
                try await completeConstruction(buildingId: building.id)
            } catch {
                print("[建筑] ❌ 自动完成建筑失败: \(error)")
            }
        }
    }

    // MARK: - Upgrade

    /// 升级建筑
    /// - Parameter buildingId: 建筑ID
    func upgradeBuilding(buildingId: String) async throws {
        guard let building = buildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.buildingNotFound
        }

        guard building.canUpgrade else {
            throw BuildingError.cannotUpgrade
        }

        // 计算升级所需资源（基础资源 * 当前等级）
        var upgradeResources: [String: Int] = [:]
        for (itemId, baseQty) in building.template.requiredResources {
            upgradeResources[itemId] = baseQty * building.level
        }

        // 检查资源
        guard let inventoryManager = inventoryManager else {
            throw BuildingError.insufficientResources(upgradeResources)
        }

        var missingResources: [String: Int] = [:]
        for (itemId, requiredQty) in upgradeResources {
            let totalOwned = inventoryManager.items
                .filter { $0.itemId == itemId }
                .reduce(0) { $0 + $1.quantity }
            if totalOwned < requiredQty {
                missingResources[itemId] = requiredQty - totalOwned
            }
        }

        if !missingResources.isEmpty {
            throw BuildingError.insufficientResources(missingResources)
        }

        // 扣除资源
        for (itemId, requiredQty) in upgradeResources {
            var remaining = requiredQty
            let matchingItems = inventoryManager.items
                .filter { $0.itemId == itemId }
                .sorted { $0.obtainedAt < $1.obtainedAt }

            for item in matchingItems where remaining > 0 {
                let deductAmount = min(item.quantity, remaining)
                try await inventoryManager.useItem(inventoryItemId: item.id, quantity: deductAmount)
                remaining -= deductAmount
            }
        }

        // 更新建筑等级
        let newLevel = building.level + 1
        do {
            try await supabaseClient
                .from("player_buildings")
                .update(["level": newLevel])
                .eq("id", value: buildingId)
                .execute()

            print("[建筑] ✅ 升级完成: \(building.template.name) -> Lv.\(newLevel)")

            // 更新本地状态
            if let index = buildings.firstIndex(where: { $0.id == buildingId }) {
                buildings[index].level = newLevel
            }

        } catch {
            print("[建筑] ❌ 升级建筑失败: \(error)")
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - Data Loading

    /// 加载指定领地的建筑
    /// - Parameter territoryId: 领地ID
    func loadBuildings(for territoryId: String) async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw BuildingError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: [PlayerBuildingDB] = try await supabaseClient
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("territory_id", value: territoryId)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 转换为应用层模型
            var loadedBuildings: [PlayerBuilding] = []
            for dbBuilding in response {
                if let template = templates[dbBuilding.templateId] {
                    loadedBuildings.append(dbBuilding.toPlayerBuilding(template: template))
                }
            }

            buildings = loadedBuildings
            isLoading = false

            print("[建筑] ✅ 加载 \(buildings.count) 个建筑")

            // 检查是否有需要完成的建筑
            await checkAndCompleteBuildings()

        } catch {
            isLoading = false
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
            print("[建筑] ❌ 加载建筑失败: \(error)")
            throw error
        }
    }

    /// 加载用户所有建筑
    func loadAllBuildings() async throws {
        guard let userId = supabaseClient.auth.currentUser?.id else {
            throw BuildingError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: [PlayerBuildingDB] = try await supabaseClient
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            var loadedBuildings: [PlayerBuilding] = []
            for dbBuilding in response {
                if let template = templates[dbBuilding.templateId] {
                    loadedBuildings.append(dbBuilding.toPlayerBuilding(template: template))
                }
            }

            buildings = loadedBuildings
            isLoading = false

            print("[建筑] ✅ 加载 \(buildings.count) 个建筑（全部）")

        } catch {
            isLoading = false
            errorMessage = "加载建筑失败: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Timer

    /// 启动建造完成检查定时器
    private func startBuildCheckTimer(territoryId: String) {
        buildCheckTimer?.invalidate()
        buildCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndCompleteBuildings()
            }
        }
    }

    /// 停止建造完成检查定时器
    func stopBuildCheckTimer() {
        buildCheckTimer?.invalidate()
        buildCheckTimer = nil
    }

    // MARK: - Statistics

    /// 获取指定类型建筑的数量
    func getBuildingCount(templateId: String) -> Int {
        return buildings.filter { $0.template.id == templateId }.count
    }

    /// 获取指定分类建筑的数量
    func getBuildingCount(category: BuildingCategory) -> Int {
        return buildings.filter { $0.template.category == category }.count
    }

    /// 获取正在建造中的建筑数量
    var constructingCount: Int {
        return buildings.filter { $0.status == .constructing }.count
    }

    /// 获取已完成的建筑数量
    var activeCount: Int {
        return buildings.filter { $0.status == .active }.count
    }
}
