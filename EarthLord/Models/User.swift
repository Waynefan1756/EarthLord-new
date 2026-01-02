//
//  User.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/2.
//

import Foundation

/// 用户数据模型
struct User: Codable, Identifiable {
    let id: UUID
    let username: String
    let avatarUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}
