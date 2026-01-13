//
//  ExplorationResultView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//
//  探索结果弹窗页面
//  显示探索完成后的统计数据和获得的物品奖励
//  包含丰富的入场动画效果
//

import SwiftUI

// MARK: - 探索结果视图

struct ExplorationResultView: View {
    // MARK: 属性

    /// 探索结果数据
    let result: ExplorationResult

    /// 关闭弹窗
    @Environment(\.dismiss) private var dismiss

    // MARK: 动画状态

    /// 头部动画
    @State private var showHeader: Bool = false

    /// 统计卡片动画
    @State private var showStats: Bool = false

    /// 动画数值（从0跳动到目标值）
    @State private var animatedWalkingDistance: Double = 0
    @State private var animatedDiscoveredPOIs: Int = 0
    @State private var animatedLootedPOIs: Int = 0

    /// 奖励卡片动画
    @State private var showRewards: Bool = false

    /// 各个奖励物品的可见状态
    @State private var visibleLootItems: Set<String> = []

    /// 对勾动画状态
    @State private var checkmarkScales: [String: CGFloat] = [:]

    /// 确认按钮动画
    @State private var showButton: Bool = false

    // MARK: Body

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 成就标题
                    achievementHeader
                        .opacity(showHeader ? 1 : 0)
                        .scaleEffect(showHeader ? 1 : 0.8)

                    // 统计数据卡片
                    statsCard
                        .opacity(showStats ? 1 : 0)
                        .offset(y: showStats ? 0 : 30)

                    // 奖励物品卡片
                    rewardsCard
                        .opacity(showRewards ? 1 : 0)
                        .offset(y: showRewards ? 0 : 30)

                    // 确认按钮
                    confirmButton
                        .opacity(showButton ? 1 : 0)
                        .scaleEffect(showButton ? 1 : 0.9)
                }
                .padding(20)
                .padding(.top, 20)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - 动画控制

    /// 启动所有动画
    private func startAnimations() {
        // 1. 头部动画（立即开始）
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showHeader = true
        }

        // 2. 统计卡片动画（0.3秒后）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                showStats = true
            }
            // 启动数值跳动动画
            startNumberAnimations()
        }

        // 3. 奖励卡片动画（0.6秒后）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showRewards = true
            }
            // 启动奖励物品依次出现动画
            startLootItemAnimations()
        }

        // 4. 确认按钮动画（1.2秒后）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showButton = true
            }
        }
    }

    /// 启动数值跳动动画
    private func startNumberAnimations() {
        // 行走距离动画
        withAnimation(.easeOut(duration: 1.0)) {
            animatedWalkingDistance = result.stats.walkingDistance
        }

        // POI 数量动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animateIntValue(from: 0, to: result.stats.discoveredPOIs, duration: 0.8) { value in
                animatedDiscoveredPOIs = value
            }
            animateIntValue(from: 0, to: result.stats.lootedPOIs, duration: 0.8) { value in
                animatedLootedPOIs = value
            }
        }
    }

    /// 整数跳动动画
    private func animateIntValue(from: Int, to: Int, duration: Double, update: @escaping (Int) -> Void) {
        let steps = to - from
        guard steps > 0 else {
            update(to)
            return
        }

        let stepDuration = duration / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                update(from + i)
            }
        }
    }

    /// 启动奖励物品动画
    private func startLootItemAnimations() {
        for (index, loot) in result.lootItems.enumerated() {
            // 每个物品间隔0.2秒出现
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = visibleLootItems.insert(loot.id)
                }

                // 对勾弹跳动画（物品出现0.15秒后）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        checkmarkScales[loot.id] = 1.0
                    }
                }
            }
        }
    }

    // MARK: - 成就标题

    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 光晕效果背景
            ZStack {
                // 外层光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 内圈
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 标题文字
            Text("探索完成！")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text("你的探索之旅收获满满")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.bottom, 10)
    }

    // MARK: - 统计数据卡片

    private var statsCard: some View {
        VStack(spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索统计")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 分隔线
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 行走距离（使用动画数值）
            animatedStatRow(
                icon: "figure.walk",
                iconColor: ApocalypseTheme.success,
                title: "行走距离",
                currentValue: animatedWalkingDistance,
                totalValue: result.stats.totalWalkingDistance,
                rank: result.stats.walkingDistanceRank,
                formatter: formatDistance
            )

            // 探索时长
            statRowSimple(
                icon: "clock.fill",
                iconColor: ApocalypseTheme.warning,
                title: "探索时长",
                value: result.stats.formattedDuration
            )

            // 发现/搜刮 POI（使用动画数值）
            HStack(spacing: 20) {
                animatedMiniStatBox(
                    title: "发现 POI",
                    value: animatedDiscoveredPOIs,
                    color: ApocalypseTheme.info
                )

                animatedMiniStatBox(
                    title: "搜刮 POI",
                    value: animatedLootedPOIs,
                    color: ApocalypseTheme.success
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 动画统计行
    private func animatedStatRow(icon: String, iconColor: Color, title: String,
                                  currentValue: Double, totalValue: Double, rank: Int,
                                  formatter: (Double) -> String) -> some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 排名
                Text("#\(rank)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.success)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本次")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(formatter(currentValue))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("累计")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(formatter(totalValue))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }

    /// 简单统计行
    private func statRowSimple(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }

    /// 动画迷你统计盒子
    private func animatedMiniStatBox(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
                .contentTransition(.numericText())

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
    }

    // MARK: - 奖励物品卡片

    private var rewardsCard: some View {
        VStack(spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(result.lootItems.count) 件")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 分隔线
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物品列表（带动画）
            VStack(spacing: 10) {
                ForEach(result.lootItems) { loot in
                    if let definition = ItemDefinitions.get(loot.itemId) {
                        animatedRewardItemRow(loot: loot, definition: definition)
                    }
                }
            }

            // 底部提示
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.success)

                Text("已添加到背包")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.success)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 带动画的奖励物品行
    private func animatedRewardItemRow(loot: LootItem, definition: ItemDefinition) -> some View {
        let isVisible = visibleLootItems.contains(loot.id)
        let checkmarkScale = checkmarkScales[loot.id] ?? 0

        return HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor(for: definition.category).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition.category.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor(for: definition.category))
            }

            // 物品名称
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let quality = loot.quality {
                    Text(quality.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 数量
            Text("x\(loot.quantity)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)

            // 对勾（带弹跳动画）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.background)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -30)
    }

    /// 分类颜色
    private func categoryColor(for category: ItemCategory) -> Color {
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

    // MARK: - 确认按钮

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text("太棒了！")
                    .font(.system(size: 18, weight: .bold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .padding(.top, 10)
    }

    // MARK: - 辅助方法

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.explorationResult)
}

#Preview("Sheet 模式") {
    Text("主页面")
        .sheet(isPresented: .constant(true)) {
            ExplorationResultView(result: MockExplorationData.explorationResult)
        }
}
