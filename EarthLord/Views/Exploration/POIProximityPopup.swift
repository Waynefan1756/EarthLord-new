//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI接近弹窗视图
//  当用户进入POI 50米范围内时显示，提示用户搜刮物资
//

import SwiftUI
import CoreLocation

struct POIProximityPopup: View {

    // MARK: - Properties

    /// 当前POI
    let poi: ExplorablePOI

    /// 搜刮回调
    let onScavenge: () -> Void

    /// 跳过回调
    let onSkip: () -> Void

    /// 动画状态
    @State private var showContent: Bool = false
    @State private var pulseAnimation: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            // 主内容
            VStack(spacing: 20) {
                // POI图标（带脉冲动画）
                ZStack {
                    // 脉冲圆环
                    Circle()
                        .stroke(poi.type.themeColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.6)

                    // 图标背景
                    Circle()
                        .fill(poi.type.themeColor.opacity(0.2))
                        .frame(width: 70, height: 70)

                    // 图标
                    Image(systemName: poi.type.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(poi.type.themeColor)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        pulseAnimation = true
                    }
                }

                // POI信息
                VStack(spacing: 8) {
                    Text("发现地点")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(poi.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(poi.type.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(poi.type.themeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(poi.type.themeColor.opacity(0.15))
                        )
                }

                // 提示文字
                Text("你已进入该地点的搜刮范围")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

                // 按钮组
                HStack(spacing: 16) {
                    // 跳过按钮
                    Button(action: onSkip) {
                        Text("稍后再说")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ApocalypseTheme.cardBackground)
                            )
                    }

                    // 搜刮按钮
                    Button(action: onScavenge) {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 16))
                            Text("搜刮物资")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
            }
            .padding(24)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.background)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    POIProximityPopup(
        poi: ExplorablePOI(
            id: "test_poi",
            name: "测试超市",
            type: .supermarket,
            coordinate: .init(latitude: 31.23, longitude: 121.47),
            isScavenged: false
        ),
        onScavenge: {},
        onSkip: {}
    )
    .preferredColorScheme(.dark)
}
