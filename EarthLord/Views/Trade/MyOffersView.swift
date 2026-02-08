//
//  MyOffersView.swift
//  EarthLord
//
//  我的挂单列表视图
//  显示用户发布的所有挂单，支持取消和查看详情
//

import SwiftUI

/// 我的挂单视图
struct MyOffersView: View {
    @EnvironmentObject var tradeManager: TradeManager

    // MARK: 状态

    /// 是否显示创建挂单页
    @State private var showCreateOffer: Bool = false

    /// 正在取消的挂单ID
    @State private var cancellingOfferId: String?

    /// 是否显示取消确认弹窗
    @State private var showCancelConfirmation: Bool = false

    /// 选中要取消的挂单
    @State private var offerToCancel: TradeOffer?

    /// 错误信息
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            headerBar

            // 内容区
            if tradeManager.myOffers.isEmpty && !tradeManager.isLoading {
                emptyStateView
            } else {
                offersList
            }
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateOfferView()
        }
        .alert("确认取消挂单", isPresented: $showCancelConfirmation) {
            Button("不取消", role: .cancel) {
                offerToCancel = nil
            }
            Button("确认取消", role: .destructive) {
                if let offer = offerToCancel {
                    cancelOffer(offer)
                }
            }
        } message: {
            Text("取消后物品将退回背包。确定要取消此挂单吗？")
        }
        .onAppear {
            loadOffers()
        }
    }

    // MARK: - 顶部操作栏

    private var headerBar: some View {
        HStack {
            // 统计信息
            VStack(alignment: .leading, spacing: 2) {
                Text("共 \(tradeManager.myOffers.count) 个挂单")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                let activeCount = tradeManager.myOffers.filter { $0.status == .active }.count
                Text("\(activeCount) 个进行中")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 发布按钮
            Button {
                showCreateOffer = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("发布挂单")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.primary)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tradeManager.myOffers) { offer in
                    MyOfferCard(offer: offer) {
                        offerToCancel = offer
                        showCancelConfirmation = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await refreshOffers()
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.primary.opacity(0.6))
            }

            Text("暂无挂单")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("发布挂单，与其他幸存者交换物资")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            Button {
                showCreateOffer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("发布第一个挂单")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.primary)
                )
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 操作方法

    private func loadOffers() {
        Task {
            do {
                try await tradeManager.loadMyOffers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshOffers() async {
        do {
            try await tradeManager.loadMyOffers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancelOffer(_ offer: TradeOffer) {
        cancellingOfferId = offer.id

        Task {
            do {
                try await tradeManager.cancelOffer(offerId: offer.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            cancellingOfferId = nil
            offerToCancel = nil
        }
    }
}

// MARK: - Preview

#Preview {
    MyOffersView()
        .background(ApocalypseTheme.background)
}
