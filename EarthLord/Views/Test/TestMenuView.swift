//
//  TestMenuView.swift
//  EarthLord
//
//  开发测试菜单：集中管理各种测试功能的入口
//

import SwiftUI

struct TestMenuView: View {

    // MARK: - Body

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supabase 连接测试")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试数据库连接和认证功能")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // 圈地功能测试
            NavigationLink(destination: TerritoryTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("圈地功能测试")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("查看路径追踪、闭环检测和速度验证日志")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("开发测试")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
