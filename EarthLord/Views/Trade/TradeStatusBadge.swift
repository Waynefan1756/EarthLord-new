//
//  TradeStatusBadge.swift
//  EarthLord
//
//  交易状态标签组件
//  显示挂单状态（进行中/已完成/已取消/已过期）
//

import SwiftUI

/// 交易状态标签
struct TradeStatusBadge: View {
    let status: TradeOfferStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.system(size: 10))

            Text(status.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor)
        )
    }

    /// 状态对应颜色
    private var statusColor: Color {
        switch status {
        case .active:
            return ApocalypseTheme.success
        case .completed:
            return ApocalypseTheme.info
        case .cancelled:
            return ApocalypseTheme.textMuted
        case .expired:
            return ApocalypseTheme.warning
        }
    }
}

// MARK: - 剩余时间标签

/// 剩余时间标签
struct RemainingTimeBadge: View {
    let remainingTime: String
    let isUrgent: Bool

    init(remainingTime: String, isUrgent: Bool = false) {
        self.remainingTime = remainingTime
        self.isUrgent = isUrgent
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))

            Text(remainingTime)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(isUrgent ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TradeStatusBadge(status: .active)
        TradeStatusBadge(status: .completed)
        TradeStatusBadge(status: .cancelled)
        TradeStatusBadge(status: .expired)

        RemainingTimeBadge(remainingTime: "2小时30分")
        RemainingTimeBadge(remainingTime: "30分钟", isUrgent: true)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
