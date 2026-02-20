//
//  CommunicationTabView.swift
//  EarthLord
//
//  通讯系统主入口页面
//  包含消息、频道、呼叫、设备四个分段
//

import SwiftUI
import Supabase

struct CommunicationTabView: View {
    // MARK: - State

    @State private var selectedSection: CommunicationSection = .messages
    @StateObject private var communicationManager = CommunicationManager.shared
    @EnvironmentObject var authManager: AuthManager

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航
                headerSection

                // 内容区域
                contentView
            }
        }
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task { await communicationManager.loadDevices(userId: userId) }
            }
        }
    }

    // MARK: - 顶部导航

    private var headerSection: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("通讯中心")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 当前设备指示器
                if let device = communicationManager.currentDevice {
                    HStack(spacing: 4) {
                        Image(systemName: device.deviceType.iconName)
                            .font(.system(size: 12))
                        Text(device.deviceType.rangeText)
                            .font(.caption)
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ApocalypseTheme.primary.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // 导航按钮
            HStack(spacing: 0) {
                ForEach(CommunicationSection.allCases, id: \.self) { section in
                    Button(action: { selectedSection = section }) {
                        VStack(spacing: 4) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 20))
                            Text(section.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedSection == section ?
                            ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedSection == section ?
                            ApocalypseTheme.primary.opacity(0.15) : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Divider()
                .background(ApocalypseTheme.textSecondary.opacity(0.3))
        }
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .messages:
            MessageCenterView()
        case .channels:
            ChannelCenterView()
        case .call:
            PTTCallView()
        case .devices:
            DeviceManagementView()
        }
    }
}
