//
//  BuildingDetailView.swift
//  EarthLord
//
//  建筑详情页
//  显示建筑状态、等级、升级/拆除按钮
//

import SwiftUI
import Combine

struct BuildingDetailView: View {

    // MARK: - Properties

    let building: PlayerBuilding
    @ObservedObject var buildingManager: BuildingManager
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var isUpgrading = false
    @State private var isDemolishing = false
    @State private var showDemolishAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var currentProgress: Double = 0
    @State private var remainingTime: String = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 建筑信息
                        buildingInfo

                        // 状态和进度
                        statusSection

                        // 操作按钮
                        if building.status == .active {
                            actionButtons
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(building.template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("确认拆除", isPresented: $showDemolishAlert) {
                Button("取消", role: .cancel) {}
                Button("拆除", role: .destructive) {
                    demolishBuilding()
                }
            } message: {
                Text("确定要拆除 \(building.template.name) 吗？此操作无法撤销。")
            }
            .alert("操作失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                updateProgress()
            }
            .onReceive(timer) { _ in
                if building.status == .constructing {
                    updateProgress()
                }
            }
        }
    }

    // MARK: - Subviews

    /// 建筑信息
    private var buildingInfo: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: building.template.icon)
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }

            // 名称和等级
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(building.template.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("Lv.\(building.level)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(8)
                }

                Text(building.template.description)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)

                // 分类标签
                HStack(spacing: 6) {
                    Image(systemName: building.template.category.iconName)
                    Text(building.template.category.displayName)
                }
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 状态和进度
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("建筑状态")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 12) {
                // 状态行
                HStack {
                    Text("当前状态")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(building.status.displayName)
                            .foregroundColor(statusColor)
                    }
                }
                .font(.system(size: 14))

                if building.status == .constructing {
                    Divider()

                    // 进度条
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("建造进度")
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            Spacer()
                            Text("\(Int(currentProgress * 100))%")
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        .font(.system(size: 14))

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ApocalypseTheme.background)
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ApocalypseTheme.primary)
                                    .frame(width: geometry.size.width * currentProgress, height: 8)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("剩余时间")
                                .foregroundColor(ApocalypseTheme.textSecondary)
                            Spacer()
                            Text(remainingTime)
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        .font(.system(size: 14))
                    }
                }

                if building.status == .active {
                    Divider()

                    // 等级信息
                    HStack {
                        Text("最大等级")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                        Text("Lv.\(building.template.maxLevel)")
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .font(.system(size: 14))
                }
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    /// 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 升级按钮
            if building.canUpgrade {
                Button(action: upgradeBuilding) {
                    HStack {
                        if isUpgrading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("升级到 Lv.\(building.level + 1)")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(isUpgrading)
            }

            // 拆除按钮
            Button(action: { showDemolishAlert = true }) {
                HStack {
                    if isDemolishing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "trash.fill")
                        Text("拆除建筑")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ApocalypseTheme.danger)
                .cornerRadius(12)
            }
            .disabled(isDemolishing)
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

    private func upgradeBuilding() {
        isUpgrading = true

        Task {
            do {
                try await buildingManager.upgradeBuilding(buildingId: building.id)
                await MainActor.run {
                    isUpgrading = false
                    onDismiss()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpgrading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func demolishBuilding() {
        isDemolishing = true

        Task {
            do {
                try await buildingManager.demolishBuilding(buildingId: building.id)
                await MainActor.run {
                    isDemolishing = false
                    onDismiss()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDemolishing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BuildingDetailView(
        building: PlayerBuilding(
            id: "1",
            template: BuildingTemplate(
                id: "campfire",
                name: "篝火",
                category: .survival,
                tier: 1,
                description: "提供基础照明和取暖，可以烹饪食物。",
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
        buildingManager: BuildingManager(supabase: supabase)
    ) {
        print("Dismissed")
    }
}
