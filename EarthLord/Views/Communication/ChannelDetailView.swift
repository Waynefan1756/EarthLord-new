//
//  ChannelDetailView.swift
//  EarthLord
//
//  频道详情页面
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isLoading = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var showChat = false

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 频道头像区域
                    channelHeader

                    // 频道信息卡片
                    infoCard

                    // 错误提示
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    // 操作按钮
                    actionButtons

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("删除频道", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("确认删除", role: .destructive) {
                    Task { await performDelete() }
                }
            } message: {
                Text("删除后频道将对所有人不可见，此操作不可撤销。")
            }
        }
    }

    // MARK: - 频道头像区域

    private var channelHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text(channel.name)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .multilineTextAlignment(.center)

            // 频道码
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text(channel.channelCode)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .monospaced()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(8)

            // 已订阅标签
            if isSubscribed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("已订阅")
                }
                .font(.caption).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.success)
            }

            // 频道描述
            if let desc = channel.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 频道信息卡片

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(
                icon: channel.channelType.iconName,
                label: "频道类型",
                value: channel.channelType.displayName
            )
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.15))

            infoRow(
                icon: "dot.radiowaves.left.and.right",
                label: "覆盖范围",
                value: rangeText(for: channel.channelType)
            )
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.15))

            infoRow(
                icon: "person.2.fill",
                label: "成员数量",
                value: "\(channel.memberCount) 人"
            )
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.15))

            infoRow(
                icon: "calendar",
                label: "创建时间",
                value: formattedDate(channel.createdAt)
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 已订阅用户：进入聊天
            if isSubscribed {
                Button {
                    showChat = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("进入聊天")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .fullScreenCover(isPresented: $showChat) {
                    ChannelChatView(channel: channel)
                        .environmentObject(authManager)
                }
            }

            if isCreator {
                // 创建者：删除频道
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("删除频道")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.danger.opacity(0.15))
                    .foregroundColor(ApocalypseTheme.danger)
                    .cornerRadius(12)
                }
            } else {
                // 非创建者：订阅/取消订阅
                Button {
                    Task { await toggleSubscription() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: isSubscribed ? ApocalypseTheme.textSecondary : .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isSubscribed ? "bell.slash" : "bell.badge")
                        }
                        Text(isSubscribed ? "取消订阅" : "订阅频道")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSubscribed ? ApocalypseTheme.cardBackground : ApocalypseTheme.primary)
                    .foregroundColor(isSubscribed ? ApocalypseTheme.textSecondary : .white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
        }
    }

    // MARK: - 操作逻辑

    private func toggleSubscription() async {
        guard let userId = authManager.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            if isSubscribed {
                try await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
            } else {
                try await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
            }
        } catch {
            errorMessage = "操作失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    private func performDelete() async {
        isLoading = true
        errorMessage = nil
        do {
            try await communicationManager.deleteChannel(channelId: channel.id)
            dismiss()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - 辅助

    private func rangeText(for type: ChannelType) -> String {
        switch type {
        case .official: return "全球覆盖"
        case .public: return "无限制"
        case .walkie: return "3 公里"
        case .camp: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    ChannelDetailView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public,
        channelCode: "PUB-ABC123",
        name: "末日求生群",
        description: "分享末日生存技巧与资源",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(AuthManager(supabase: supabase))
}
