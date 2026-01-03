//
//  LanguageSelectionView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/3.
//

import SwiftUI

/// 语言选择视图
struct LanguageSelectionView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 语言选项列表
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageRow(
                            language: language,
                            isSelected: languageManager.currentLanguage == language
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                languageManager.currentLanguage = language
                            }

                            // 延迟关闭页面，让用户看到选中效果
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                dismiss()
                            }
                        }

                        if language != AppLanguage.allCases.last {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()
            }
        }
        .navigationTitle(NSLocalizedString("语言设置", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 语言选项行
struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 语言图标
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundColor(.green)
                    .frame(width: 24)

                // 语言名称
                Text(language.displayName)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
            .environmentObject(LanguageManager.shared)
    }
}
