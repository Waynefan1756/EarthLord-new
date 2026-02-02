//
//  CategoryButton.swift
//  EarthLord
//
//  分类按钮组件
//  支持生存/存储/生产/能源分类，支持选中状态
//

import SwiftUI

struct CategoryButton: View {

    // MARK: - Properties

    let category: BuildingCategory
    let isSelected: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.system(size: 20))

                Text(category.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Selector

struct CategorySelector: View {

    @Binding var selectedCategory: BuildingCategory?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BuildingCategory.allCases, id: \.self) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategory == category
                ) {
                    if selectedCategory == category {
                        selectedCategory = nil
                    } else {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CategorySelector(selectedCategory: .constant(.survival))
        CategorySelector(selectedCategory: .constant(nil))
    }
    .padding(.vertical)
    .background(ApocalypseTheme.background)
}
