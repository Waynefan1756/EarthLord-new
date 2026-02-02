//
//  TerritoryToolbarView.swift
//  EarthLord
//
//  悬浮工具栏
//  包含返回按钮、标题、更多菜单（重命名/建造/删除）
//

import SwiftUI

struct TerritoryToolbarView: View {

    // MARK: - Properties

    let title: String
    let onBack: () -> Void
    let onRename: () -> Void
    let onBuild: () -> Void
    let onDelete: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // 返回按钮
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(ApocalypseTheme.cardBackground.opacity(0.9))
                    .clipShape(Circle())
            }

            // 标题
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

            Spacer()

            // 更多菜单
            Menu {
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }

                Button(action: onBuild) {
                    Label("建造", systemImage: "hammer.fill")
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("删除领地", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(ApocalypseTheme.cardBackground.opacity(0.9))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray
            .ignoresSafeArea()

        VStack {
            TerritoryToolbarView(
                title: "我的领地",
                onBack: {},
                onRename: {},
                onBuild: {},
                onDelete: {}
            )

            Spacer()
        }
    }
}
