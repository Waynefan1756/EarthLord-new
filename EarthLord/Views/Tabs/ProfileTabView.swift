//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/1.
//

import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        VStack(spacing: 16) {
                            // 头像
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                ApocalypseTheme.primary,
                                                ApocalypseTheme.primaryDark
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 20)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 40)

                            // 用户名
                            if let user = authManager.currentUser {
                                Text(user.username)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                Text("幸存者 ID: \(user.id.uuidString.prefix(8))")
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            } else {
                                Text("加载中...")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // 统计信息
                        HStack(spacing: 16) {
                            StatCard(title: "领地", value: "0", icon: "map.fill")
                            StatCard(title: "POI", value: "0", icon: "mappin.circle.fill")
                            StatCard(title: "资源", value: "0", icon: "cube.fill")
                        }
                        .padding(.horizontal)

                        // 功能列表
                        VStack(spacing: 12) {
                            NavigationButton(
                                icon: "gear",
                                title: "设置",
                                subtitle: "账户与偏好设置"
                            ) {
                                // TODO: 跳转到设置页
                            }

                            NavigationButton(
                                icon: "chart.bar.fill",
                                title: "统计",
                                subtitle: "查看游戏数据"
                            ) {
                                // TODO: 跳转到统计页
                            }

                            NavigationButton(
                                icon: "questionmark.circle",
                                title: "帮助",
                                subtitle: "游戏指南与FAQ"
                            ) {
                                // TODO: 跳转到帮助页
                            }
                        }
                        .padding(.horizontal)

                        // 退出登录按钮
                        Button(action: {
                            showLogoutConfirm = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .font(.headline)

                                Text("退出登录")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ApocalypseTheme.danger)
                            .cornerRadius(12)
                            .shadow(color: ApocalypseTheme.danger.opacity(0.3), radius: 10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        Spacer()
                    }
                }
            }
            .navigationTitle("个人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showLogoutConfirm = true
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(ApocalypseTheme.danger)
                    }
                }
            }
            .confirmationDialog(
                "确定要退出登录吗？",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("退出登录", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

// MARK: - 统计卡片

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 导航按钮

struct NavigationButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(subtitle)
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
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager(supabase: supabase))
}
