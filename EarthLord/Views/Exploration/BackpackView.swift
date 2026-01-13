//
//  BackpackView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//
//  背包管理页面
//  显示容量状态、物品搜索筛选和物品列表
//

import SwiftUI

// MARK: - 背包筛选类型

/// 背包物品筛选选项
enum BackpackFilterType: String, CaseIterable {
    case all = "全部"
    case food = "食物"
    case water = "水"
    case material = "材料"
    case tool = "工具"
    case medical = "医疗"

    /// 对应的 ItemCategory（全部返回 nil）
    var itemCategory: ItemCategory? {
        switch self {
        case .all: return nil
        case .food: return .food
        case .water: return .water
        case .material: return .material
        case .tool: return .tool
        case .medical: return .medical
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .medical: return "cross.case.fill"
        }
    }
}

// MARK: - 背包视图

struct BackpackView: View {
    // MARK: 依赖

    /// 背包管理器（从 App 注入的全局实例）
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: 状态

    /// 搜索文字
    @State private var searchText: String = ""

    /// 当前选中的筛选类型
    @State private var selectedFilter: BackpackFilterType = .all

    /// 动画用的容量值
    @State private var animatedCapacity: Double = 0

    /// 列表项可见状态（用于淡入动画）
    @State private var visibleItems: Set<String> = []

    /// 背包容量设置
    private let maxCapacity: Double = 100.0  // 最大容量（kg）

    /// 当前使用的容量
    private var usedCapacity: Double {
        inventoryManager.totalWeight
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        usedCapacity / maxCapacity
    }

    /// 筛选后的物品列表
    private var filteredItems: [(item: InventoryItem, definition: ItemDefinition)] {
        var result: [(InventoryItem, ItemDefinition)] = []

        for item in inventoryManager.items {
            guard let definition = ItemDefinitions.get(item.itemId) else {
                continue
            }

            // 分类筛选
            if let category = selectedFilter.itemCategory {
                if definition.category != category {
                    continue
                }
            }

            // 搜索筛选
            if !searchText.isEmpty {
                if !definition.name.localizedCaseInsensitiveContains(searchText) {
                    continue
                }
            }

            result.append((item, definition))
        }

        return result
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 搜索和筛选
                searchAndFilterSection
                    .padding(.top, 16)

                // 物品列表或空状态
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemList
                }
            }
        }
        // 注意：BackpackView 嵌套在 ResourcesTabView 的 NavigationStack 中
        // 不需要单独设置 navigationTitle，由父视图统一管理
        .onAppear {
            // 加载背包数据
            Task {
                try? await inventoryManager.loadInventory()
            }
        }
        .refreshable {
            // 下拉刷新
            try? await inventoryManager.loadInventory()
        }
    }

    // MARK: - 容量状态卡

    private var capacityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "bag.fill")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 容量数值（使用动画值）
                Text(String(format: "%.1f / %.0f kg", animatedCapacity, maxCapacity))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .contentTransition(.numericText())  // 数字过渡动画
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.background)
                        .frame(height: 12)

                    // 已使用容量（使用动画值）
                    RoundedRectangle(cornerRadius: 6)
                        .fill(animatedCapacityColor)
                        .frame(width: geometry.size.width * min(animatedCapacity / maxCapacity, 1.0), height: 12)
                        .animation(.easeInOut(duration: 0.8), value: animatedCapacity)
                }
            }
            .frame(height: 12)

            // 警告文字（超过90%时显示）
            if capacityPercentage > 0.9 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .onAppear {
            // 页面出现时触发容量动画
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedCapacity = usedCapacity
            }
        }
    }

    /// 动画容量进度条颜色
    private var animatedCapacityColor: Color {
        let percentage = animatedCapacity / maxCapacity
        if percentage > 0.9 {
            return ApocalypseTheme.danger      // >90% 红色
        } else if percentage > 0.7 {
            return ApocalypseTheme.warning     // 70-90% 黄色
        } else {
            return ApocalypseTheme.success     // <70% 绿色
        }
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger      // >90% 红色
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning     // 70-90% 黄色
        } else {
            return ApocalypseTheme.success     // <70% 绿色
        }
    }

    // MARK: - 搜索和筛选

    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜索框
            searchBar
                .padding(.horizontal, 16)

            // 分类筛选按钮
            filterButtons
        }
    }

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 分类筛选按钮
    private var filterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BackpackFilterType.allCases, id: \.self) { filter in
                    filterButton(for: filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    /// 单个筛选按钮
    private func filterButton(for filter: BackpackFilterType) -> some View {
        Button {
            // 切换分类时重置可见项，触发重新动画
            visibleItems.removeAll()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 12))

                Text(filter.rawValue)
                    .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .regular))
            }
            .foregroundColor(selectedFilter == filter ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedFilter == filter ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredItems, id: \.item.id) { pair in
                    itemRow(pair: pair, index: filteredItems.firstIndex(where: { $0.item.id == pair.item.id }) ?? 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedFilter)  // 切换分类时的过渡
    }

    /// 单个物品行（带动画）
    private func itemRow(pair: (item: InventoryItem, definition: ItemDefinition), index: Int) -> some View {
        ItemCardView(item: pair.item, definition: pair.definition)
            .opacity(visibleItems.contains(pair.item.id) ? 1 : 0)
            .offset(x: visibleItems.contains(pair.item.id) ? 0 : -20)
            .onAppear {
                // 依次淡入动画
                if !visibleItems.contains(pair.item.id) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            _ = visibleItems.insert(pair.item.id)
                        }
                    }
                }
            }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("没有找到物品")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(searchText.isEmpty ? "当前分类下没有物品" : "尝试搜索其他关键词")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
    }
}

