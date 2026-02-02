//
//  BuildingBrowserView.swift
//  EarthLord
//
//  建筑浏览器
//  显示分类筛选栏和建筑卡片列表
//

import SwiftUI

struct BuildingBrowserView: View {

    // MARK: - Properties

    let territoryId: String
    @ObservedObject var buildingManager: BuildingManager
    let onSelectTemplate: (BuildingTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedCategory: BuildingCategory?
    @State private var isLoading = true

    // MARK: - Computed Properties

    /// 筛选后的模板列表
    private var filteredTemplates: [BuildingTemplate] {
        let allTemplates = Array(buildingManager.templates.values)
        if let category = selectedCategory {
            return allTemplates.filter { $0.category == category }
        }
        return allTemplates.sorted { $0.tier < $1.tier }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分类筛选栏
                    CategorySelector(selectedCategory: $selectedCategory)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    // 建筑列表
                    if isLoading {
                        Spacer()
                        ProgressView("加载中...")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                    } else if filteredTemplates.isEmpty {
                        Spacer()
                        emptyStateView
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTemplates, id: \.id) { template in
                                    let resourceCheck = buildingManager.checkResources(for: template)
                                    let existingCount = buildingManager.getBuildingCount(templateId: template.id, territoryId: territoryId)

                                    BuildingCard(
                                        template: template,
                                        resourceCheck: resourceCheck,
                                        existingCount: existingCount
                                    ) {
                                        onSelectTemplate(template)
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("建筑列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2")
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无可用建筑")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Methods

    private func loadData() {
        Task {
            if buildingManager.templates.isEmpty {
                try? await buildingManager.loadTemplates()
            }
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    BuildingBrowserView(
        territoryId: "test",
        buildingManager: BuildingManager(supabase: supabase)
    ) { template in
        print("Selected: \(template.name)")
    }
}
