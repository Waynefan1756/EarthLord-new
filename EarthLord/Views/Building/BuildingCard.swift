//
//  BuildingCard.swift
//  EarthLord
//
//  建筑卡片组件
//  显示建筑图标、名称、建造时间、资源状态
//

import SwiftUI

struct BuildingCard: View {

    // MARK: - Properties

    let template: BuildingTemplate
    let resourceCheck: ResourceCheckResult
    let existingCount: Int
    let onTap: () -> Void

    // MARK: - Computed Properties

    /// 是否已达数量上限
    private var isMaxReached: Bool {
        existingCount >= template.maxPerTerritory
    }

    /// 是否可以建造
    private var canBuild: Bool {
        resourceCheck.canBuild && !isMaxReached
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：图标和名称
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(canBuild ? ApocalypseTheme.primary.opacity(0.2) : ApocalypseTheme.textMuted.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: template.icon)
                            .font(.system(size: 20))
                            .foregroundColor(canBuild ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // 名称和等级
                        HStack(spacing: 6) {
                            Text(template.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(canBuild ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)

                            Text("T\(template.tier)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tierColor)
                                .cornerRadius(4)
                        }

                        // 分类
                        Text(template.category.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    Spacer()

                    // 数量限制
                    if isMaxReached {
                        Text("已满")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.danger)
                            .cornerRadius(4)
                    } else {
                        Text("\(existingCount)/\(template.maxPerTerritory)")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 描述
                Text(template.description)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(2)

                // 底部信息
                HStack {
                    // 建造时间
                    Label(formattedBuildTime, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 资源状态
                    if resourceCheck.canBuild {
                        Label("资源充足", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.success)
                    } else {
                        Label("资源不足", systemImage: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ApocalypseTheme.danger)
                    }
                }
            }
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(canBuild ? ApocalypseTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canBuild)
    }

    // MARK: - Helper

    private var tierColor: Color {
        switch template.tier {
        case 1:
            return ApocalypseTheme.success
        case 2:
            return ApocalypseTheme.info
        case 3:
            return ApocalypseTheme.primary
        default:
            return ApocalypseTheme.textMuted
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        BuildingCard(
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
            resourceCheck: ResourceCheckResult(canBuild: true, missingResources: [:], availableResources: ["item_wood": 50]),
            existingCount: 1
        ) {
            print("Tapped")
        }

        BuildingCard(
            template: BuildingTemplate(
                id: "storage",
                name: "储物箱",
                category: .storage,
                tier: 1,
                description: "增加领地存储容量。",
                icon: "archivebox.fill",
                requiredResources: ["item_wood": 50, "item_scrap_metal": 20],
                buildTimeSeconds: 120,
                maxPerTerritory: 5,
                maxLevel: 3
            ),
            resourceCheck: ResourceCheckResult(canBuild: false, missingResources: ["item_scrap_metal": 10], availableResources: ["item_wood": 50, "item_scrap_metal": 10]),
            existingCount: 5
        ) {
            print("Tapped")
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