// MARK: - 物品卡片视图

struct ItemCardView: View {
    let item: InventoryItem
    let definition: ItemDefinition

    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            categoryIcon

            // 物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称 + 稀有度标签
                HStack(spacing: 8) {
                    Text(definition.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    rarityBadge
                }

                // 第二行：数量、重量、品质
                HStack(spacing: 12) {
                    // 数量
                    Label("x\(item.quantity)", systemImage: "number")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 重量
                    Label(String(format: "%.1fkg", item.totalWeight(definition: definition)), systemImage: "scalemass")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质（如有）
                    if let quality = item.quality {
                        qualityBadge(quality)
                    }
                }
            }

            Spacer()

            // 操作按钮
            actionButtons
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: 分类图标

    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: definition.category.iconName)
                .font(.system(size: 18))
                .foregroundColor(categoryColor)
        }
    }

    /// 分类对应颜色
    private var categoryColor: Color {
        switch definition.category {
        case .water:
            return ApocalypseTheme.info        // 蓝色
        case .food:
            return ApocalypseTheme.success     // 绿色
        case .medical:
            return Color.red                   // 红色
        case .material:
            return Color.brown                 // 棕色
        case .tool:
            return ApocalypseTheme.warning     // 黄色
        case .weapon:
            return Color.purple                // 紫色
        case .misc:
            return ApocalypseTheme.textMuted   // 灰色
        }
    }

    // MARK: 稀有度标签

    private var rarityBadge: some View {
        Text(definition.rarity.displayName)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(rarityColor)
            )
    }

    /// 稀有度对应颜色
    private var rarityColor: Color {
        switch definition.rarity {
        case .common:
            return Color.gray                  // 普通：灰色
        case .uncommon:
            return Color.green                 // 优秀：绿色
        case .rare:
            return Color.blue                  // 稀有：蓝色
        case .epic:
            return Color.purple                // 史诗：紫色
        case .legendary:
            return Color.orange                // 传说：橙色
        }
    }

    // MARK: 品质标签

    private func qualityBadge(_ quality: ItemQuality) -> some View {
        Text(quality.displayName)
            .font(.system(size: 11))
            .foregroundColor(qualityColor(quality))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .stroke(qualityColor(quality), lineWidth: 1)
            )
    }

    /// 品质对应颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .pristine:
            return ApocalypseTheme.success     // 崭新：绿色
        case .good:
            return ApocalypseTheme.info        // 良好：蓝色
        case .worn:
            return ApocalypseTheme.warning     // 磨损：黄色
        case .damaged:
            return ApocalypseTheme.primary     // 损坏：橙色
        case .ruined:
            return ApocalypseTheme.danger      // 报废：红色
        }
    }

    // MARK: 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 6) {
            // 使用按钮
            Button {
                print("使用物品: \(definition.name), 数量: \(item.quantity)")
            } label: {
                Text("使用")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ApocalypseTheme.primary)
                    )
            }

            // 存储按钮
            Button {
                print("存储物品: \(definition.name), 数量: \(item.quantity)")
            } label: {
                Text("存储")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ApocalypseTheme.textMuted, lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackpackView()
    }
}
