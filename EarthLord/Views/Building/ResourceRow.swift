//
//  ResourceRow.swift
//  EarthLord
//
//  资源显示行组件
//  显示资源图标、名称、拥有/需要数量（不足显示红色）
//

import SwiftUI

struct ResourceRow: View {

    // MARK: - Properties

    let itemId: String
    let required: Int
    let owned: Int

    // MARK: - Computed Properties

    /// 是否资源充足
    private var hasEnough: Bool {
        owned >= required
    }

    /// 物品定义
    private var itemDefinition: ItemDefinition? {
        ItemDefinitions.get(itemId)
    }

    /// 物品名称
    private var itemName: String {
        itemDefinition?.name ?? itemId
    }

    /// 物品图标
    private var itemIcon: String {
        switch itemDefinition?.category {
        case .water:
            return "drop.fill"
        case .food:
            return "fork.knife"
        case .medical:
            return "cross.case.fill"
        case .material:
            return "cube.fill"
        case .tool:
            return "wrench.fill"
        case .weapon:
            return "shield.fill"
        case .misc:
            return "ellipsis.circle.fill"
        case .none:
            return "questionmark.circle"
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: itemIcon)
                .font(.system(size: 16))
                .foregroundColor(hasEnough ? ApocalypseTheme.primary : ApocalypseTheme.danger)
                .frame(width: 24)

            // 名称
            Text(itemName)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量
            HStack(spacing: 4) {
                Text("\(owned)")
                    .foregroundColor(hasEnough ? ApocalypseTheme.success : ApocalypseTheme.danger)
                Text("/")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("\(required)")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .font(.system(size: 14, weight: .medium))

            // 状态图标
            Image(systemName: hasEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(hasEnough ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ResourceRow(itemId: "item_wood", required: 30, owned: 50)
        ResourceRow(itemId: "item_scrap_metal", required: 20, owned: 10)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
