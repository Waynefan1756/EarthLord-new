//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地测试界面：显示路径追踪、闭环检测、速度验证的实时日志
//

import SwiftUI

struct TerritoryTestView: View {

    // MARK: - Properties

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator

            Divider()

            // 日志滚动区域
            logScrollView

            Divider()

            // 操作按钮
            actionButtons
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
        .background(ApocalypseTheme.background)
    }

    // MARK: - Subviews

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // 状态点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 点数统计
            if locationManager.isTracking {
                Text("\(locationManager.pathCoordinates.count) 个点")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logs.isEmpty {
                        // 空状态提示
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 48))
                                .foregroundColor(ApocalypseTheme.textMuted)

                            Text("暂无日志")
                                .font(.system(size: 16))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("在「地图」页面开始圈地，日志将在此显示")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // 日志列表
                        ForEach(logger.logs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                // 时间戳
                                Text(formatTimestamp(entry.timestamp))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(ApocalypseTheme.textMuted)
                                    .frame(width: 70, alignment: .leading)

                                // 类型标签
                                Text("[\(entry.type.rawValue)]")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(entry.type.color)
                                    .frame(width: 80, alignment: .leading)

                                // 消息内容
                                Text(entry.message)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .id(entry.id)
                        }
                    }
                }
            }
            .onChange(of: logger.logText) { _ in
                // 自动滚动到最新日志
                if let lastLog = logger.logs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // 清空日志按钮
            Button(action: {
                logger.clear()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))

                    Text("清空日志")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.danger)
                .cornerRadius(10)
            }

            // 导出日志按钮
            ShareLink(
                item: logger.export(),
                preview: SharePreview("圈地测试日志", icon: "map.fill")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14))

                    Text("导出日志")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - Helper Methods

    /// 格式化时间戳
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
