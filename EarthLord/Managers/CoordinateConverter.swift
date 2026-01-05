//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具：WGS-84 → GCJ-02
//  解决中国地区 GPS 坐标偏移问题（火星坐标系）
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter

/// 坐标转换工具
/// 用途：将 GPS 硬件返回的 WGS-84 坐标转换为中国地图使用的 GCJ-02 坐标
struct CoordinateConverter {

    // MARK: - Constants

    /// 长半轴
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    // MARK: - Public Methods

    /// 将 WGS-84 坐标转换为 GCJ-02 坐标（火星坐标系）
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国加密坐标）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国境内，不进行转换
        if !isInChina(latitude: wgs84.latitude, longitude: wgs84.longitude) {
            return wgs84
        }

        var dLat = transformLatitude(x: wgs84.longitude - 105.0, y: wgs84.latitude - 35.0)
        var dLon = transformLongitude(x: wgs84.longitude - 105.0, y: wgs84.latitude - 35.0)

        let radLat = wgs84.latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)

        let gcj02Latitude = wgs84.latitude + dLat
        let gcj02Longitude = wgs84.longitude + dLon

        return CLLocationCoordinate2D(latitude: gcj02Latitude, longitude: gcj02Longitude)
    }

    /// 批量转换坐标数组
    /// - Parameter wgs84Coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ wgs84Coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return wgs84Coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国境内
    private static func isInChina(latitude: Double, longitude: Double) -> Bool {
        // 中国范围：纬度 0.8293 ~ 55.8271, 经度 72.004 ~ 137.8347
        return longitude >= 72.004 && longitude <= 137.8347 && latitude >= 0.8293 && latitude <= 55.8271
    }

    /// 纬度转换
    private static func transformLatitude(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLongitude(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}
