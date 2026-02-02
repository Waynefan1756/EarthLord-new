//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建造确认页
//  显示建筑预览信息、所需资源列表、位置选择、确认建造按钮
//

import SwiftUI
import CoreLocation

struct BuildingPlacementView: View {

    // MARK: - Properties

    let template: BuildingTemplate
    let territory: Territory
    @ObservedObject var buildingManager: BuildingManager
    let onBuildComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker = false
    @State private var isBuilding = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Computed Properties

    private var resourceCheck: ResourceCheckResult {
        buildingManager.checkResources(for: template)
    }

    private var canBuild: Bool {
        resourceCheck.canBuild && selectedLocation != nil
    }

    /// 格式化建造时间
    private var formattedBuildTime: String {
        let seconds = template.buildTimeSeconds
        if seconds >= 3600 {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return "\(hours)小时\(mins)分"
        } else if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(mins)分\(secs)秒" : "\(mins)分钟"
        } else {
            return "\(seconds)秒"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 建筑预览
                        buildingPreview

                        // 所需资源
                        resourceSection

                        // 位置选择
                        locationSection

                        // 确认建造按钮
                        buildButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("确认建造")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territory: territory,
                    existingBuildings: buildingManager.buildings
                ) { location in
                    selectedLocation = location
                }
            }
            .alert("建造失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    /// 建筑预览
    private var buildingPreview: some View {
        VStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: template.icon)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 名称和等级
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(template.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("T\(template.tier)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(6)
                }

                Text(template.description)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // 建造时间
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("建造时间: \(formattedBuildTime)")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .font(.system(size: 14))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 所需资源
    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("所需资源")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            VStack(spacing: 8) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { itemId in
                    let required = template.requiredResources[itemId] ?? 0
                    let owned = resourceCheck.availableResources[itemId] ?? 0
                    ResourceRow(itemId: itemId, required: required, owned: owned)
                }
            }

            // 资源状态提示
            if !resourceCheck.canBuild {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("资源不足，无法建造")
                }
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.danger)
                .padding(.top, 8)
            }
        }
    }

    /// 位置选择
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造位置")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Button(action: { showLocationPicker = true }) {
                HStack {
                    Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "mappin.circle")
                        .font(.system(size: 20))
                        .foregroundColor(selectedLocation != nil ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedLocation != nil ? "已选择位置" : "点击选择建造位置")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        if let location = selectedLocation {
                            Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(16)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    /// 确认建造按钮
    private var buildButton: some View {
        Button(action: startBuilding) {
            HStack {
                if isBuilding {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "hammer.fill")
                    Text("开始建造")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canBuild ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canBuild || isBuilding)
    }

    // MARK: - Methods

    private func startBuilding() {
        guard let location = selectedLocation else {
            errorMessage = "请选择建造位置"
            showError = true
            return
        }

        isBuilding = true

        Task {
            do {
                try await buildingManager.startConstruction(
                    templateId: template.id,
                    territoryId: territory.id,
                    locationLat: location.latitude,
                    locationLon: location.longitude
                )

                await MainActor.run {
                    isBuilding = false
                    onBuildComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isBuilding = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BuildingPlacementView(
        template: BuildingTemplate(
            id: "campfire",
            name: "篝火",
            category: .survival,
            tier: 1,
            description: "提供基础照明和取暖，可以烹饪食物。",
            icon: "flame.fill",
            requiredResources: ["item_wood": 30],
            buildTimeSeconds: 60,
            maxPerTerritory: 3,
            maxLevel: 5
        ),
        territory: Territory(
            id: "test",
            userId: "user",
            name: "测试领地",
            path: [["lat": 31.230, "lon": 121.470]],
            area: 5000,
            pointCount: 4,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: nil
        ),
        buildingManager: BuildingManager(supabase: supabase)
    ) {
        print("Build complete")
    }
}
