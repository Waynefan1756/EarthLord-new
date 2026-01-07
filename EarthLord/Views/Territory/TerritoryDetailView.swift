//
//  TerritoryDetailView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/7.
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - Properties

    let territory: Territory
    let territoryManager: TerritoryManager
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    // MARK: - Computed Properties

    /// 地图区域
    private var mapRegion: MKCoordinateRegion {
        let coordinates = territory.toCoordinates()
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview

                    // 领地信息
                    territoryInfo

                    // 功能区
                    functionalSection

                    // 删除按钮
                    deleteButton
                }
                .padding(.vertical, 20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritoryAction()
                    }
                }
            } message: {
                Text("确定要删除这个领地吗？此操作无法撤销。")
            }
        }
    }

    // MARK: - Subviews

    /// 地图预览
    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("地图预览")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 20)

            Map(coordinateRegion: .constant(mapRegion))
                .frame(height: 250)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .disabled(true)
        }
    }

    /// 领地信息
    private var territoryInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("领地信息")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                InfoRow(icon: "map", label: "面积", value: territory.formattedArea)
                Divider().padding(.leading, 60)
                InfoRow(icon: "point.3.connected.trianglepath.dotted", label: "路径点数", value: "\(territory.pointCount ?? 0) 个")
                Divider().padding(.leading, 60)
                InfoRow(icon: "calendar", label: "创建时间", value: formatDate(territory.createdAt))
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    /// 功能区（占位）
    private var functionalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("管理功能")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                PlaceholderFeatureButton(icon: "pencil", title: "重命名领地", subtitle: "敬请期待")
                PlaceholderFeatureButton(icon: "building.2", title: "建筑系统", subtitle: "敬请期待")
                PlaceholderFeatureButton(icon: "arrow.left.arrow.right", title: "领地交易", subtitle: "敬请期待")
            }
            .padding(.horizontal, 20)
        }
    }

    /// 删除按钮
    private var deleteButton: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "trash")
                    Text("删除领地")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Methods

    /// 格式化日期
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "未知" }

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "未知" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }

    /// 删除领地操作
    private func deleteTerritoryAction() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        if success {
            onDelete?()
            dismiss()
        }

        isDeleting = false
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Placeholder Feature Button

struct PlaceholderFeatureButton: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "test-user",
            name: "测试领地",
            path: [["lat": 31.23, "lon": 121.47]],
            area: 5000,
            pointCount: 50,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2026-01-07T10:00:00Z"
        ),
        territoryManager: TerritoryManager(supabase: supabase),
        onDelete: nil
    )
}
