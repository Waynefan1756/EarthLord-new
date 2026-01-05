//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器：将 UIKit 的地图组件转换为 SwiftUI 视图
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable

struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Properties

    /// 用户位置（绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @Binding var hasLocatedUser: Bool

    /// 路径追踪坐标数组（绑定）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（用于触发更新）
    let pathUpdateVersion: Int

    /// 是否正在追踪
    let isTracking: Bool

    /// 路径是否已闭合
    let isPathClosed: Bool

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid                       // 卫星图+道路标签
        mapView.pointOfInterestFilter = .excludingAll   // 隐藏 POI 标签（星巴克、麦当劳等）
        mapView.showsBuildings = false                  // 隐藏 3D 建筑
        mapView.showsUserLocation = true                // ⭐ 显示用户位置蓝点（必须！）
        mapView.isZoomEnabled = true                    // 允许双指缩放
        mapView.isScrollEnabled = true                  // 允许单指拖动
        mapView.isRotateEnabled = true                  // 允许双指旋转
        mapView.isPitchEnabled = false                  // 禁止透视倾斜

        // ⭐ 设置代理（关键！用于接收位置更新）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新 MKMapView
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新追踪路径（pathUpdateVersion 变化时触发）
        updateTrackingPath(on: uiView)
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    /// 应用末世滤镜效果
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度，营造荒凉感
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey) // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey)   // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey)     // 中等强度的泛黄

        // 应用滤镜到地图图层
        if let controls = colorControls, let sepia = sepiaFilter {
            mapView.layer.filters = [controls, sepia]
        }
    }

    /// 更新追踪路径
    private func updateTrackingPath(on mapView: MKMapView) {
        // 移除所有旧的覆盖物（轨迹线和多边形）
        mapView.removeOverlays(mapView.overlays)

        // 如果没有路径点，直接返回
        guard !trackingPath.isEmpty else { return }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国地区偏移问题）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)

        // 创建轨迹线
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        mapView.addOverlay(polyline)

        // ⭐ 如果路径已闭合且点数 >= 3，添加多边形填充
        if isPathClosed && gcj02Coordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            mapView.addOverlay(polygon)
            print("🎨 轨迹已更新（已闭合），共 \(trackingPath.count) 个点，已添加多边形填充")
        } else {
            print("🎨 轨迹已更新，共 \(trackingPath.count) 个点")
        }
    }

    // MARK: - Coordinator

    /// 协调器：处理 MKMapView 的代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复居中）
        private var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 用户位置更新时调用（自动居中的关键方法！）
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经居中过，则不再自动居中（避免干扰用户手动拖动）
            guard !hasInitialCentered else { return }

            // 创建居中区域（约 1 公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,  // 纬度范围 1000 米
                longitudinalMeters: 1000  // 经度范围 1000 米
            )

            // ⭐ 平滑居中地图（animated: true 实现平滑过渡）
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("✅ 地图已自动居中到用户位置：\(location.coordinate.latitude), \(location.coordinate.longitude)")
        }

        /// 地图区域改变时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于追踪用户手动移动地图
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("✅ 地图加载完成")
        }

        /// 地图加载失败时调用
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("❌ 地图加载失败：\(error.localizedDescription)")
        }

        /// ⭐ 渲染覆盖物（轨迹线和多边形）- 关键方法！
        /// 如果不实现这个方法，轨迹添加了也看不见！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // ⭐ 根据路径是否闭合改变颜色
                if parent.isPathClosed {
                    renderer.strokeColor = UIColor.systemGreen  // 闭环后：绿色
                } else {
                    renderer.strokeColor = UIColor.systemCyan   // 追踪中：青色
                }

                renderer.lineWidth = 5                          // 线宽 5pt
                renderer.lineCap = .round                       // 圆头
                renderer.lineJoin = .round                      // 圆角连接
                return renderer
            }

            // ⭐ 渲染多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)  // 半透明绿色填充
                renderer.strokeColor = UIColor.systemGreen                         // 绿色边框
                renderer.lineWidth = 2
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
