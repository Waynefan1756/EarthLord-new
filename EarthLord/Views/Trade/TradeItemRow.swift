//
//  TradeItemRow.swift
//  EarthLord
//
//  交易物品行组件
//  显示物品图标、名称、数量和品质
//

import SwiftUI

/// 交易物品行
struct TradeItemRow: View {
    let tradeItem: TradeItem

    /// 物品定义
    private var definition: ItemDefinition? {
        ItemDefinitions.get(tradeItem.itemId)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            categoryIcon

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称
                Text(definition?.name ?? tradeItem.itemId)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 品质（如有）
                if let quality = tradeItem.quality,
                   let itemQuality = ItemQuality(rawValue: quality) {
                    Text(itemQuality.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(qualityColor(itemQuality))
                }
            }

            Spacer()

            // 数量
            Text("x\(tradeItem.quantity)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 分类图标

    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 36, height: 36)

            Image(systemName: definition?.category.iconName ?? "questionmark")
                .font(.system(size: 14))
                .foregroundColor(categoryColor)
        }
    }

    /// 分类对应颜色
    private var categoryColor: Color {
        guard let category = definition?.category else {
            return ApocalypseTheme.textMuted
        }

        switch category {
        case .water:
            return ApocalypseTheme.info
        case .food:
            return ApocalypseTheme.success
        case .medical:
            return Color.red
        case .material:
            return Color.brown
        case .tool:
            return ApocalypseTheme.warning
        case .weapon:
            return Color.purple
        case .misc:
            return ApocalypseTheme.textMuted
        }
    }

    /// 品质对应颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .pristine:
            return ApocalypseTheme.success
        case .good:
            return ApocalypseTheme.info
        case .worn:
            return ApocalypseTheme.warning
        case .damaged:
            return ApocalypseTheme.primary
        case .ruined:
            return ApocalypseTheme.danger
        }
    }
}

// MARK: - 紧凑型物品行

/// 紧凑型交易物品行（用于卡片摘要）
struct TradeItemCompactRow: View {
    let tradeItem: TradeItem

    private var definition: ItemDefinition? {
        ItemDefinitions.get(tradeItem.itemId)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: definition?.category.iconName ?? "questionmark")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(definition?.name ?? tradeItem.itemId)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Text("x\(tradeItem.quantity)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }
}

// MARK: - 物品摘要视图

/// 物品摘要视图（显示物品列表的缩略信息）
struct TradeItemsSummary: View {
    let items: [TradeItem]
    let maxDisplay: Int

    init(items: [TradeItem], maxDisplay: Int = 2) {
        self.items = items
        self.maxDisplay = maxDisplay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items.prefix(maxDisplay)) { item in
                TradeItemCompactRow(tradeItem: item)
            }

            if items.count > maxDisplay {
                Text("还有 \(items.count - maxDisplay) 件物品...")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TradeItemRow(tradeItem: TradeItem(
            itemId: "item_water_bottle",
            quantity: 5,
            quality: nil
        ))

        TradeItemRow(tradeItem: TradeItem(
            itemId: "item_wood",
            quantity: 10,
            quality: "good"
        ))

        Divider()

        TradeItemsSummary(items: [
            TradeItem(itemId: "item_water_bottle", quantity: 5, quality: nil),
            TradeItem(itemId: "item_canned_food", quantity: 3, quality: nil),
            TradeItem(itemId: "item_bandage", quantity: 10, quality: nil)
        ])
    }
    .padding()
    .background(ApocalypseTheme.cardBackground)
}
