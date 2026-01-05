//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器：记录追踪、闭环、速度检测等日志，方便真机测试时查看
//

import Foundation
import SwiftUI
import Combine

// MARK: - LogType

/// 日志类型
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

    /// 日志颜色
    var color: Color {
        switch self {
        case .info:
            return ApocalypseTheme.textSecondary
        case .success:
            return .green
        case .warning:
            return ApocalypseTheme.warning
        case .error:
            return ApocalypseTheme.danger
        }
    }
}

// MARK: - LogEntry

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

// MARK: - TerritoryLogger

/// 圈地功能日志管理器（单例 + ObservableObject）
class TerritoryLogger: ObservableObject {

    // MARK: - Singleton

    static let shared = TerritoryLogger()

    private init() {}

    // MARK: - Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    // MARK: - Date Formatters

    /// 显示用时间格式化器（HH:mm:ss）
    private lazy var displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 导出用时间格式化器（yyyy-MM-dd HH:mm:ss）
    private lazy var exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        // 确保在主线程更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建日志条目
            let entry = LogEntry(timestamp: Date(), message: message, type: type)
            self.logs.append(entry)

            // 限制日志条数，超出时移除最旧的
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新格式化文本
            self.updateLogText()
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息和完整时间戳的日志文本
    func export() -> String {
        var result = "=== 圈地功能测试日志 ===\n"
        result += "导出时间: \(exportFormatter.string(from: Date()))\n"
        result += "日志条数: \(logs.count)\n"
        result += "\n"

        for entry in logs {
            let timestamp = exportFormatter.string(from: entry.timestamp)
            result += "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        return result
    }

    // MARK: - Private Methods

    /// 更新格式化的日志文本
    private func updateLogText() {
        logText = logs.map { entry in
            let timestamp = displayFormatter.string(from: entry.timestamp)
            return "[\(timestamp)] [\(entry.type.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
