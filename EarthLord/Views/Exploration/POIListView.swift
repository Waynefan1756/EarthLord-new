//
//  POIListView.swift
//  EarthLord
//
//  Created by Claude on 2026/1/9.
//
//  附近兴趣点列表页面
//  显示GPS坐标、搜索按钮、分类筛选和POI列表
//

import SwiftUI

// MARK: - POI 类型颜色扩展

extension POIType {
    /// 每种POI类型对应的主题颜色
    var themeColor: Color {
        switch self {
        case .hospital:
            return Color.red                    // 医院：红色
        case .supermarket:
            return Color.green                  // 超市：绿色
        case .factory:
            return Color.gray                   // 工厂：灰色
        case .pharmacy:
            return Color.purple                 // 药店：紫色
        case .gasStation:
            return Color.orange                 // 加油站：橙色
        case .warehouse:
            return Color.brown                  // 仓库：棕色
        case .residential:
            return Color.blue                   // 住宅区：蓝色
        }
    }
}

// MARK: - 筛选类型

/// 筛选选项枚举
enum POIFilterType: String, CaseIterable {
    case all = "全部"
    case hospital = "医院"
    case supermarket = "超市"
    case factory = "工厂"
    case pharmacy = "药店"
    case gasStation = "加油站"

    /// 对应的 POIType（全部返回 nil）
    var poiType: POIType? {
        switch self {
        case .all: return nil
        case .hospital: return .hospital
        case .supermarket: return .supermarket
        case .factory: return .factory
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        }
    }
}

// MARK: - POI 列表视图

struct POIListView: View {
    // MARK: 状态

    /// 当前选中的筛选类型
    @State private var selectedFilter: POIFilterType = .all

    /// 是否正在搜索
    @State private var isSearching: Bool = false

    /// 搜索按钮是否被按下（用于缩放动画）
    @State private var isSearchButtonPressed: Bool = false

    /// 列表项是否已显示（用于淡入动画）
    @State private var visibleItems: Set<String> = []

    /// 假 GPS 坐标
    private let mockLatitude: Double = 22.5431
    private let mockLongitude: Double = 114.0579

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if selectedFilter == .all {
            return MockExplorationData.pois
        } else if let type = selectedFilter.poiType {
            return MockExplorationData.pois.filter { $0.type == type }
        }
        return MockExplorationData.pois
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        MockExplorationData.pois.filter { $0.discoveryStatus == .discovered }.count
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 筛选工具栏
                filterToolbar

                // POI 列表
                poiList
            }
        }
        // 注意：POIListView 嵌套在 ResourcesTabView 的 NavigationStack 中
        // 不需要单独设置 navigationTitle，由父视图统一管理
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.success)

                Text(String(format: "%.4f, %.4f", mockLatitude, mockLongitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            Text("附近发现 \(discoveredCount) 个地点")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索按钮

    private var searchButton: some View {
        Button {
            performSearch()
        } label: {
            HStack(spacing: 10) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            )
        }
        .scaleEffect(isSearchButtonPressed ? 0.96 : 1.0)  // 按下时缩放
        .animation(.easeInOut(duration: 0.1), value: isSearchButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isSearchButtonPressed = true }
                .onEnded { _ in isSearchButtonPressed = false }
        )
        .disabled(isSearching)
    }

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearching = true
        }

        // 1.5秒后恢复正常，并触发列表淡入动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearching = false
            }
            // 重置可见项，触发淡入动画
            visibleItems.removeAll()
            triggerListAnimation()
        }
    }

    /// 触发列表淡入动画
    private func triggerListAnimation() {
        for (index, poi) in filteredPOIs.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = visibleItems.insert(poi.id)
                }
            }
        }
    }

    // MARK: - 筛选工具栏

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(POIFilterType.allCases, id: \.self) { filter in
                    filterButton(for: filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    /// 单个筛选按钮
    private func filterButton(for filter: POIFilterType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .regular))
                .foregroundColor(selectedFilter == filter ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedFilter == filter ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                )
        }
    }

    // MARK: - POI 列表

    private var poiList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredPOIs) { poi in
                    poiRow(poi: poi, index: filteredPOIs.firstIndex(where: { $0.id == poi.id }) ?? 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    /// 单个 POI 行（带动画）
    private func poiRow(poi: POI, index: Int) -> some View {
        NavigationLink(destination: POIDetailView(poi: poi)) {
            POICardView(poi: poi)
        }
        .buttonStyle(PlainButtonStyle())  // 移除默认按钮样式
        .opacity(visibleItems.contains(poi.id) ? 1 : 0)  // 淡入效果
        .offset(y: visibleItems.contains(poi.id) ? 0 : 20)  // 从下方滑入
        .onAppear {
            // 首次出现时触发动画
            if !visibleItems.contains(poi.id) {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        _ = visibleItems.insert(poi.id)
                    }
                }
            }
        }
    }
}

// MARK: - POI 卡片视图

struct POICardView: View {
    let poi: POI

    var body: some View {
        HStack(spacing: 14) {
            // 类型图标
            iconView

            // 信息区域
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型文字
                Text(poi.type.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(poi.type.themeColor)
            }

            Spacer()

            // 状态标签区域
            VStack(alignment: .trailing, spacing: 6) {
                // 发现状态
                discoveryStatusBadge

                // 物资状态
                lootStatusBadge
            }

            // 右箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(poi.type.themeColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: 类型图标

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(poi.type.themeColor.opacity(0.2))
                .frame(width: 48, height: 48)

            Image(systemName: poi.type.iconName)
                .font(.system(size: 20))
                .foregroundColor(poi.type.themeColor)
        }
    }

    // MARK: 发现状态标签

    private var discoveryStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: poi.discoveryStatus == .discovered ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 10))

            Text(poi.discoveryStatus == .discovered ? "已发现" : "未发现")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(poi.discoveryStatus == .discovered ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(poi.discoveryStatus == .discovered
                      ? ApocalypseTheme.success.opacity(0.15)
                      : ApocalypseTheme.textMuted.opacity(0.15))
        )
    }

    // MARK: 物资状态标签

    private var lootStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: lootStatusIcon)
                .font(.system(size: 10))

            Text(lootStatusText)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(lootStatusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(lootStatusColor.opacity(0.15))
        )
    }

    private var lootStatusIcon: String {
        switch poi.lootStatus {
        case .hasLoot: return "shippingbox.fill"
        case .looted: return "shippingbox"
        case .noLoot: return "xmark"
        }
    }

    private var lootStatusText: String {
        switch poi.lootStatus {
        case .hasLoot: return "有物资"
        case .looted: return "已搜空"
        case .noLoot: return "无物资"
        }
    }

    private var lootStatusColor: Color {
        switch poi.lootStatus {
        case .hasLoot: return ApocalypseTheme.warning
        case .looted: return ApocalypseTheme.textMuted
        case .noLoot: return ApocalypseTheme.textMuted
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        POIListView()
    }
}
