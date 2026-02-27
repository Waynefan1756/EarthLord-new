//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯系统管理器
//  管理通讯设备的加载、切换、解锁等操作
//

import Foundation
import Combine
import Supabase

// MARK: - 设备解锁更新模型

/// 设备解锁更新请求（用于 Supabase 更新操作）
private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}

// MARK: - 通讯管理器

/// 通讯系统管理器
/// 管理通讯设备的加载、切换、解锁等操作
@MainActor
final class CommunicationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = CommunicationManager()

    // MARK: - Published Properties

    /// 用户拥有的所有设备
    @Published private(set) var devices: [CommunicationDevice] = []

    /// 当前使用的设备
    @Published private(set) var currentDevice: CommunicationDevice?

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let client = supabase

    // MARK: - Initialization

    private init() {}

    // MARK: - 加载设备

    /// 加载用户的所有通讯设备
    /// - Parameter userId: 用户ID
    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await client
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            // 如果没有设备记录，执行初始化
            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    /// 初始化用户默认设备（首次使用时调用）
    /// - Parameter userId: 用户ID
    func initializeDevices(userId: UUID) async {
        do {
            try await client
                .rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString])
                .execute()

            // 初始化后重新加载
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    /// 切换当前使用的通讯设备
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - deviceType: 目标设备类型
    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        // 验证设备已解锁
        guard let device = devices.first(where: { $0.deviceType == deviceType }),
              device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        // 已经是当前设备则跳过
        if device.isCurrent { return }

        isLoading = true

        do {
            try await client
                .rpc("switch_current_device", params: [
                    "p_user_id": userId.uuidString,
                    "p_device_type": deviceType.rawValue
                ])
                .execute()

            // 更新本地状态
            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 解锁设备

    /// 解锁通讯设备（由建造系统调用）
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - deviceType: 要解锁的设备类型
    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            // 更新本地状态
            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷查询方法

    /// 获取当前设备类型
    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    /// 当前设备是否可以发送消息
    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    /// 获取当前设备通讯范围（公里）
    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    /// 检查指定设备是否已解锁
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 频道属性

    /// 公开频道列表
    @Published var channels: [CommunicationChannel] = []

    /// 我的已订阅频道（含订阅信息）
    @Published var subscribedChannels: [SubscribedChannel] = []

    /// 我的订阅记录
    @Published var mySubscriptions: [ChannelSubscription] = []

    // MARK: - 频道方法

    /// 加载所有活跃的公开频道
    func loadPublicChannels() async {
        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            channels = response
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }
    }

    /// 加载用户已订阅的频道
    /// - Parameter userId: 用户ID
    func loadSubscribedChannels(userId: UUID) async {
        do {
            let subs: [ChannelSubscription] = try await client
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            mySubscriptions = subs

            // 根据订阅记录加载频道详情
            let channelIds = subs.map { $0.channelId.uuidString }
            if channelIds.isEmpty {
                subscribedChannels = []
                return
            }

            let channelList: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
                .value

            subscribedChannels = channelList.compactMap { ch in
                guard let sub = subs.first(where: { $0.channelId == ch.id }) else { return nil }
                return SubscribedChannel(channel: ch, subscription: sub)
            }
        } catch {
            errorMessage = "加载订阅频道失败: \(error.localizedDescription)"
        }
    }

    /// 创建频道（自动订阅创建者）
    /// - Parameters:
    ///   - userId: 创建者ID
    ///   - type: 频道类型
    ///   - name: 频道名称
    ///   - description: 频道描述
    func createChannel(userId: UUID, type: ChannelType, name: String, description: String?) async throws {
        let params: [String: AnyJSON] = [
            "p_creator_id": .string(userId.uuidString),
            "p_channel_type": .string(type.rawValue),
            "p_name": .string(name),
            "p_description": description.map { .string($0) } ?? .null
        ]

        try await client
            .rpc("create_channel_with_subscription", params: params)
            .execute()

        // 刷新列表
        await loadPublicChannels()
        await loadSubscribedChannels(userId: userId)
    }

    /// 订阅频道
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - channelId: 频道ID
    func subscribeToChannel(userId: UUID, channelId: UUID) async throws {
        struct SubscribeInsert: Encodable {
            let userId: UUID
            let channelId: UUID
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case channelId = "channel_id"
            }
        }

        try await client
            .from("channel_subscriptions")
            .insert(SubscribeInsert(userId: userId, channelId: channelId))
            .execute()

        await loadSubscribedChannels(userId: userId)
    }

    /// 取消订阅频道
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - channelId: 频道ID
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async throws {
        try await client
            .from("channel_subscriptions")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("channel_id", value: channelId.uuidString)
            .execute()

        mySubscriptions.removeAll { $0.channelId == channelId }
        subscribedChannels.removeAll { $0.channel.id == channelId }
    }

    /// 检查是否已订阅某频道
    /// - Parameter channelId: 频道ID
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    /// 删除频道（仅限创建者）
    /// - Parameter channelId: 频道ID
    func deleteChannel(channelId: UUID) async throws {
        try await client
            .from("communication_channels")
            .delete()
            .eq("id", value: channelId.uuidString)
            .execute()

        channels.removeAll { $0.id == channelId }
        subscribedChannels.removeAll { $0.channel.id == channelId }
    }

    // MARK: - 消息属性

    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published var isSendingMessage = false
    @Published var subscribedChannelIds: Set<UUID> = []
    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?

    // MARK: - 消息方法

    /// 加载频道历史消息（最新 50 条，按时间升序）
    func loadChannelMessages(channelId: UUID) async {
        do {
            let response: [ChannelMessage] = try await client
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value
            channelMessages[channelId] = response
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }

    /// 发送频道消息（通过 RPC）
    @discardableResult
    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        deviceType: String? = nil
    ) async -> Bool {
        isSendingMessage = true
        defer { isSendingMessage = false }

        var params: [String: AnyJSON] = [
            "p_channel_id": .string(channelId.uuidString),
            "p_content": .string(content)
        ]
        if let lat = latitude { params["p_latitude"] = .double(lat) }
        if let lon = longitude { params["p_longitude"] = .double(lon) }
        if let dt = deviceType { params["p_device_type"] = .string(dt) }

        do {
            try await client
                .rpc("send_channel_message", params: params)
                .execute()
            // RPC 成功后主动刷新消息列表，作为 Realtime 的保底
            await loadChannelMessages(channelId: channelId)
            return true
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            return false
        }
    }

    /// 启动 Realtime 订阅（监听所有已订阅频道的新消息）
    func startRealtimeSubscription() {
        guard realtimeChannel == nil else { return }

        let channel = client.realtimeV2.channel("channel_messages_realtime")
        realtimeChannel = channel

        messageSubscriptionTask = Task {
            try? await channel.subscribeWithError()
            let changes = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "channel_messages"
            )
            for await insertion in changes {
                await handleNewMessage(insertion: insertion)
            }
        }
    }

    /// 停止 Realtime 订阅
    func stopRealtimeSubscription() {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil
        if let ch = realtimeChannel {
            Task { await ch.unsubscribe() }
        }
        realtimeChannel = nil
    }

    /// 处理 Realtime 新消息插入事件
    private func handleNewMessage(insertion: InsertAction) async {
        let decoder = JSONDecoder()
        guard let message = try? insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder) else { return }
        guard subscribedChannelIds.contains(message.channelId) else { return }
        var list = channelMessages[message.channelId] ?? []
        list.append(message)
        channelMessages[message.channelId] = list
    }

    /// 为指定频道注册消息订阅（并按需启动 Realtime）
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
        if realtimeChannel == nil {
            startRealtimeSubscription()
        }
    }

    /// 取消指定频道的消息订阅（无订阅时停止 Realtime）
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        channelMessages.removeValue(forKey: channelId)
        if subscribedChannelIds.isEmpty {
            stopRealtimeSubscription()
        }
    }

    /// 获取指定频道的消息列表
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }
}
