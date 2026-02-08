//
//  MyOfferCard.swift
//  EarthLord
//
//  我的挂单卡片组件
//  显示挂单状态、物品摘要、剩余时间和操作按钮
//

import SwiftUI

/// 我的挂单卡片
struct MyOfferCard: View {
    let offer: TradeOffer
    let onCancel: () -> Void

    /// 是否即将过期（小于1小时）
    private var isUrgent: Bool {
        offer.remainingTime < 3600 && offer.status == .active
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：状态标签 + 剩余时间
            headerRow

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 提供物品
            offeringSection

            // 索取物品
            requestingSection

            // 留言（如有）
            if let message = offer.message, !message.isEmpty {
                messageSection(message)
            }

            // 底部操作区
            if offer.canBeCancelled {
                actionRow
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 顶部行

    private var headerRow: some View {
        HStack {
            TradeStatusBadge(status: offer.status)

            Spacer()

            if offer.status == .active {
                RemainingTimeBadge(
                    remainingTime: offer.formattedRemainingTime,
                    isUrgent: isUrgent
                )
            } else if let completedAt = offer.completedAt {
                Text(formatDate(completedAt))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    // MARK: - 提供物品区

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("我提供", systemImage: "arrow.up.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.success)

            TradeItemsSummary(items: offer.offeringItems)
        }
    }

    // MARK: - 索取物品区

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("我想要", systemImage: "arrow.down.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.info)

            TradeItemsSummary(items: offer.requestingItems)
        }
    }

    // MARK: - 留言区

    private func messageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("留言", systemImage: "text.bubble")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(.top, 4)
    }

    // MARK: - 操作行

    private var actionRow: some View {
        HStack {
            Spacer()

            Button {
                onCancel()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))

                    Text("取消挂单")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ApocalypseTheme.danger, lineWidth: 1)
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 辅助方法

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            MyOfferCard(
                offer: TradeOffer(
                    id: "1",
                    ownerId: "user1",
                    ownerUsername: "测试用户",
                    offeringItems: [
                        TradeItem(itemId: "item_water_bottle", quantity: 10, quality: nil),
                        TradeItem(itemId: "item_canned_food", quantity: 5, quality: nil)
                    ],
                    requestingItems: [
                        TradeItem(itemId: "item_bandage", quantity: 20, quality: nil)
                    ],
                    status: .active,
                    message: "急需绷带，可以议价",
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(7200)
                ),
                onCancel: {}
            )

            MyOfferCard(
                offer: TradeOffer(
                    id: "2",
                    ownerId: "user1",
                    ownerUsername: "测试用户",
                    offeringItems: [
                        TradeItem(itemId: "item_wood", quantity: 50, quality: "good")
                    ],
                    requestingItems: [
                        TradeItem(itemId: "item_scrap_metal", quantity: 30, quality: nil)
                    ],
                    status: .completed,
                    message: nil,
                    createdAt: Date().addingTimeInterval(-86400),
                    expiresAt: Date().addingTimeInterval(-3600),
                    completedAt: Date().addingTimeInterval(-7200)
                ),
                onCancel: {}
            )
        }
        .padding(16)
    }
    .background(ApocalypseTheme.background)
}
