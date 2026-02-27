//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//  包含设备类型、设备模型、导航分段等定义
//

import Foundation

// MARK: - 设备类型

/// 通讯设备类型
enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    /// 显示名称
    var displayName: String {
        switch self {
        case .radio: return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio: return "营地电台"
        case .satellite: return "卫星通讯"
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "phone.badge.waveform"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    /// 设备描述
    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio: return "可在30公里范围内广播"
        case .satellite: return "可在100公里+范围内联络"
        }
    }

    /// 通讯范围（公里）
    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    /// 通讯范围文字描述
    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    /// 是否可以发送消息
    var canSend: Bool {
        self != .radio
    }

    /// 解锁条件描述
    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio: return "需建造「营地电台」建筑"
        case .satellite: return "需建造「通讯塔」建筑"
        }
    }
}

// MARK: - 设备模型

/// 通讯设备
struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 导航分段

/// 通讯系统导航分段
enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    /// 图标名称
    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 频道类型

/// 频道类型枚举
enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case `public` = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方"
        case .public: return "公开"
        case .walkie: return "对讲"
        case .camp: return "营地"
        case .satellite: return "卫星"
        }
    }

    var iconName: String {
        switch self {
        case .official: return "star.circle.fill"
        case .public: return "megaphone.fill"
        case .walkie: return "phone.badge.waveform"
        case .camp: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .official: return "官方发布的权威频道"
        case .public: return "任何人均可订阅的公开频道"
        case .walkie: return "对讲机频道，限3公里范围"
        case .camp: return "营地内部通讯频道"
        case .satellite: return "卫星通讯频道，覆盖100公里+"
        }
    }
}

// MARK: - 频道模型

/// 通讯频道
struct CommunicationChannel: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    var isActive: Bool
    var memberCount: Int
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 订阅记录

/// 频道订阅记录
struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    var isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道（频道+订阅信息组合）

/// 包含频道信息和订阅记录的组合模型
struct SubscribedChannel: Identifiable {
    var id: UUID { channel.id }
    let channel: CommunicationChannel
    let subscription: ChannelSubscription
}

// MARK: - 消息元数据

struct MessageMetadata: Codable {
    let deviceType: String?
    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
    }
}

// MARK: - 位置点（PostGIS WKT 解析）

struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    /// 从 PostGIS WKT 字符串解析，如 "POINT(lon lat)"
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        let trimmed = wkt.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("POINT(") || trimmed.hasPrefix("POINT (") else { return nil }
        let inner = trimmed
            .replacingOccurrences(of: "POINT(", with: "")
            .replacingOccurrences(of: "POINT (", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespaces)
        let parts = inner.split(separator: " ")
        guard parts.count == 2,
              let lon = Double(parts[0]),
              let lat = Double(parts[1]) else { return nil }
        return LocationPoint(latitude: lat, longitude: lon)
    }
}

// MARK: - 频道消息

struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let createdAt: Date

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation = "sender_location"
        case metadata
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // PostGIS geography 字段：尝试作为字符串解析 WKT
        if let wkt = (try? container.decodeIfPresent(String.self, forKey: .senderLocation)) ?? nil {
            senderLocation = LocationPoint.fromPostGIS(wkt)
        } else {
            senderLocation = nil
        }

        // 多格式日期解析
        let dateString = try container.decode(String.self, forKey: .createdAt)
        if let date = ChannelMessage.parseDate(dateString) {
            createdAt = date
        } else {
            createdAt = Date()
        }
    }

    static func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = {
            let iso = DateFormatter()
            iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
            iso.locale = Locale(identifier: "en_US_POSIX")
            let isoShort = DateFormatter()
            isoShort.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
            isoShort.locale = Locale(identifier: "en_US_POSIX")
            return [iso, isoShort]
        }()
        for f in formatters {
            if let d = f.date(from: string) { return d }
        }
        return ISO8601DateFormatter().date(from: string)
    }

    /// 相对时间描述
    var timeAgo: String {
        let diff = Date().timeIntervalSince(createdAt)
        switch diff {
        case ..<60: return "刚刚"
        case ..<3600: return "\(Int(diff / 60)) 分钟前"
        case ..<86400: return "\(Int(diff / 3600)) 小时前"
        default: return "\(Int(diff / 86400)) 天前"
        }
    }
}
