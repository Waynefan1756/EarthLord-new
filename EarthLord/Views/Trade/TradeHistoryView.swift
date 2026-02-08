//
//  TradeHistoryView.swift
//  EarthLord
//
//  交易历史列表视图
//  显示已完成的交易记录
//

import SwiftUI

/// 交易历史视图
struct TradeHistoryView: View {
    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var authManager: AuthManager

    // MARK: 状态

    /// 选中要评价的交易
    @State private var historyToRate: TradeHistory?

    /// 是否显示评价弹窗
    @State private var showRatingView: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 当前用户ID
    private var currentUserId: String {
        authManager.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // 统计信息
            if !tradeManager.tradeHistory.isEmpty {
                statsHeader
            }

            // 内容区
            if tradeManager.tradeHistory.isEmpty && !tradeManager.isLoading {
                emptyStateView
            } else {
                historyList
            }
        }
        .sheet(isPresented: $showRatingView) {
            if let history = historyToRate {
                TradeRatingView(
                    history: history,
                    currentUserId: currentUserId
                )
            }
        }
        .onAppear {
            loadHistory()
        }
    }

    // MARK: - 统计信息头部

    private var statsHeader: some View {
        HStack(spacing: 20) {
            // 总交易数
            statItem(
                value: "\(tradeManager.tradeHistory.count)",
                label: "总交易",
                icon: "arrow.triangle.2.circlepath"
            )

            Divider()
                .frame(height: 30)
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 待评价数
            let pendingCount = tradeManager.tradeHistory.filter { !$0.hasRated(myUserId: currentUserId) }.count
            statItem(
                value: "\(pendingCount)",
                label: "待评价",
                icon: "star"
            )

            Divider()
                .frame(height: 30)
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 作为卖家
            let sellerCount = tradeManager.tradeHistory.filter { $0.isSeller(userId: currentUserId) }.count
            statItem(
                value: "\(sellerCount)",
                label: "作为卖家",
                icon: "arrow.up.circle"
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(ApocalypseTheme.cardBackground)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
    }

    // MARK: - 历史列表

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.tradeHistory) { history in
                    TradeHistoryCard(
                        history: history,
                        currentUserId: currentUserId,
                        onRate: {
                            historyToRate = history
                            showRatingView = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await refreshHistory()
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.textMuted.opacity(0.6))
            }

            Text("暂无交易记录")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("完成交易后，记录将显示在这里")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 操作方法

    private func loadHistory() {
        Task {
            do {
                try await tradeManager.loadTradeHistory()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshHistory() async {
        do {
            try await tradeManager.loadTradeHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    TradeHistoryView()
        .background(ApocalypseTheme.background)
}
