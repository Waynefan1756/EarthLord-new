//
//  CreateOfferView.swift
//  EarthLord
//
//  发布挂单页面
//  选择要交换的物品、设置有效期和留言
//

import SwiftUI

/// 有效期选项
enum ExpirationOption: Int, CaseIterable {
    case hours1 = 1
    case hours6 = 6
    case hours12 = 12
    case hours24 = 24
    case hours48 = 48
    case hours72 = 72

    var displayName: String {
        switch self {
        case .hours1: return "1小时"
        case .hours6: return "6小时"
        case .hours12: return "12小时"
        case .hours24: return "24小时"
        case .hours48: return "48小时"
        case .hours72: return "72小时"
        }
    }
}

/// 发布挂单视图
struct CreateOfferView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tradeManager: TradeManager
    @EnvironmentObject var inventoryManager: InventoryManager

    // MARK: 状态

    /// 我要出的物品
    @State private var offeringItems: [TradeItem] = []

    /// 我想要的物品
    @State private var requestingItems: [TradeItem] = []

    /// 有效期
    @State private var expiration: ExpirationOption = .hours24

    /// 留言
    @State private var message: String = ""

    /// 是否显示物品选择器
    @State private var showItemPicker: Bool = false

    /// 物品选择器模式
    @State private var pickerMode: ItemPickerMode = .fromBackpack

    /// 是否正在发布
    @State private var isPublishing: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 是否可以发布
    private var canPublish: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 我要出的物品
                        offeringSection

                        // 我想要的物品
                        requestingSection

                        // 有效期选择
                        expirationSection

                        // 留言
                        messageSection

                        // 错误提示
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.danger)
                                .padding(.horizontal, 16)
                        }

                        // 发布按钮
                        publishButton
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("发布挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showItemPicker) {
                ItemPickerView(mode: pickerMode) { item in
                    addItem(item)
                }
            }
        }
    }

    // MARK: - 我要出的物品区

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Label("我要出的物品", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.success)

                Spacer()

                Button {
                    pickerMode = .fromBackpack
                    showItemPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 物品列表
            if offeringItems.isEmpty {
                emptyItemsPlaceholder(text: "从背包中选择要交换的物品")
            } else {
                ForEach(offeringItems) { item in
                    itemRow(item, isOffering: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 我想要的物品区

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Label("我想要的物品", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.info)

                Spacer()

                Button {
                    pickerMode = .fromCatalog
                    showItemPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            // 物品列表
            if requestingItems.isEmpty {
                emptyItemsPlaceholder(text: "选择您想要交换获得的物品")
            } else {
                ForEach(requestingItems) { item in
                    itemRow(item, isOffering: false)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 空物品占位符

    private func emptyItemsPlaceholder(text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "cube.box")
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    // MARK: - 物品行

    private func itemRow(_ item: TradeItem, isOffering: Bool) -> some View {
        HStack(spacing: 12) {
            TradeItemRow(tradeItem: item)

            // 删除按钮
            Button {
                removeItem(item, isOffering: isOffering)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.danger.opacity(0.8))
            }
        }
    }

    // MARK: - 有效期选择

    private var expirationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("有效期")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExpirationOption.allCases, id: \.self) { option in
                        Button {
                            expiration = option
                        } label: {
                            Text(option.displayName)
                                .font(.system(size: 14, weight: expiration == option ? .semibold : .regular))
                                .foregroundColor(expiration == option ? .white : ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(expiration == option ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                                )
                        }
                    }
                }
            }

            Text("超过有效期后挂单将自动取消，物品将退回背包")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 留言区

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("留言")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("(可选)")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            TextField("添加留言，如交易说明、可议价等...", text: $message, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(3...5)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.background)
                )

            Text("\(message.count) / 100")
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

    // MARK: - 发布按钮

    private var publishButton: some View {
        Button {
            publishOffer()
        } label: {
            HStack(spacing: 8) {
                if isPublishing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }

                Text("发布挂单")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canPublish ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canPublish || isPublishing)
    }

    // MARK: - 操作方法

    private func addItem(_ item: TradeItem) {
        if pickerMode == .fromBackpack {
            // 检查是否已添加相同物品
            if let index = offeringItems.firstIndex(where: { $0.itemId == item.itemId && $0.quality == item.quality }) {
                // 更新数量
                let existing = offeringItems[index]
                let newQuantity = existing.quantity + item.quantity
                offeringItems[index] = TradeItem(
                    id: existing.id,
                    itemId: existing.itemId,
                    quantity: newQuantity,
                    quality: existing.quality
                )
            } else {
                offeringItems.append(item)
            }
        } else {
            // 检查是否已添加相同物品
            if let index = requestingItems.firstIndex(where: { $0.itemId == item.itemId && $0.quality == item.quality }) {
                let existing = requestingItems[index]
                let newQuantity = existing.quantity + item.quantity
                requestingItems[index] = TradeItem(
                    id: existing.id,
                    itemId: existing.itemId,
                    quantity: newQuantity,
                    quality: existing.quality
                )
            } else {
                requestingItems.append(item)
            }
        }
    }

    private func removeItem(_ item: TradeItem, isOffering: Bool) {
        if isOffering {
            offeringItems.removeAll { $0.id == item.id }
        } else {
            requestingItems.removeAll { $0.id == item.id }
        }
    }

    private func publishOffer() {
        guard canPublish else { return }

        isPublishing = true
        errorMessage = nil

        // 限制留言长度
        let finalMessage = message.isEmpty ? nil : String(message.prefix(100))

        Task {
            do {
                _ = try await tradeManager.createOffer(
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    message: finalMessage,
                    expirationHours: expiration.rawValue
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isPublishing = false
        }
    }
}

// MARK: - Preview

#Preview {
    CreateOfferView()
}
