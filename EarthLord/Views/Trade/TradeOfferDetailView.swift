//
//  TradeOfferDetailView.swift
//  EarthLord
//
//  挂单详情页
//  显示完整挂单信息，检查库存并支持接受交易
//

import SwiftUI

/// 挂单详情视图
struct TradeOfferDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var authManager: AuthManager

    /// 挂单信息
    let offer: TradeOffer

    // MARK: 状态

    /// 是否正在接受交易
    @State private var isAccepting: Bool = false

    /// 是否显示确认弹窗
    @State private var showConfirmation: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 成功提示
    @State private var showSuccess: Bool = false

    /// 库存检查结果
    private var inventoryCheck: (sufficient: Bool, missing: [String]) {
        var missing: [String] = []

        for requestItem in offer.requestingItems {
            let matchingItems = inventoryManager.items.filter { invItem in
                invItem.itemId == requestItem.itemId &&
                (requestItem.quality == nil || invItem.quality?.rawValue == requestItem.quality)
            }
            let totalQuantity = matchingItems.reduce(0) { $0 + $1.quantity }

            if totalQuantity < requestItem.quantity {
                let itemName = ItemDefinitions.get(requestItem.itemId)?.name ?? requestItem.itemId
                missing.append("\(itemName) (需要\(requestItem.quantity)，拥有\(totalQuantity))")
            }
        }

        return (missing.isEmpty, missing)
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // 卖家信息
                    sellerInfoCard

                    // 提供物品详情
                    offeringItemsCard

                    // 索取物品详情
                    requestingItemsCard

                    // 库存检查
                    inventoryCheckCard

                    // 留言
                    if let message = offer.message, !message.isEmpty {
                        messageCard(message)
                    }

                    // 错误提示
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.danger)
                            .padding(.horizontal, 16)
                    }

                    // 接受交易按钮
                    if offer.canBeAccepted {
                        acceptButton
                            .padding(.top, 8)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("挂单详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认接受交易", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认") {
                acceptTrade()
            }
        } message: {
            Text("您将用以下物品交换：\n\n索取：\(offer.requestingDescription)\n\n获得：\(offer.offeringDescription)")
        }
        .alert("交易成功", isPresented: $showSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("交易已完成，物品已添加到您的背包。")
        }
    }

    // MARK: - 卖家信息卡片

    private var sellerInfoCard: some View {
        HStack(spacing: 12) {
            // 头像
            Circle()
                .fill(ApocalypseTheme.primary.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(offer.ownerUsername.prefix(1)))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(offer.ownerUsername)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("卖家")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 剩余时间
            VStack(alignment: .trailing, spacing: 4) {
                RemainingTimeBadge(
                    remainingTime: offer.formattedRemainingTime,
                    isUrgent: offer.remainingTime < 3600
                )

                Text("剩余时间")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 提供物品卡片

    private var offeringItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("卖家提供", systemImage: "arrow.up.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.success)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            ForEach(offer.offeringItems) { item in
                TradeItemRow(tradeItem: item)

                if item.id != offer.offeringItems.last?.id {
                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.2))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 索取物品卡片

    private var requestingItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("卖家想要", systemImage: "arrow.down.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.info)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            ForEach(offer.requestingItems) { item in
                TradeItemRow(tradeItem: item)

                if item.id != offer.requestingItems.last?.id {
                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.2))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 库存检查卡片

    private var inventoryCheckCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("库存检查", systemImage: inventoryCheck.sufficient ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(inventoryCheck.sufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)

                Spacer()

                Text(inventoryCheck.sufficient ? "物品充足" : "物品不足")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(inventoryCheck.sufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
            }

            if !inventoryCheck.sufficient {
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                VStack(alignment: .leading, spacing: 6) {
                    Text("缺少以下物品：")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    ForEach(inventoryCheck.missing, id: \.self) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.danger)

                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            inventoryCheck.sufficient ? ApocalypseTheme.success.opacity(0.3) : ApocalypseTheme.danger.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - 留言卡片

    private func messageCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("卖家留言", systemImage: "text.bubble.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 接受交易按钮

    private var acceptButton: some View {
        Button {
            showConfirmation = true
        } label: {
            HStack(spacing: 8) {
                if isAccepting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }

                Text("接受交易")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(inventoryCheck.sufficient ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!inventoryCheck.sufficient || isAccepting)
    }

    // MARK: - 接受交易

    private func acceptTrade() {
        isAccepting = true
        errorMessage = nil

        Task {
            do {
                _ = try await tradeManager.acceptOffer(offerId: offer.id)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isAccepting = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TradeOfferDetailView(
            offer: TradeOffer(
                id: "1",
                ownerId: "user2",
                ownerUsername: "幸存者小明",
                offeringItems: [
                    TradeItem(itemId: "item_medicine", quantity: 5, quality: nil),
                    TradeItem(itemId: "item_bandage", quantity: 20, quality: nil),
                    TradeItem(itemId: "item_first_aid_kit", quantity: 2, quality: "good")
                ],
                requestingItems: [
                    TradeItem(itemId: "item_water_bottle", quantity: 15, quality: nil),
                    TradeItem(itemId: "item_canned_food", quantity: 10, quality: nil)
                ],
                status: .active,
                message: "急需水和食物，可以小刀，有诚意的来联系。",
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(14400)
            )
        )
    }
}
