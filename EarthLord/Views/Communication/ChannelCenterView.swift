//
//  ChannelCenterView.swift
//  EarthLord
//
//  频道中心页面
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0       // 0=我的频道, 1=发现频道
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?
    @State private var selectedOfficialChannel: CommunicationChannel?
    @State private var searchText = ""

    var filteredPublicChannels: [CommunicationChannel] {
        if searchText.isEmpty {
            return communicationManager.channels
        }
        return communicationManager.channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            headerBar

            // Tab 切换栏
            tabBar

            // 搜索框（仅发现页面）
            if selectedTab == 1 {
                searchBar
            }

            // 内容区
            if selectedTab == 0 {
                myChannelsList
            } else {
                discoverChannelsList
            }
        }
        .background(ApocalypseTheme.background)
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet()
                .environmentObject(authManager)
                .onDisappear { reloadData() }
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel)
                .environmentObject(authManager)
                .onDisappear { reloadData() }
        }
        .sheet(item: $selectedOfficialChannel) { channel in
            OfficialChannelDetailView(channel: channel)
        }
        .onAppear { reloadData() }
    }

    // MARK: - 顶部操作栏

    private var headerBar: some View {
        HStack {
            Text("频道中心")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("创建")
                }
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tab 切换栏

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(["我的频道", "发现频道"], id: \.self) { title in
                let index = title == "我的频道" ? 0 : 1
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                } label: {
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.subheadline).fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                        Rectangle()
                            .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(ApocalypseTheme.background)
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)
            TextField("搜索频道名称或频道码", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .autocapitalization(.none)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 我的频道列表

    private var myChannelsList: some View {
        Group {
            if communicationManager.subscribedChannels.isEmpty {
                emptyState(
                    icon: "dot.radiowaves.left.and.right",
                    title: "暂无订阅频道",
                    subtitle: "前往「发现频道」订阅，或创建自己的频道"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(communicationManager.subscribedChannels) { subscribed in
                            ChannelRowView(channel: subscribed.channel, isSubscribed: true)
                                .onTapGesture {
                                    if subscribed.channel.channelType == .official {
                                        selectedOfficialChannel = subscribed.channel
                                    } else {
                                        selectedChannel = subscribed.channel
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - 发现频道列表

    private var discoverChannelsList: some View {
        Group {
            if filteredPublicChannels.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: searchText.isEmpty ? "暂无公开频道" : "未找到相关频道",
                    subtitle: searchText.isEmpty ? "点击右上角「创建」建立第一个频道" : "尝试其他关键词"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPublicChannels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                            .onTapGesture { selectedChannel = channel }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - 空状态

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.4))
            Text(title)
                .font(.title3).fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 数据加载

    private func reloadData() {
        guard let userId = authManager.currentUser?.id else { return }
        Task {
            await communicationManager.loadPublicChannels()
            await communicationManager.loadSubscribedChannels(userId: userId)
        }
    }
}

// MARK: - 频道行组件

private struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    if isSubscribed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }
                HStack(spacing: 8) {
                    Text(channel.channelType.displayName)
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary.opacity(0.12))
                        .cornerRadius(4)
                    Text(channel.channelCode)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 成员数
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("\(channel.memberCount)")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager(supabase: supabase))
}
