//
//  AIScavengeResultView.swift
//  EarthLord
//
//  AI 生成物品搜刮结果视图
//  显示从 POI 获得的 AI 生成物品，包含物品故事展示
//

import SwiftUI

struct AIScavengeResultView: View {

    // MARK: - Properties

    /// POI 名称
    let poiName: String

    /// POI 类型
    let poiType: POIType

    /// 危险等级
    let dangerLevel: Int

    /// AI 生成的物品
    let items: [AIGeneratedItem]

    /// 关闭回调
    let onClose: () -> Void

    // MARK: - State

    @State private var showHeader: Bool = false
    @State private var showItems: Bool = false
    @State private var showButton: Bool = false
    @State private var visibleItemIds: Set<String> = []
    @State private var expandedStoryIds: Set<String> = []

    // MARK: - Body

    var body: some View {
        ScrollView {
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
        }
        .background(ApocalypseTheme.background)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Header Section

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

            // POI 信息和危险等级
            HStack(spacing: 8) {
                Image(systemName: poiType.iconName)
                    .font(.system(size: 14))
                Text(poiName)
                    .font(.system(size: 14))

                // 危险等级指示器
                HStack(spacing: 2) {
                    ForEach(0..<dangerLevel, id: \.self) { _ in
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(dangerLevelColor)
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("获得物品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(items.count) 件")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            VStack(spacing: 12) {
                ForEach(items) { item in
                    aiItemRow(item: item)
                        .opacity(visibleItemIds.contains(item.id) ? 1 : 0)
                        .offset(x: visibleItemIds.contains(item.id) ? 0 : -20)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - Item Row

    private func aiItemRow(item: AIGeneratedItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(rarityColor(item.itemRarity).opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.itemCategory.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(rarityColor(item.itemRarity))
                }

                // 名称和稀有度
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    HStack(spacing: 4) {
                        Text(item.itemRarity.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(rarityColor(item.itemRarity))

                        Text("·")
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(item.itemCategory.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Spacer()

                // 数量
                Text("x\(item.quantity)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 故事区域（可展开/收起）
            storySection(for: item)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }

    // MARK: - Story Section

    private func storySection(for item: AIGeneratedItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedStoryIds.contains(item.id) {
                        expandedStoryIds.remove(item.id)
                    } else {
                        expandedStoryIds.insert(item.id)
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: expandedStoryIds.contains(item.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                    Text("物品故事")
                        .font(.system(size: 12))
                }
                .foregroundColor(ApocalypseTheme.textMuted)
            }

            if expandedStoryIds.contains(item.id) {
                Text(item.story)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Confirm Button

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

    private var dangerLevelColor: Color {
        switch dangerLevel {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
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
            for (index, item) in items.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        _ = visibleItemIds.insert(item.id)
                    }
                }
            }
        }

        // 按钮动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(items.count) * 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showButton = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIScavengeResultView(
        poiName: "协和医院急诊室",
        poiType: .hospital,
        dangerLevel: 4,
        items: [
            AIGeneratedItem(
                id: UUID().uuidString,
                name: "「最后的希望」应急包",
                category: "medical",
                rarity: "epic",
                story: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它...",
                quantity: 1
            ),
            AIGeneratedItem(
                id: UUID().uuidString,
                name: "护士站的咖啡罐头",
                category: "food",
                rarity: "rare",
                story: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。",
                quantity: 1
            ),
            AIGeneratedItem(
                id: UUID().uuidString,
                name: "急诊科常备止痛片",
                category: "medical",
                rarity: "uncommon",
                story: "瓶身上还贴着患者的名字和床号，这位患者大概永远不会来取了。",
                quantity: 2
            )
        ],
        onClose: {}
    )
    .preferredColorScheme(.dark)
}
