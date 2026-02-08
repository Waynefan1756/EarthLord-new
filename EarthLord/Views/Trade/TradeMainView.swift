//
//  TradeMainView.swift
//  EarthLord
//
//  交易主容器视图
//  通过分段选择器切换三个子视图：我的挂单、交易市场、交易历史
//

import SwiftUI

/// 交易分段类型
enum TradeSegment: String, CaseIterable {
    case myOffers = "我的挂单"
    case market = "交易市场"
    case history = "交易历史"

    var iconName: String {
        switch self {
        case .myOffers: return "list.bullet.rectangle"
        case .market: return "storefront"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

/// 交易主视图
struct TradeMainView: View {
    @EnvironmentObject var tradeManager: TradeManager

    // MARK: 状态

    /// 当前选中的分段
    @State private var selectedSegment: TradeSegment = .myOffers

    var body: some View {
        VStack(spacing: 0) {
            // 分段选择器
            segmentPicker
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // 内容区
            contentView
        }
        .onAppear {
            refreshData()
        }
    }

    // MARK: - 分段选择器

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(TradeSegment.allCases, id: \.self) { segment in
                segmentButton(segment)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    private func segmentButton(_ segment: TradeSegment) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSegment = segment
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: segment.iconName)
                    .font(.system(size: 12))

                Text(segment.rawValue)
                    .font(.system(size: 13, weight: selectedSegment == segment ? .semibold : .regular))
            }
            .foregroundColor(selectedSegment == segment ? .white : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSegment == segment ? ApocalypseTheme.primary : Color.clear)
                    .padding(2)
            )
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .myOffers:
            MyOffersView()

        case .market:
            TradeMarketView()

        case .history:
            TradeHistoryView()
        }
    }

    // MARK: - 数据刷新

    private func refreshData() {
        Task {
            do {
                try await tradeManager.refreshAll()
            } catch {
                print("刷新交易数据失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TradeMainView()
    }
    .background(ApocalypseTheme.background)
}
