//
//  SupabaseConfig.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/2.
//

import Foundation
import Supabase

/// 全局 Supabase 客户端实例
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://mlxrahhsuulzrssjtafq.supabase.co")!,
    supabaseKey: "sb_publishable_TFwuSbHslwmzezox3TUfZw_l7mO6mzV"
)
