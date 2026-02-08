//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场列表视图
//  浏览其他玩家发布的挂单
//

import SwiftUI

/// 市场排序选项
enum MarketSortOption: String, CaseIterable {
    case newest = "最新"
    case expiringSoon = "即将过期"

    var iconName: String {
        switch self {
        case .newest: return "clock.arrow.circlepath"
        case .expiringSoon: return "timer"
        }
    }
}

/// 交易市场视图
struct TradeMarketView: View {
    @EnvironmentObject var tradeManager: TradeManager

    // MARK: 状态

    /// 选中的分类筛选
    @State private var selectedCategory: ItemCategory?

    /// 排序方式
    @State private var sortOption: MarketSortOption = .newest

    /// 搜索文字
    @State private var searchText: String = ""

    /// 错误信息
    @State private var errorMessage: String?

    /// 筛选后的挂单
    private var filteredOffers: [TradeOffer] {
        var offers = tradeManager.availableOffers

        // 分类筛选
        if let category = selectedCategory {
            offers = offers.filter { offer in
                let hasOfferingCategory = offer.offeringItems.contains { item in
                    ItemDefinitions.get(item.itemId)?.category == category
                }
                let hasRequestingCategory = offer.requestingItems.contains { item in
                    ItemDefinitions.get(item.itemId)?.category == category
                }
                return hasOfferingCategory || hasRequestingCategory
            }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            offers = offers.filter { offer in
                // 搜索物品名称
                let matchesOffering = offer.offeringItems.contains { item in
                    ItemDefinitions.get(item.itemId)?.name.localizedCaseInsensitiveContains(searchText) ?? false
                }
                let matchesRequesting = offer.requestingItems.contains { item in
                    ItemDefinitions.get(item.itemId)?.name.localizedCaseInsensitiveContains(searchText) ?? false
                }
                // 搜索卖家名称
                let matchesOwner = offer.ownerUsername.localizedCaseInsensitiveContains(searchText)

                return matchesOffering || matchesRequesting || matchesOwner
            }
        }

        // 排序
        switch sortOption {
        case .newest:
            offers.sort { $0.createdAt > $1.createdAt }
        case .expiringSoon:
            offers.sort { $0.remainingTime < $1.remainingTime }
        }

        return offers
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索和筛选
            searchAndFilterSection

            // 内容区
            if filteredOffers.isEmpty && !tradeManager.isLoading {
                emptyStateView
            } else {
                offersList
            }
        }
        .onAppear {
            loadOffers()
        }
    }

    // MARK: - 搜索和筛选区

    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textMuted)

                TextField("搜索物品或卖家...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .padding(.horizontal, 16)

            // 分类和排序
            HStack(spacing: 12) {
                // 分类筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryButton(nil, title: "全部")

                        ForEach(ItemCategory.allCases, id: \.self) { category in
                            categoryButton(category, title: category.displayName)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // 排序按钮
                Menu {
                    ForEach(MarketSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            HStack {
                                Image(systemName: option.iconName)
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortOption.iconName)
                        Text(sortOption.rawValue)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.primary.opacity(0.1))
                    )
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 12)
    }

    private func categoryButton(_ category: ItemCategory?, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selectedCategory == category ? .semibold : .regular))
                .foregroundColor(selectedCategory == category ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                )
        }
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredOffers) { offer in
                    NavigationLink {
                        TradeOfferDetailView(offer: offer)
                    } label: {
                        TradeMarketOfferCard(offer: offer)
                    }
                    .buttonStyle(PlainButtonStyle())
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
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ApocalypseTheme.info.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "storefront")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.info.opacity(0.6))
            }

            Text(searchText.isEmpty && selectedCategory == nil ? "暂无可用挂单" : "没有找到匹配的挂单")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(searchText.isEmpty && selectedCategory == nil ? "等待其他幸存者发布挂单" : "尝试调整搜索条件")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 操作方法

    private func loadOffers() {
        Task {
            do {
                try await tradeManager.loadAvailableOffers()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshOffers() async {
        do {
            try await tradeManager.loadAvailableOffers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TradeMarketView()
    }
    .background(ApocalypseTheme.background)
}
