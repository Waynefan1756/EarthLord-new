//
//  ChannelChatView.swift
//  EarthLord
//
//  频道聊天界面
//

import SwiftUI
import CoreLocation

struct ChannelChatView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var messageText = ""
    @State private var scrollToBottom = false
    @State private var bottomAnchorId = "bottom_anchor"

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 消息列表
                messageList

                Divider()
                    .background(ApocalypseTheme.textSecondary.opacity(0.2))

                // 输入区域
                inputArea
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(channel.name)
                            .font(.headline).fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                        Text("\(channel.memberCount) 成员")
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await communicationManager.loadChannelMessages(channelId: channel.id)
                communicationManager.subscribeToChannelMessages(channelId: channel.id)
                communicationManager.startRealtimeSubscription()
                scrollToBottom = true
            }
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
            communicationManager.stopRealtimeSubscription()
        }
        .onChange(of: messages.count) { _, _ in
            scrollToBottom = true
        }
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwn: message.senderId == authManager.currentUser?.id
                            )
                        }
                    }
                    // 底部锚点用于自动滚动
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorId)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: scrollToBottom) { _, shouldScroll in
                if shouldScroll {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                    }
                    scrollToBottom = false
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
            Text("暂无消息")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("成为第一个发言的人")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 输入区域

    private var inputArea: some View {
        Group {
            if canSend {
                sendInputBar
            } else {
                radioOnlyBanner
            }
        }
        .background(ApocalypseTheme.cardBackground)
    }

    private var sendInputBar: some View {
        HStack(spacing: 10) {
            TextField("发送消息...", text: $messageText, axis: .vertical)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.background)
                .cornerRadius(20)
                .lineLimit(1...4)

            Button {
                sendMessage()
            } label: {
                Image(systemName: communicationManager.isSendingMessage ? "hourglass" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ApocalypseTheme.textSecondary.opacity(0.4)
                            : ApocalypseTheme.primary
                    )
            }
            .disabled(
                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || communicationManager.isSendingMessage
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var radioOnlyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Text("📻 收音机模式：只能收听，无法发送消息")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - 发送消息

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        Task {
            let deviceType = communicationManager.getCurrentDeviceType().rawValue
            let coord = LocationManager.shared.userLocation
            await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: text,
                latitude: coord?.latitude,
                longitude: coord?.longitude,
                deviceType: deviceType
            )
        }
    }
}

// MARK: - 消息气泡

private struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwn: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwn { Spacer(minLength: 50) }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                // 发送者呼号（非自己时显示）
                if !isOwn {
                    HStack(spacing: 4) {
                        Image(systemName: deviceIcon)
                            .font(.caption2)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(message.senderCallsign ?? "匿名幸存者")
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                // 消息内容
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(isOwn ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOwn ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                    .cornerRadius(16)

                // 时间
                Text(message.timeAgo)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
            }

            if !isOwn { Spacer(minLength: 50) }
        }
    }

    private var deviceIcon: String {
        switch message.metadata?.deviceType {
        case "walkie_talkie": return "phone.badge.waveform"
        case "camp_radio": return "antenna.radiowaves.left.and.right"
        case "satellite": return "antenna.radiowaves.left.and.right.circle"
        default: return "radio"
        }
    }
}

// MARK: - Preview

#Preview {
    ChannelChatView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .public,
        channelCode: "PUB-ABC123",
        name: "末日求生群",
        description: "分享末日生存技巧",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(AuthManager(supabase: supabase))
}
