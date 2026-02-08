//
//  ItemPickerView.swift
//  EarthLord
//
//  物品选择器弹窗
//  支持从背包选择物品或从物品目录选择
//

import SwiftUI

/// 物品选择模式
enum ItemPickerMode {
    case fromBackpack     // 从背包选择（我要出的物品）
    case fromCatalog      // 从物品目录选择（我想要的物品）
}

/// 物品选择器视图
struct ItemPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var inventoryManager: InventoryManager

    /// 选择模式
    let mode: ItemPickerMode

    /// 选中物品回调
    let onSelect: (TradeItem) -> Void

    // MARK: 状态

    /// 搜索文字
    @State private var searchText: String = ""

    /// 选中的分类
    @State private var selectedCategory: ItemCategory?

    /// 选中的物品ID
    @State private var selectedItemId: String?

    /// 选中的物品品质
    @State private var selectedQuality: String?

    /// 选中的数量
    @State private var quantity: Int = 1

    /// 可选的最大数量
    @State private var maxQuantity: Int = 99

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索框
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // 分类筛选
                    categoryFilter
                        .padding(.top, 12)

                    // 物品列表
                    itemList
                        .padding(.top, 12)

                    // 数量选择器（选中物品后显示）
                    if selectedItemId != nil {
                        quantitySelector
                    }
                }
            }
            .navigationTitle(mode == .fromBackpack ? "选择出售物品" : "选择想要的物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("确认") {
                        confirmSelection()
                    }
                    .foregroundColor(selectedItemId != nil ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .disabled(selectedItemId == nil)
                }
            }
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - 搜索框

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

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部分类
                categoryButton(nil, title: "全部", icon: "square.grid.2x2.fill")

                // 各分类
                ForEach(ItemCategory.allCases, id: \.self) { category in
                    categoryButton(category, title: category.displayName, icon: category.iconName)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryButton(_ category: ItemCategory?, title: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: selectedCategory == category ? .semibold : .regular))
            }
            .foregroundColor(selectedCategory == category ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedCategory == category ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
        }
    }

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if mode == .fromBackpack {
                    // 从背包选择
                    ForEach(filteredBackpackItems, id: \.item.id) { pair in
                        backpackItemRow(item: pair.item, definition: pair.definition)
                    }
                } else {
                    // 从物品目录选择
                    ForEach(filteredCatalogItems, id: \.id) { definition in
                        catalogItemRow(definition: definition)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 背包物品行

    private func backpackItemRow(item: InventoryItem, definition: ItemDefinition) -> some View {
        Button {
            selectBackpackItem(item: item, definition: definition)
        } label: {
            HStack(spacing: 12) {
                // 选中指示器
                Image(systemName: selectedItemId == item.id ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedItemId == item.id ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)

                // 分类图标
                ZStack {
                    Circle()
                        .fill(categoryColor(definition.category).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: definition.category.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(categoryColor(definition.category))
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text("库存: \(item.quantity)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        if let quality = item.quality {
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
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedItemId == item.id ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
            )
        }
    }

    // MARK: - 目录物品行

    private func catalogItemRow(definition: ItemDefinition) -> some View {
        Button {
            selectCatalogItem(definition: definition)
        } label: {
            HStack(spacing: 12) {
                // 选中指示器
                Image(systemName: selectedItemId == definition.id ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectedItemId == definition.id ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)

                // 分类图标
                ZStack {
                    Circle()
                        .fill(categoryColor(definition.category).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: definition.category.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(categoryColor(definition.category))
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(definition.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 稀有度标签
                        Text(definition.rarity.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(rarityColor(definition.rarity))
                            )
                    }

                    if let desc = definition.description {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedItemId == definition.id ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
            )
        }
    }

    // MARK: - 数量选择器

    private var quantitySelector: some View {
        VStack(spacing: 12) {
            Divider()
                .background(ApocalypseTheme.textMuted)

            HStack {
                Text("数量")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 减少按钮
                Button {
                    if quantity > 1 {
                        quantity -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(quantity <= 1)

                // 数量显示
                Text("\(quantity)")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(width: 60)

                // 增加按钮
                Button {
                    if quantity < maxQuantity {
                        quantity += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(quantity < maxQuantity ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(quantity >= maxQuantity)

                Text("/ \(maxQuantity)")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 筛选后的物品

    private var filteredBackpackItems: [(item: InventoryItem, definition: ItemDefinition)] {
        var result: [(InventoryItem, ItemDefinition)] = []

        for item in inventoryManager.items {
            guard let definition = ItemDefinitions.get(item.itemId) else { continue }

            // 分类筛选
            if let category = selectedCategory, definition.category != category {
                continue
            }

            // 搜索筛选
            if !searchText.isEmpty, !definition.name.localizedCaseInsensitiveContains(searchText) {
                continue
            }

            result.append((item, definition))
        }

        return result
    }

    private var filteredCatalogItems: [ItemDefinition] {
        var items = Array(ItemDefinitions.all.values)

        // 分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // 按稀有度排序
        items.sort { $0.rarity.rawValue < $1.rarity.rawValue }

        return items
    }

    // MARK: - 选择逻辑

    private func selectBackpackItem(item: InventoryItem, definition: ItemDefinition) {
        selectedItemId = item.id
        selectedQuality = item.quality?.rawValue
        maxQuantity = item.quantity
        quantity = min(quantity, maxQuantity)
        if quantity == 0 { quantity = 1 }
    }

    private func selectCatalogItem(definition: ItemDefinition) {
        selectedItemId = definition.id
        selectedQuality = nil
        maxQuantity = definition.maxStack
        quantity = min(quantity, maxQuantity)
        if quantity == 0 { quantity = 1 }
    }

    private func confirmSelection() {
        guard let itemId = selectedItemId else { return }

        let finalItemId: String
        if mode == .fromBackpack {
            // 从背包选择时，需要获取实际的 itemId
            if let item = inventoryManager.items.first(where: { $0.id == itemId }) {
                finalItemId = item.itemId
            } else {
                return
            }
        } else {
            finalItemId = itemId
        }

        let tradeItem = TradeItem(
            itemId: finalItemId,
            quantity: quantity,
            quality: selectedQuality
        )

        onSelect(tradeItem)
        dismiss()
    }

    // MARK: - 颜色辅助

    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .water: return ApocalypseTheme.info
        case .food: return ApocalypseTheme.success
        case .medical: return Color.red
        case .material: return Color.brown
        case .tool: return ApocalypseTheme.warning
        case .weapon: return Color.purple
        case .misc: return ApocalypseTheme.textMuted
        }
    }

    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .pristine: return ApocalypseTheme.success
        case .good: return ApocalypseTheme.info
        case .worn: return ApocalypseTheme.warning
        case .damaged: return ApocalypseTheme.primary
        case .ruined: return ApocalypseTheme.danger
        }
    }

    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return Color.gray
        case .uncommon: return Color.green
        case .rare: return Color.blue
        case .epic: return Color.purple
        case .legendary: return Color.orange
        }
    }
}

// MARK: - Preview

#Preview {
    ItemPickerView(mode: .fromCatalog) { item in
        print("Selected: \(item.displayName)")
    }
}
