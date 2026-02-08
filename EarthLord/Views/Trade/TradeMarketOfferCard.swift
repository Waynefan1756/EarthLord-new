//
//  TradeMarketOfferCard.swift
//  EarthLord
//
//  交易市场挂单卡片组件
//  显示卖家信息、物品摘要和剩余时间
//

import SwiftUI

/// 交易市场挂单卡片
struct TradeMarketOfferCard: View {
    let offer: TradeOffer

    /// 是否即将过期（小于1小时）
    private var isUrgent: Bool {
        offer.remainingTime < 3600
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：卖家信息 + 剩余时间
            headerRow

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 提供物品
            offeringSection

            // 索取物品
            requestingSection

            // 底部：查看详情提示
            HStack {
                Spacer()

                HStack(spacing: 4) {
                    Text("查看详情")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.primary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.primary)
                }
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
            // 卖家头像和用户名
            HStack(spacing: 8) {
                // 头像占位
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(offer.ownerUsername.prefix(1)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.primary)
                    )

                Text(offer.ownerUsername)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            RemainingTimeBadge(
                remainingTime: offer.formattedRemainingTime,
                isUrgent: isUrgent
            )
        }
    }

    // MARK: - 提供物品区

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("提供", systemImage: "arrow.up.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.success)

            TradeItemsSummary(items: offer.offeringItems)
        }
    }

    // MARK: - 索取物品区

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("想要", systemImage: "arrow.down.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.info)

            TradeItemsSummary(items: offer.requestingItems)
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TradeMarketOfferCard(
                offer: TradeOffer(
                    id: "1",
                    ownerId: "user2",
                    ownerUsername: "幸存者A",
                    offeringItems: [
                        TradeItem(itemId: "item_medicine", quantity: 5, quality: nil),
                        TradeItem(itemId: "item_bandage", quantity: 20, quality: nil)
                    ],
                    requestingItems: [
                        TradeItem(itemId: "item_water_bottle", quantity: 15, quality: nil)
                    ],
                    status: .active,
                    message: nil,
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(14400)
                )
            )

            TradeMarketOfferCard(
                offer: TradeOffer(
                    id: "2",
                    ownerId: "user3",
                    ownerUsername: "废土商人",
                    offeringItems: [
                        TradeItem(itemId: "item_gasoline", quantity: 2, quality: nil)
                    ],
                    requestingItems: [
                        TradeItem(itemId: "item_canned_food", quantity: 30, quality: nil),
                        TradeItem(itemId: "item_purified_water", quantity: 20, quality: nil)
                    ],
                    status: .active,
                    message: "汽油急售",
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(1800)
                )
            )
        }
        .padding(16)
    }
    .background(ApocalypseTheme.background)
}
