//
//  ResourcesTabView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//
//  资源模块主入口页面
//  包含POI、背包、已购、领地、交易等分段
//

import SwiftUI

// MARK: - 资源分段类型

/// 资源页面分段选项
enum ResourceSegment: String, CaseIterable {
    case poi = "POI"
    case backpack = "背包"
    case purchased = "已购"
    case territory = "领地"
    case trade = "交易"
}

// MARK: - 资源主页视图

struct ResourcesTabView: View {
    // MARK: 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradeEnabled: Bool = false

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    tradeToggle
                }
            }
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - 交易开关

    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Text("交易")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Toggle("", isOn: $isTradeEnabled)
                .labelsHidden()
                .scaleEffect(0.8)
                .tint(ApocalypseTheme.primary)
        }
    }

    // MARK: - 分段选择器

    private var segmentPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.rawValue)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            POIListView()

        case .backpack:
            BackpackView()

        case .purchased:
            placeholderView(
                icon: "bag.fill",
                title: "已购物品",
                subtitle: "功能开发中..."
            )

        case .territory:
            placeholderView(
                icon: "map.fill",
                title: "领地资源",
                subtitle: "功能开发中..."
            )

        case .trade:
            placeholderView(
                icon: "arrow.triangle.2.circlepath",
                title: "交易市场",
                subtitle: "功能开发中..."
            )
        }
    }

    // MARK: - 占位视图

    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.primary.opacity(0.6))
            }

            // 标题
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textMuted)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
