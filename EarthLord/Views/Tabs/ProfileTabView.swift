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

                VStack(spacing: 0) {
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

                                // 用户信息
                                if let user = authManager.currentUser {
                                    Text(user.username)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    if let email = authManager.currentUserEmail {
                                        Text(email)
                                            .font(.subheadline)
                                            .foregroundColor(ApocalypseTheme.textSecondary)
                                    }

                                    Text("ID: \(user.id.uuidString.prefix(8).uppercased())...")
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
                            .padding(.top, 20)

                            // 统计信息
                            HStack(spacing: 0) {
                                StatCard(title: "领地", value: "0", icon: "flag.fill")

                                Divider()
                                    .background(ApocalypseTheme.textMuted.opacity(0.3))
                                    .frame(height: 60)

                                StatCard(title: "资源点", value: "0", icon: "mappin.circle.fill")

                                Divider()
                                    .background(ApocalypseTheme.textMuted.opacity(0.3))
                                    .frame(height: 60)

                                StatCard(title: "探索距离", value: "0", icon: "figure.walk")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)

                            // 功能列表
                            VStack(spacing: 0) {
                                MenuButton(
                                    icon: "gearshape.fill",
                                    iconColor: .gray,
                                    title: "设置"
                                ) {
                                    // TODO: 跳转到设置页
                                }

                                Divider()
                                    .padding(.leading, 60)

                                MenuButton(
                                    icon: "bell.fill",
                                    iconColor: ApocalypseTheme.primary,
                                    title: "通知"
                                ) {
                                    // TODO: 跳转到通知页
                                }

                                Divider()
                                    .padding(.leading, 60)

                                MenuButton(
                                    icon: "questionmark.circle.fill",
                                    iconColor: .blue,
                                    title: "帮助"
                                ) {
                                    // TODO: 跳转到帮助页
                                }

                                Divider()
                                    .padding(.leading, 60)

                                MenuButton(
                                    icon: "info.circle.fill",
                                    iconColor: .green,
                                    title: "关于"
                                ) {
                                    // TODO: 跳转到关于页
                                }
                            }
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }

                    // 固定在底部的退出登录按钮
                    Button(action: {
                        showLogoutConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
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
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.background)
                }
            }
            .navigationTitle("幸存者档案")
            .navigationBarTitleDisplayMode(.inline)
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
                .font(.title3)
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
        .padding(.vertical, 12)
    }
}

// MARK: - 菜单按钮

struct MenuButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager(supabase: supabase))
}
