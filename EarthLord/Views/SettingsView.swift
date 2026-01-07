//
//  SettingsView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/3.
//

import SwiftUI

/// 设置页面
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss

    @State private var showDeleteConfirm = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 账户设置区域
                            VStack(spacing: 0) {
                                Text("账户设置")
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)

                                VStack(spacing: 0) {
                                    SettingsRow(
                                        icon: "envelope.fill",
                                        iconColor: .blue,
                                        title: "邮箱",
                                        value: authManager.currentUserEmail ?? "未设置".localized
                                    )

                                    Divider()
                                        .padding(.leading, 60)

                                    SettingsRow(
                                        icon: "lock.fill",
                                        iconColor: .orange,
                                        title: "修改密码",
                                        showChevron: true
                                    ) {
                                        // TODO: 跳转到修改密码页面
                                    }
                                }
                                .background(ApocalypseTheme.cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .padding(.top, 20)

                            // 通用设置区域
                            VStack(spacing: 0) {
                                Text("通用设置")
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)

                                VStack(spacing: 0) {
                                    SettingsRow(
                                        icon: "bell.fill",
                                        iconColor: ApocalypseTheme.primary,
                                        title: "通知设置",
                                        showChevron: true
                                    ) {
                                        // TODO: 跳转到通知设置页面
                                    }

                                    Divider()
                                        .padding(.leading, 60)

                                    NavigationLink(destination: LanguageSelectionView()) {
                                        HStack(spacing: 16) {
                                            Image(systemName: "globe")
                                                .font(.title3)
                                                .foregroundColor(.green)
                                                .frame(width: 24)

                                            Text("语言")
                                                .font(.body)
                                                .foregroundColor(ApocalypseTheme.textPrimary)

                                            Spacer()

                                            Text(languageManager.currentLanguageDisplayText)
                                                .font(.subheadline)
                                                .foregroundColor(ApocalypseTheme.textSecondary)

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(ApocalypseTheme.textMuted)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .contentShape(Rectangle())
                                    }
                                }
                                .background(ApocalypseTheme.cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }

                            // 关于区域
                            VStack(spacing: 0) {
                                Text("关于")
                                    .font(.subheadline)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)

                                VStack(spacing: 0) {
                                    SettingsRow(
                                        icon: "info.circle.fill",
                                        iconColor: .cyan,
                                        title: "版本",
                                        value: "1.0.0"
                                    )

                                    Divider()
                                        .padding(.leading, 60)

                                    SettingsRow(
                                        icon: "doc.text.fill",
                                        iconColor: .purple,
                                        title: "隐私政策",
                                        showChevron: true
                                    ) {
                                        // TODO: 跳转到隐私政策页面
                                    }
                                }
                                .background(ApocalypseTheme.cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }

                            Spacer(minLength: 100)
                        }
                    }

                    // 固定在底部的删除账户按钮
                    VStack(spacing: 12) {
                        if let error = deleteError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                                .padding(.horizontal)
                        }

                        Button(action: {
                            showDeleteConfirm = true
                            deleteConfirmText = ""
                            deleteError = nil
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.headline)

                                Text("删除账户")
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
                        .disabled(isDeleting)
                        .opacity(isDeleting ? 0.6 : 1.0)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                    .background(ApocalypseTheme.background)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .sheet(isPresented: $showDeleteConfirm) {
                DeleteAccountConfirmView(
                    isPresented: $showDeleteConfirm,
                    confirmText: $deleteConfirmText,
                    onConfirm: {
                        Task {
                            await performDeleteAccount()
                        }
                    }
                )
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("正在删除账户...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    // MARK: - 删除账户

    private func performDeleteAccount() async {
        print("🗑️ 用户确认删除账户")

        await MainActor.run {
            isDeleting = true
            deleteError = nil
        }

        do {
            try await authManager.deleteAccount()
            print("✅ 账户删除成功，关闭设置页面")
            // 删除成功后会自动通过 authStateChanges 跳转到登录页
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("❌ 删除账户失败: \(error.localizedDescription)")
            await MainActor.run {
                deleteError = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

// MARK: - 设置行

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey  // 改为 LocalizedStringKey
    var value: String?  // 保持 String，用于显示动态内容（如邮箱地址）
    var showChevron: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
    }
}

// MARK: - 删除账户确认视图

struct DeleteAccountConfirmView: View {
    @Binding var isPresented: Bool
    @Binding var confirmText: String
    let onConfirm: () -> Void

    // 本地化的"删除"文本
    private let deleteKeyword = NSLocalizedString("删除", comment: "")

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.danger.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(ApocalypseTheme.danger)
                    }
                    .padding(.top, 40)

                    // 警告文字
                    VStack(spacing: 12) {
                        Text("删除账户")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("此操作不可恢复")
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.danger)

                        Text("将永久删除您的账户及所有相关数据，包括：\n\n• 用户资料\n• 游戏进度\n• 领地信息\n• 所有个人数据")
                            .font(.body)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // 确认输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: NSLocalizedString("请输入\"%@\"以确认", comment: ""), deleteKeyword))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("", text: $confirmText)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(8)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 20)

                    Spacer()

                    // 按钮组
                    VStack(spacing: 12) {
                        Button(action: {
                            isPresented = false
                            // 延迟执行删除，确保 sheet 先关闭
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onConfirm()
                            }
                        }) {
                            Text("确认删除")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(confirmText == deleteKeyword ? ApocalypseTheme.danger : ApocalypseTheme.danger.opacity(0.5))
                                .cornerRadius(12)
                        }
                        .disabled(confirmText != deleteKeyword)

                        Button(action: {
                            confirmText = ""
                            isPresented = false
                        }) {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ApocalypseTheme.cardBackground)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager(supabase: supabase))
        .environmentObject(LanguageManager.shared)
}
