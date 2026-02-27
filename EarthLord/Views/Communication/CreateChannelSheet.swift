//
//  CreateChannelSheet.swift
//  EarthLord
//
//  创建频道弹窗
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedType: ChannelType = .public
    @State private var channelName = ""
    @State private var channelDesc = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var canCreate: Bool {
        channelName.count >= 2 && channelName.count <= 50 && !isCreating
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 类型选择
                    typeSelector

                    // 名称输入
                    nameInput

                    // 描述输入
                    descInput

                    // 错误提示
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    // 创建按钮
                    createButton

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 类型选择

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("频道类型")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([ChannelType.public, .walkie, .camp, .satellite], id: \.rawValue) { type in
                        typeButton(type)
                    }
                }
                .padding(.horizontal, 2)
            }

            // 类型说明
            HStack(spacing: 8) {
                Image(systemName: selectedType.iconName)
                    .foregroundColor(ApocalypseTheme.primary)
                Text(selectedType.description)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(10)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(8)
        }
    }

    private func typeButton(_ type: ChannelType) -> some View {
        let isSelected = selectedType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedType = type }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.iconName)
                    .font(.system(size: 20))
                Text(type.displayName)
                    .font(.caption).fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - 名称输入

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道名称")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
                Text("\(channelName.count)/50")
                    .font(.caption)
                    .foregroundColor(channelName.count > 50 ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
            }
            TextField("2-50个字符", text: $channelName)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
        }
    }

    // MARK: - 描述输入

    private var descInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("频道描述（可选）")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textSecondary)
            ZStack(alignment: .topLeading) {
                if channelDesc.isEmpty {
                    Text("简单介绍一下这个频道...")
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
                        .padding(12)
                }
                TextEditor(text: $channelDesc)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(minHeight: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - 创建按钮

    private var createButton: some View {
        Button {
            Task { await performCreate() }
        } label: {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isCreating ? "创建中..." : "创建频道")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreate)
    }

    // MARK: - 创建逻辑

    private func performCreate() async {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "未登录，请重新登录"
            return
        }
        guard channelName.count >= 2 else {
            errorMessage = "频道名称至少需要2个字符"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            try await communicationManager.createChannel(
                userId: userId,
                type: selectedType,
                name: channelName.trimmingCharacters(in: .whitespaces),
                description: channelDesc.isEmpty ? nil : channelDesc.trimmingCharacters(in: .whitespaces)
            )
            dismiss()
        } catch {
            errorMessage = "创建失败：\(error.localizedDescription)"
        }

        isCreating = false
    }
}

// MARK: - Preview

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager(supabase: supabase))
}
