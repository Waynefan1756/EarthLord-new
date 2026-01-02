//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/2.
//

import SwiftUI
import Supabase

// MARK: - 测试视图
struct SupabaseTestView: View {
    // MARK: - State
    @State private var isConnected: Bool? = nil
    @State private var debugLog: String = "点击按钮开始测试..."
    @State private var isTesting: Bool = false

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 120, height: 120)
                        .shadow(color: statusBackgroundColor.opacity(0.5), radius: 20)

                    Image(systemName: statusIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)

                // 连接信息
                VStack(spacing: 8) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("mlxrahhsuulzrssjtafq.supabase.co")
                        .font(.footnote)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                }

                // 调试日志
                ScrollView {
                    Text(debugLog)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }
                .frame(height: 200)
                .padding(.horizontal)

                // 测试按钮
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                                .font(.headline)
                        }

                        Text(isTesting ? "测试中..." : "测试连接")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)
                }
                .disabled(isTesting)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        if let connected = isConnected {
            return connected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        }
        return "questionmark.circle.fill"
    }

    private var statusBackgroundColor: Color {
        if let connected = isConnected {
            return connected ? ApocalypseTheme.success : ApocalypseTheme.danger
        }
        return ApocalypseTheme.textMuted
    }

    // MARK: - 测试连接方法

    private func testConnection() {
        isTesting = true
        debugLog = "开始连接测试...\n"

        Task {
            do {
                debugLog += "正在发送请求到 Supabase...\n"

                // 故意查询不存在的表来测试连接
                let _: [String] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果执行到这里，说明表存在（不太可能）
                await updateStatus(connected: true, message: "✅ 连接成功（意外：表存在）")

            } catch {
                // 分析错误信息
                let errorMessage = error.localizedDescription
                debugLog += "收到响应：\(errorMessage)\n\n"

                // 判断错误类型
                if errorMessage.contains("PGRST") ||
                   errorMessage.contains("Could not find the table") ||
                   errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                    // PostgreSQL 错误 = 连接成功，只是表不存在
                    await updateStatus(
                        connected: true,
                        message: "✅ 连接成功（服务器已响应）\n数据库正常工作，表'non_existent_table'不存在（符合预期）"
                    )

                } else if errorMessage.contains("hostname") ||
                          errorMessage.contains("URL") ||
                          errorMessage.contains("NSURLErrorDomain") ||
                          errorMessage.contains("network") {
                    // 网络或 URL 错误
                    await updateStatus(
                        connected: false,
                        message: "❌ 连接失败：URL错误或无网络\n\n详细信息：\n\(errorMessage)"
                    )

                } else {
                    // 其他未知错误
                    await updateStatus(
                        connected: false,
                        message: "❌ 未知错误\n\n详细信息：\n\(errorMessage)"
                    )
                }
            }

            await MainActor.run {
                isTesting = false
            }
        }
    }

    // MARK: - 更新状态

    @MainActor
    private func updateStatus(connected: Bool, message: String) {
        isConnected = connected
        debugLog += "\n" + message
    }
}

#Preview {
    SupabaseTestView()
}
