//
//  TradeHistoryCard.swift
//  EarthLord
//
//  交易历史记录卡片组件
//  显示交易对方、物品摘要、完成时间和评价状态
//

import SwiftUI

/// 交易历史记录卡片
struct TradeHistoryCard: View {
    let history: TradeHistory
    let currentUserId: String
    let onRate: () -> Void

    /// 交易对方用户名
    private var counterpartyName: String {
        history.counterpartyUsername(myUserId: currentUserId)
    }

    /// 我是否是卖家
    private var isSeller: Bool {
        history.isSeller(userId: currentUserId)
    }

    /// 是否已评价
    private var hasRated: Bool {
        history.hasRated(myUserId: currentUserId)
    }

    /// 对方给我的评分
    private var ratingReceived: TradeRating? {
        history.ratingReceived(myUserId: currentUserId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：对方信息 + 完成时间
            headerRow

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 我给出的物品
            myItemsSection

            // 我获得的物品
            receivedItemsSection

            // 评价区域
            ratingSection
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
            // 对方头像和用户名
            HStack(spacing: 8) {
                Circle()
                    .fill(ApocalypseTheme.info.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(counterpartyName.prefix(1)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.info)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(counterpartyName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(isSeller ? "买家" : "卖家")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 完成时间
            Text(history.formattedCompletedAt)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    // MARK: - 我给出的物品

    private var myItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("我给出", systemImage: "arrow.up.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.danger.opacity(0.8))

            TradeItemsSummary(items: history.myItems(myUserId: currentUserId))
        }
    }

    // MARK: - 我获得的物品

    private var receivedItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("我获得", systemImage: "arrow.down.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.success)

            TradeItemsSummary(items: history.counterpartyItems(myUserId: currentUserId))
        }
    }

    // MARK: - 评价区域

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            HStack {
                // 对方给我的评分
                if let rating = ratingReceived {
                    HStack(spacing: 4) {
                        Text("收到评分:")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        StarRatingDisplay(rating: rating.rawValue)
                    }
                } else {
                    Text("对方尚未评价")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }

                Spacer()

                // 评价按钮或已评价标识
                if hasRated {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("已评价")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(ApocalypseTheme.success)
                } else {
                    Button {
                        onRate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                                .font(.system(size: 12))
                            Text("评价")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ApocalypseTheme.primary)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - 星级显示组件

struct StarRatingDisplay: View {
    let rating: Int
    let maxRating: Int

    init(rating: Int, maxRating: Int = 5) {
        self.rating = rating
        self.maxRating = maxRating
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(index <= rating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TradeHistoryCard(
                history: TradeHistory(
                    id: "1",
                    offerId: "offer1",
                    sellerId: "user1",
                    sellerUsername: "我是卖家",
                    buyerId: "user2",
                    buyerUsername: "买家小明",
                    sellerItems: [
                        TradeItem(itemId: "item_water_bottle", quantity: 10, quality: nil)
                    ],
                    buyerItems: [
                        TradeItem(itemId: "item_bandage", quantity: 20, quality: nil)
                    ],
                    completedAt: Date().addingTimeInterval(-3600),
                    sellerRating: .good,
                    buyerRating: nil,
                    sellerComment: nil,
                    buyerComment: nil
                ),
                currentUserId: "user1",
                onRate: {}
            )

            TradeHistoryCard(
                history: TradeHistory(
                    id: "2",
                    offerId: "offer2",
                    sellerId: "user3",
                    sellerUsername: "卖家老王",
                    buyerId: "user1",
                    buyerUsername: "我是买家",
                    sellerItems: [
                        TradeItem(itemId: "item_medicine", quantity: 5, quality: nil)
                    ],
                    buyerItems: [
                        TradeItem(itemId: "item_canned_food", quantity: 15, quality: nil)
                    ],
                    completedAt: Date().addingTimeInterval(-86400),
                    sellerRating: .excellent,
                    buyerRating: .good,
                    sellerComment: "很好的买家",
                    buyerComment: nil
                ),
                currentUserId: "user1",
                onRate: {}
            )
        }
        .padding(16)
    }
    .background(ApocalypseTheme.background)
}
