//
//  TradeRatingView.swift
//  EarthLord
//
//  交易评价弹窗
//  提交对交易的评分和评语
//

import SwiftUI

/// 交易评价视图
struct TradeRatingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tradeManager: TradeManager

    /// 要评价的交易历史
    let history: TradeHistory

    /// 当前用户ID
    let currentUserId: String

    // MARK: 状态

    /// 选中的评分
    @State private var selectedRating: Int = 5

    /// 评语
    @State private var comment: String = ""

    /// 是否正在提交
    @State private var isSubmitting: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 交易对方用户名
    private var counterpartyName: String {
        history.counterpartyUsername(myUserId: currentUserId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 交易摘要
                        tradeSummaryCard

                        // 评分选择
                        ratingSelector

                        // 评语输入
                        commentInput

                        // 错误提示
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.danger)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("评价交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        submitRating()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("提交")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .disabled(isSubmitting)
                }
            }
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - 交易摘要卡片

    private var tradeSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Text("交易摘要")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text(history.formattedCompletedAt)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 交易对方
            HStack(spacing: 8) {
                Circle()
                    .fill(ApocalypseTheme.info.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(counterpartyName.prefix(1)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.info)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("交易对方")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(counterpartyName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }

            // 我获得的物品
            VStack(alignment: .leading, spacing: 8) {
                Label("我获得", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.success)

                ForEach(history.counterpartyItems(myUserId: currentUserId)) { item in
                    TradeItemCompactRow(tradeItem: item)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 评分选择器

    private var ratingSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("您的评分")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 星级选择
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRating = rating
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(rating <= selectedRating ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)

                            Text(ratingLabel(rating))
                                .font(.system(size: 11))
                                .foregroundColor(rating == selectedRating ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // 当前选择提示
            Text(ratingDescription(selectedRating))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 评语输入

    private var commentInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("评语")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(可选)")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            TextEditor(text: $comment)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.background)
                )

            Text("\(comment.count) / 200")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 辅助方法

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "很差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "良好"
        case 5: return "优秀"
        default: return ""
        }
    }

    private func ratingDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "交易体验非常糟糕"
        case 2: return "交易体验不太满意"
        case 3: return "交易体验还可以"
        case 4: return "交易体验不错"
        case 5: return "交易体验非常棒！"
        default: return ""
        }
    }

    private func submitRating() {
        guard let rating = TradeRating(rawValue: selectedRating) else { return }

        isSubmitting = true
        errorMessage = nil

        // 限制评语长度
        let finalComment = comment.isEmpty ? nil : String(comment.prefix(200))

        Task {
            do {
                try await tradeManager.submitRating(
                    historyId: history.id,
                    rating: rating,
                    comment: finalComment
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - Preview

#Preview {
    TradeRatingView(
        history: TradeHistory(
            id: "1",
            offerId: "offer1",
            sellerId: "user1",
            sellerUsername: "卖家老王",
            buyerId: "user2",
            buyerUsername: "买家小明",
            sellerItems: [
                TradeItem(itemId: "item_medicine", quantity: 5, quality: nil)
            ],
            buyerItems: [
                TradeItem(itemId: "item_water_bottle", quantity: 20, quality: nil)
            ],
            completedAt: Date().addingTimeInterval(-3600)
        ),
        currentUserId: "user2"
    )
}
