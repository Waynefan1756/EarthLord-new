//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器
//  封装 Edge Function 调用，支持降级方案
//

import Foundation

/// AI 物品生成器
/// 调用 Supabase Edge Function 生成 AI 物品
actor AIItemGenerator {

    // MARK: - Singleton

    static let shared = AIItemGenerator()

    private init() {}

    // MARK: - Configuration

    /// Edge Function URL
    private let functionURL = "https://mlxrahhsuulzrssjtafq.supabase.co/functions/v1/generate-ai-item"

    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = 30

    // MARK: - Public Methods

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 要搜刮的 POI
    ///   - itemCount: 生成的物品数量（1-5）
    /// - Returns: 生成的物品列表
    /// - Throws: AIGeneratorError
    func generateItems(for poi: ExplorablePOI, itemCount: Int = 3) async throws -> [AIGeneratedItem] {
        // 构建请求
        let request = AIGenerateRequest(
            poi: AIGenerateRequest.POIContext(
                name: poi.name,
                type: poi.type.rawValue,
                dangerLevel: poi.dangerLevel
            ),
            itemCount: min(max(itemCount, 1), 5)  // 限制在 1-5 之间
        )

        // 创建 URL 请求
        guard let url = URL(string: functionURL) else {
            throw AIGeneratorError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = requestTimeout

        // 编码请求体
        let encoder = JSONEncoder()
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AIGeneratorError.encodingError(error)
        }

        // 发送请求
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw AIGeneratorError.timeout
            }
            throw AIGeneratorError.networkError(urlError)
        } catch {
            throw AIGeneratorError.networkError(error)
        }

        // 检查 HTTP 响应状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIGeneratorError.invalidResponse
        }

        // 解析响应
        let decoder = JSONDecoder()
        let aiResponse: AIGenerateResponse

        do {
            aiResponse = try decoder.decode(AIGenerateResponse.self, from: data)
        } catch {
            // 尝试解析错误响应
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorJson["error"] as? String {
                throw AIGeneratorError.serverError(errorMsg)
            }
            throw AIGeneratorError.decodingError(error)
        }

        // 检查业务错误
        if let error = aiResponse.error {
            throw AIGeneratorError.serverError(error)
        }

        // HTTP 状态码检查
        guard httpResponse.statusCode == 200 else {
            throw AIGeneratorError.httpError(httpResponse.statusCode)
        }

        // 检查是否有物品返回
        guard !aiResponse.items.isEmpty else {
            throw AIGeneratorError.emptyResponse
        }

        print("[AIItemGenerator] 成功生成 \(aiResponse.items.count) 个物品")
        return aiResponse.items
    }
}

// MARK: - Error Types

/// AI 生成器错误
enum AIGeneratorError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case networkError(Error)
    case encodingError(Error)
    case decodingError(Error)
    case timeout
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的服务器地址"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let code):
            return "服务器错误: \(code)"
        case .serverError(let message):
            return "AI 生成失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .encodingError:
            return "请求编码失败"
        case .decodingError:
            return "响应解析失败"
        case .timeout:
            return "请求超时"
        case .emptyResponse:
            return "AI 未生成任何物品"
        }
    }
}
