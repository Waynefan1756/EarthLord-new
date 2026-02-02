//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 全屏地图布局
//  包含地图视图、悬浮工具栏、可折叠信息面板、建筑管理
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    let territory: Territory
    let territoryManager: TerritoryManager
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var showDeleteAlert = false
    @State private var showRenameAlert = false
    @State private var isDeleting = false
    @State private var newName = ""

    // 面板状态
    @State private var isPanelExpanded = true

    // Sheet 状态
    @State private var showBuildingBrowser = false
    @State private var templateToPlace: BuildingTemplate?
    @State private var selectedBuilding: PlayerBuilding?

    // 建筑管理器和背包管理器
    @StateObject private var buildingManager: BuildingManager
    @StateObject private var inventoryManager: InventoryManager

    // MARK: - Init

    init(territory: Territory, territoryManager: TerritoryManager, onDelete: (() -> Void)?) {
        self.territory = territory
        self.territoryManager = territoryManager
        self.onDelete = onDelete
        self._newName = State(initialValue: territory.name ?? "")

        // 创建背包管理器
        let inventory = InventoryManager(supabase: supabase)
        self._inventoryManager = StateObject(wrappedValue: inventory)
        // 创建建筑管理器并传入背包管理器
        self._buildingManager = StateObject(wrappedValue: BuildingManager(supabase: supabase, inventoryManager: inventory))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 底层全屏地图
            TerritoryMapView(
                territory: territory,
                buildings: buildingManager.buildings
            )
            .ignoresSafeArea()

            // 覆盖层
            VStack(spacing: 0) {
                // 顶部安全区
                Color.clear
                    .frame(height: 0)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                        .offset(y: -60)
                    )

                // 顶部工具栏
                TerritoryToolbarView(
                    title: territory.displayName,
                    onBack: { dismiss() },
                    onRename: { showRenameAlert = true },
                    onBuild: { showBuildingBrowser = true },
                    onDelete: { showDeleteAlert = true }
                )

                Spacer()

                // 底部信息面板
                infoPanel
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
        }
        // Sheet 1: 建筑浏览器
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                territoryId: territory.id,
                buildingManager: buildingManager
            ) { template in
                // 延迟跳转避免动画冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    templateToPlace = template
                }
            }
        }
        // Sheet 2: 建造确认页
        .sheet(item: $templateToPlace) { template in
            BuildingPlacementView(
                template: template,
                territory: territory,
                buildingManager: buildingManager
            ) {
                // 建造完成后刷新
                Task {
                    try? await buildingManager.loadBuildings(for: territory.id)
                }
            }
        }
        // Sheet 3: 建筑详情
        .sheet(item: $selectedBuilding) { building in
            BuildingDetailView(
                building: building,
                buildingManager: buildingManager
            ) {
                Task {
                    try? await buildingManager.loadBuildings(for: territory.id)
                }
            }
        }
        // 删除确认弹窗
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await deleteTerritoryAction()
                }
            }
        } message: {
            Text("确定要删除这个领地吗？此操作无法撤销。")
        }
        // 重命名弹窗
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("领地名称", text: $newName)
            Button("取消", role: .cancel) {
                newName = territory.name ?? ""
            }
            Button("确定") {
                Task {
                    await renameTerritory()
                }
            }
        } message: {
            Text("请输入新的领地名称")
        }
    }

    // MARK: - Subviews

    /// 底部信息面板
    private var infoPanel: some View {
        VStack(spacing: 0) {
            // 拖动手柄
            panelHandle

            if isPanelExpanded {
                VStack(spacing: 16) {
                    // 领地信息
                    territoryInfoSection

                    // 建筑列表
                    buildingListSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
        )
        .animation(.spring(response: 0.3), value: isPanelExpanded)
    }

    /// 拖动手柄
    private var panelHandle: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ApocalypseTheme.textMuted)
                .frame(width: 36, height: 4)

            HStack {
                Text("领地信息")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, isPanelExpanded ? 8 : 12)
        .contentShape(Rectangle())
        .onTapGesture {
            isPanelExpanded.toggle()
        }
    }

    /// 领地信息区域
    private var territoryInfoSection: some View {
        HStack(spacing: 20) {
            infoItem(icon: "map", label: "面积", value: territory.formattedArea)
            infoItem(icon: "point.3.connected.trianglepath.dotted", label: "路径点", value: "\(territory.pointCount ?? 0)")
            infoItem(icon: "building.2", label: "建筑", value: "\(buildingManager.buildings.count)")
        }
        .padding(16)
        .background(ApocalypseTheme.background)
        .cornerRadius(12)
    }

    /// 信息项
    private func infoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 建筑列表区域
    private var buildingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("建筑列表")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Button(action: { showBuildingBrowser = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("建造")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            if buildingManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if buildingManager.buildings.isEmpty {
                emptyBuildingView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(buildingManager.buildings) { building in
                            TerritoryBuildingRow(
                                building: building,
                                onUpgrade: {
                                    selectedBuilding = building
                                },
                                onDemolish: {
                                    Task {
                                        try? await buildingManager.demolishBuilding(buildingId: building.id)
                                    }
                                }
                            )
                            .onTapGesture {
                                selectedBuilding = building
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
    }

    /// 空建筑视图
    private var emptyBuildingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 32))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有建筑")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Button(action: { showBuildingBrowser = true }) {
                Text("开始建造")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ApocalypseTheme.primary.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Methods

    /// 加载数据
    private func loadData() {
        Task {
            // 加载背包数据（用于资源检查）
            try? await inventoryManager.loadInventory()
            // 加载建筑模板
            if buildingManager.templates.isEmpty {
                try? await buildingManager.loadTemplates()
            }
            // 加载领地建筑
            try? await buildingManager.loadBuildings(for: territory.id)
        }
    }

    /// 删除领地操作
    private func deleteTerritoryAction() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        if success {
            onDelete?()
            dismiss()
        }

        isDeleting = false
    }

    /// 重命名领地
    private func renameTerritory() async {
        guard !newName.isEmpty else { return }

        let success = await territoryManager.updateTerritoryName(territoryId: territory.id, name: newName)

        if success {
            // 通知已在 TerritoryManager 中发送
        }
    }
}

// MARK: - PlayerBuilding Hashable

extension PlayerBuilding: Hashable {
    static func == (lhs: PlayerBuilding, rhs: PlayerBuilding) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "test-user",
            name: "测试领地",
            path: [
                ["lat": 31.230, "lon": 121.470],
                ["lat": 31.231, "lon": 121.471],
                ["lat": 31.230, "lon": 121.472],
                ["lat": 31.229, "lon": 121.471]
            ],
            area: 5000,
            pointCount: 50,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2026-01-07T10:00:00Z"
        ),
        territoryManager: TerritoryManager(supabase: supabase),
        onDelete: nil
    )
}
