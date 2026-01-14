//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果视图
//  显示从POI获得的物品，带有逐个出现的动画效果
//

import SwiftUI

struct ScavengeResultView: View {

    // MARK: - Properties

    /// POI名称
    let poiName: String

    /// POI类型
    let poiType: POIType

    /// 获得的物品
    let lootItems: [LootItem]

    /// 关闭回调
    let onClose: () -> Void

    /// 动画状态
    @State private var showHeader: Bool = false
    @State private var showItems: Bool = false
    @State private var showButton: Bool = false
    @State private var visibleItemIds: Set<String> = []

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // 头部
            headerSection
                .opacity(showHeader ? 1 : 0)
                .scaleEffect(showHeader ? 1 : 0.8)

            // 物品列表
            itemsSection
                .opacity(showItems ? 1 : 0)
                .offset(y: showItems ? 0 : 20)

            // 确认按钮
            confirmButton
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.9)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.background)
        )
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 12) {
            // 成功图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.success)
            }

            Text("搜刮成功!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            HStack(spacing: 6) {
                Image(systemName: poiType.iconName)
                    .font(.system(size: 14))
                Text(poiName)
                    .font(.system(size: 14))
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    private var itemsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("获得物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(lootItems.count) 件")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            VStack(spacing: 10) {
                ForEach(lootItems) { loot in
                    if let definition = MockExplorationData.getItemDefinition(for: loot.itemId) {
                        itemRow(loot: loot, definition: definition)
                            .opacity(visibleItemIds.contains(loot.id) ? 1 : 0)
                            .offset(x: visibleItemIds.contains(loot.id) ? 0 : -20)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    private func itemRow(loot: LootItem, definition: ItemDefinition) -> some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(rarityColor(definition.rarity).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition.category.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(rarityColor(definition.rarity))
            }

            // 名称和品质
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(definition.rarity.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(rarityColor(definition.rarity))

                    if let quality = loot.quality {
                        Text("·")
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(quality.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }

            Spacer()

            // 数量
            Text("x\(loot.quantity)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }

    private var confirmButton: some View {
        Button(action: onClose) {
            HStack(spacing: 8) {
                Text("太棒了!")
                    .font(.system(size: 18, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.success, ApocalypseTheme.success.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
    }

    // MARK: - Helpers

    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    private func startAnimations() {
        // 头部动画
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showHeader = true
        }

        // 物品列表动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) {
                showItems = true
            }
            // 逐个显示物品
            for (index, loot) in lootItems.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        _ = visibleItemIds.insert(loot.id)
                    }
                }
            }
        }

        // 按钮动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(lootItems.count) * 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showButton = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScavengeResultView(
        poiName: "废弃超市",
        poiType: .supermarket,
        lootItems: MockExplorationData.explorationResult.lootItems,
        onClose: {}
    )
    .preferredColorScheme(.dark)
}
