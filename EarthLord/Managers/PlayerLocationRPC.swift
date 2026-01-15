//
//  PlayerLocationRPC.swift
//  EarthLord
//
//  玩家位置数据库操作
//  上报使用直接表操作，查询使用RPC函数（保护隐私）
//

import Foundation
@preconcurrency import Supabase

// MARK: - 数据模型

/// 插入/更新位置的请求模型
struct UpsertLocationRequest: Codable, Sendable {
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let lastReportedAt: Date
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case latitude
        case longitude
        case lastReportedAt = "last_reported_at"
        case isOnline = "is_online"
    }
}

/// 更新在线状态的请求模型
struct UpdateOnlineStatusRequest: Codable, Sendable {
    let isOnline: Bool
    let lastReportedAt: Date

    enum CodingKeys: String, CodingKey {
        case isOnline = "is_online"
        case lastReportedAt = "last_reported_at"
    }
}

// MARK: - 数据库操作函数

/// 上报玩家位置（使用upsert）
func executeUpsertLocationRPC(
    client: SupabaseClient,
    lat: Double,
    lon: Double,
    isOnline: Bool
) async throws {
    guard let userId = client.auth.currentUser?.id else {
        print("❌ [位置上报] 用户未登录")
        throw PlayerLocationError.notAuthenticated
    }

    print("📍 [位置上报] 开始上报: lat=\(lat), lon=\(lon), online=\(isOnline)")

    let request = UpsertLocationRequest(
        userId: userId,
        latitude: lat,
        longitude: lon,
        lastReportedAt: Date(),
        isOnline: isOnline
    )

    try await client
        .from("player_locations")
        .upsert(request, onConflict: "user_id")
        .execute()

    print("✅ [位置上报] 成功")
}

/// 查询附近玩家数量
/// 调用数据库函数 get_nearby_player_count（绕过RLS，保护隐私）
/// 使用原始 SQL 查询方式避免 Swift 并发类型问题
func executeNearbyPlayerQueryRPC(
    client: SupabaseClient,
    lat: Double,
    lon: Double,
    radiusMeters: Double,
    activeMinutes: Int
) async throws -> Int {
    guard client.auth.currentUser != nil else {
        print("❌ [RPC] 用户未登录，无法查询附近玩家")
        throw PlayerLocationError.notAuthenticated
    }

    print("📡 [RPC] 开始调用 get_nearby_player_count")
    print("  参数: lat=\(lat), lon=\(lon), radius=\(radiusMeters), minutes=\(activeMinutes)")

    // 使用 AnyJSON 字典避免 Encodable 结构体的 main actor 隔离问题
    let response: Int = try await client
        .rpc("get_nearby_player_count", params: [
            "p_lat": AnyJSON.double(lat),
            "p_lon": AnyJSON.double(lon),
            "p_radius_meters": AnyJSON.double(radiusMeters),
            "p_active_minutes": AnyJSON.integer(activeMinutes)
        ])
        .execute()
        .value

    print("✅ [RPC] 查询成功，结果: \(response)")
    return response
}

/// 标记玩家离线
func executeMarkOfflineRPC(client: SupabaseClient) async throws {
    guard let userId = client.auth.currentUser?.id else {
        throw PlayerLocationError.notAuthenticated
    }

    let request = UpdateOnlineStatusRequest(
        isOnline: false,
        lastReportedAt: Date()
    )

    try await client
        .from("player_locations")
        .update(request)
        .eq("user_id", value: userId.uuidString)
        .execute()
}

// MARK: - 错误类型

enum PlayerLocationError: Error, LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        }
    }
}
