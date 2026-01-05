//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/1.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 标题
                    Text("更多功能")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.top, 40)

                    // 功能列表
                    VStack(spacing: 16) {
                        // 开发测试入口
                        NavigationLink(destination: TestMenuView()) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("开发测试")
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text("数据库连接和圈地功能测试")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MoreTabView()
}
