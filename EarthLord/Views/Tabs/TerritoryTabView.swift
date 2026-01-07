//
//  TerritoryTabView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/1.
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - Properties

    /// 领地管理器
    private let territoryManager = TerritoryManager(supabase: supabase)

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 选中的领地（用于详情页）
    @State private var selectedTerritory: Territory?

    // MARK: - Computed Properties

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("加载中...")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else if myTerritories.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 统计信息卡片
                            statsCard

                            // 领地列表
                            VStack(spacing: 12) {
                                ForEach(myTerritories) { territory in
                                    TerritoryCardView(territory: territory)
                                        .onTapGesture {
                                            selectedTerritory = territory
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        await loadMyTerritories()
                    }
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await loadMyTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    territoryManager: territoryManager,
                    onDelete: {
                        // 删除成功后刷新列表
                        Task {
                            await loadMyTerritories()
                        }
                    }
                )
            }
        }
    }

    // MARK: - Subviews

    /// 统计信息卡片
    private var statsCard: some View {
        HStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("\(myTerritories.count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("领地数量")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            VStack(spacing: 8) {
                Text(formattedTotalArea)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("总面积")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有领地")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面开始圈地吧")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Methods

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            print("❌ 加载领地失败：\(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - Territory Card View

struct TerritoryCardView: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                Text(territory.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 12) {
                    Label(territory.formattedArea, systemImage: "map")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let pointCount = territory.pointCount {
                        Label("\(pointCount) 个点", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    TerritoryTabView()
}
