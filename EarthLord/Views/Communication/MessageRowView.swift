//
//  MessageRowView.swift
//  EarthLord
//
//  消息中心行组件
//

import SwiftUI

struct MessageRowView: View {
    let summary: ChannelSummary

    private var isOfficial: Bool { summary.channel.channelType == .official }

    var body: some View {
        HStack(spacing: 12) {
            channelIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if isOfficial {
                        Text("官方")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }

                    Spacer()

                    if let last = summary.lastMessage {
                        Text(last.timeAgo)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                HStack {
                    if let last = summary.lastMessage {
                        if let callsign = last.senderCallsign {
                            Text("\(callsign): ")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        Text(last.content)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("暂无消息")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .italic()
                    }

                    Spacer()

                    if summary.unreadCount > 0 {
                        Text("\(summary.unreadCount)")
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(ApocalypseTheme.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(12)
        .background(isOfficial ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var channelIcon: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.2))
                .frame(width: 50, height: 50)
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
        }
    }

    private var iconName: String {
        switch summary.channel.channelType {
        case .official: return "megaphone.fill"
        case .public:   return "antenna.radiowaves.left.and.right"
        case .walkie:   return "person.wave.2.fill"
        case .camp:     return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle.fill"
        }
    }

    private var iconColor: Color {
        switch summary.channel.channelType {
        case .official:  return .red
        case .public:    return .blue
        case .walkie:    return ApocalypseTheme.primary
        case .camp:      return .purple
        case .satellite: return .cyan
        }
    }
}
