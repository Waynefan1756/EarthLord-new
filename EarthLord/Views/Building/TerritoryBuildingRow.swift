//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件
//  显示建筑状态、进度条、倒计时、操作菜单（升级/拆除）
//

import SwiftUI
import Combine

struct TerritoryBuildingRow: View {

    // MARK: - Properties

    let building: PlayerBuilding
    let onUpgrade: () -> Void
    let onDemolish: () -> Void

    // MARK: - State

    @State private var currentProgress: Double = 0
    @State private var remainingTime: String = ""

    // Timer for updating progress
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：图标、名称、等级、菜单
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: building.template.icon)
                        .font(.system(size: 18))
                        .foregroundColor(statusColor)
                }

                // 名称和等级
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(building.template.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("Lv.\(building.level)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(4)
                    }

                    // 状态
                    statusLabel
                }

                Spacer()

                // 操作菜单
                if building.status == .active {
                    Menu {
                        if building.canUpgrade {
                            Button(action: onUpgrade) {
                                Label("升级", systemImage: "arrow.up.circle")
                            }
                        }
                        Button(role: .destructive, action: onDemolish) {
                            Label("拆除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 22))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            // 建造进度条（仅建造中显示）
            if building.status == .constructing {
                VStack(alignment: .leading, spacing: 6) {
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ApocalypseTheme.background)
                                .frame(height: 8)

                            // 进度
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ApocalypseTheme.primary)
                                .frame(width: geometry.size.width * currentProgress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    // 剩余时间
                    HStack {
                        Text("剩余时间")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Spacer()

                        Text(remainingTime)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .onAppear {
            updateProgress()
        }
        .onReceive(timer) { _ in
            if building.status == .constructing {
                updateProgress()
            }
        }
    }

    // MARK: - Subviews

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(building.status.displayName)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch building.status {
        case .constructing:
            return ApocalypseTheme.warning
        case .active:
            return ApocalypseTheme.success
        }
    }

    // MARK: - Methods

    private func updateProgress() {
        currentProgress = building.buildProgress
        remainingTime = building.formattedRemainingTime
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: "1",
                template: BuildingTemplate(
                    id: "campfire",
                    name: "篝火",
                    category: .survival,
                    tier: 1,
                    description: "提供基础照明和取暖",
                    icon: "flame.fill",
                    requiredResources: [:],
                    buildTimeSeconds: 60,
                    maxPerTerritory: 3,
                    maxLevel: 5
                ),
                territoryId: "t1",
                status: .active,
                level: 2,
                locationLat: nil,
                locationLon: nil,
                buildStartedAt: Date(),
                buildCompletedAt: Date()
            ),
            onUpgrade: {},
            onDemolish: {}
        )

        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: "2",
                template: BuildingTemplate(
                    id: "storage",
                    name: "储物箱",
                    category: .storage,
                    tier: 1,
                    description: "增加存储容量",
                    icon: "archivebox.fill",
                    requiredResources: [:],
                    buildTimeSeconds: 300,
                    maxPerTerritory: 5,
                    maxLevel: 3
                ),
                territoryId: "t1",
                status: .constructing,
                level: 1,
                locationLat: nil,
                locationLon: nil,
                buildStartedAt: Date().addingTimeInterval(-180),
                buildCompletedAt: nil
            ),
            onUpgrade: {},
            onDemolish: {}
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
