//
//  POIDetailView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//
//  POI 详情页面
//  显示兴趣点的详细信息和操作按钮
//

import SwiftUI

// MARK: - POI 详情视图

struct POIDetailView: View {
    // MARK: 属性

    /// 当前显示的 POI
    let poi: POI

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult: Bool = false

    /// POI 状态（用于本地修改展示）
    @State private var localDiscoveryStatus: POIDiscoveryStatus
    @State private var localLootStatus: POILootStatus

    /// 假数据：距离
    private let mockDistance: Double = 350

    /// 初始化
    init(poi: POI) {
        self.poi = poi
        _localDiscoveryStatus = State(initialValue: poi.discoveryStatus)
        _localLootStatus = State(initialValue: poi.lootStatus)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 信息区域
                    infoSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // 操作按钮区域
                    actionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            // 使用独立的 ExplorationResultView，传递假探索结果数据
            ExplorationResultView(result: MockExplorationData.explorationResult)
        }
    }

    // MARK: - 顶部大图区域

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    poi.type.themeColor,
                    poi.type.themeColor.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)

            // 大图标
            VStack {
                Spacer()

                Image(systemName: poi.type.iconName)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()
            }
            .frame(height: 280)

            // 底部遮罩和文字
            VStack(alignment: .leading, spacing: 6) {
                Text(poi.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Image(systemName: poi.type.iconName)
                        .font(.system(size: 14))

                    Text(poi.type.displayName)
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - 信息区域

    private var infoSection: some View {
        VStack(spacing: 12) {
            // 距离
            InfoRowView(
                icon: "location.fill",
                iconColor: ApocalypseTheme.info,
                title: "距离",
                value: String(format: "%.0f 米", mockDistance)
            )

            // 物资状态
            InfoRowView(
                icon: lootStatusIcon,
                iconColor: lootStatusColor,
                title: "物资状态",
                value: lootStatusText,
                valueColor: lootStatusColor
            )

            // 危险等级
            InfoRowView(
                icon: "exclamationmark.shield.fill",
                iconColor: dangerLevelColor,
                title: "危险等级",
                value: dangerLevelText,
                valueColor: dangerLevelColor
            )

            // 来源
            InfoRowView(
                icon: "map.fill",
                iconColor: ApocalypseTheme.textSecondary,
                title: "来源",
                value: "地图数据"
            )

            // 描述（如有）
            if let description = poi.description {
                descriptionCard(description)
            }
        }
    }

    /// 描述卡片
    private func descriptionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("描述")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: 物资状态相关

    private var lootStatusIcon: String {
        switch localLootStatus {
        case .hasLoot: return "shippingbox.fill"
        case .looted: return "shippingbox"
        case .noLoot: return "xmark.circle.fill"
        }
    }

    private var lootStatusText: String {
        switch localLootStatus {
        case .hasLoot: return "有物资"
        case .looted: return "已清空"
        case .noLoot: return "无物资"
        }
    }

    private var lootStatusColor: Color {
        switch localLootStatus {
        case .hasLoot: return ApocalypseTheme.success
        case .looted: return ApocalypseTheme.textMuted
        case .noLoot: return ApocalypseTheme.textMuted
        }
    }

    // MARK: 危险等级相关

    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1: return "安全"
        case 2: return "低危"
        case 3: return "中危"
        case 4: return "高危"
        case 5: return "极危"
        default: return "未知"
        }
    }

    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1: return ApocalypseTheme.success      // 安全：绿色
        case 2: return ApocalypseTheme.info         // 低危：蓝色
        case 3: return ApocalypseTheme.warning      // 中危：黄色
        case 4: return ApocalypseTheme.primary      // 高危：橙色
        case 5: return ApocalypseTheme.danger       // 极危：红色
        default: return ApocalypseTheme.textMuted
        }
    }

    // MARK: - 操作按钮区域

    private var actionSection: some View {
        VStack(spacing: 16) {
            // 主按钮：搜寻此POI
            searchButton

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                markDiscoveredButton

                // 标记无物资
                markNoLootButton
            }
        }
    }

    /// 搜寻按钮
    private var searchButton: some View {
        Button {
            showExplorationResult = true
            print("开始搜寻POI: \(poi.name)")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))

                Text("搜寻此POI")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if localLootStatus == .looted || localLootStatus == .noLoot {
                        // 已清空或无物资：灰色背景
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ApocalypseTheme.textMuted)
                    } else {
                        // 有物资：橙色渐变背景
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
                    }
                }
            )
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(localLootStatus == .looted || localLootStatus == .noLoot)
    }

    /// 标记已发现按钮
    private var markDiscoveredButton: some View {
        Button {
            withAnimation {
                localDiscoveryStatus = .discovered
            }
            print("标记已发现: \(poi.name)")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: localDiscoveryStatus == .discovered ? "eye.fill" : "eye")
                    .font(.system(size: 14))

                Text("标记已发现")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(localDiscoveryStatus == .discovered ? .white : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(localDiscoveryStatus == .discovered
                          ? ApocalypseTheme.success
                          : ApocalypseTheme.cardBackground)
            )
        }
    }

    /// 标记无物资按钮
    private var markNoLootButton: some View {
        Button {
            withAnimation {
                localLootStatus = .looted
            }
            print("标记无物资: \(poi.name)")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: localLootStatus == .looted ? "xmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 14))

                Text("标记无物资")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(localLootStatus == .looted ? .white : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(localLootStatus == .looted
                          ? ApocalypseTheme.danger
                          : ApocalypseTheme.cardBackground)
            )
        }
    }
}

// MARK: - 信息行视图

struct InfoRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var valueColor: Color = ApocalypseTheme.textPrimary

    var body: some View {
        HStack {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            // 标题
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 值
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
}

// MARK: - Preview

#Preview("有物资POI") {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.pois[0])
    }
}

#Preview("已清空POI") {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.pois[1])
    }
}
