//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器：将 UIKit 的地图组件转换为 SwiftUI 视图
//

import SwiftUI
import MapKit

// MARK: - POIAnnotation

/// POI 地图标注
class POIAnnotation: NSObject, MKAnnotation {
    let poi: ExplorablePOI
    let coordinate: CLLocationCoordinate2D

    var title: String? { poi.name }
    var subtitle: String? { poi.type.displayName }

    init(poi: ExplorablePOI, coordinate: CLLocationCoordinate2D) {
        self.poi = poi
        self.coordinate = coordinate
        super.init()
    }
}

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

    /// 已加载的领地列表
    let territories: [Territory]

    /// 当前用户 ID
    let currentUserId: String?

    // MARK: - 探索路径相关

    /// 探索路径坐标数组
    let explorationPath: [CLLocationCoordinate2D]

    /// 探索路径更新版本号
    let explorationPathVersion: Int

    /// 是否正在探索
    let isExploring: Bool

    // MARK: - POI 标注相关

    /// 附近POI列表
    let nearbyPOIs: [ExplorablePOI]

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

        // 绘制领地
        drawTerritories(on: uiView)

        // 绘制探索路径
        updateExplorationPath(on: uiView)

        // 更新POI标注
        updatePOIAnnotations(on: uiView)
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

    /// 绘制领地
    private func drawTerritories(on mapView: MKMapView) {
        // 移除旧的领地多边形（保留路径轨迹）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 绘制每个领地
        for territory in territories {
            var coords = territory.toCoordinates()

            // ⚠️ 中国大陆需要坐标转换
            coords = CoordinateConverter.wgs84ToGcj02(coords)

            guard coords.count >= 3 else { continue }

            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
            // 如果不转换，会导致自己的领地显示为橙色
            let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            mapView.addOverlay(polygon, level: .aboveRoads)
        }

        print("🎨 绘制了 \(territories.count) 个领地")
    }

    /// 更新追踪路径
    private func updateTrackingPath(on mapView: MKMapView) {
        // 移除当前追踪的轨迹线和多边形（保留领地多边形）
        let trackingOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                // 只移除没有 title 的多边形（当前追踪的多边形）
                return polygon.title == nil
            }
            // 移除所有轨迹线
            return overlay is MKPolyline
        }
        mapView.removeOverlays(trackingOverlays)

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

    /// 更新探索路径
    private func updateExplorationPath(on mapView: MKMapView) {
        // 移除旧的探索轨迹线（通过 title 识别）
        let explorationOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline {
                return polyline.title == "exploration"
            }
            return false
        }
        mapView.removeOverlays(explorationOverlays)

        // 如果没有探索路径点或不在探索中，直接返回
        guard !explorationPath.isEmpty && isExploring else { return }

        // 将 WGS-84 坐标转换为 GCJ-02 坐标（解决中国地区偏移问题）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(explorationPath)

        // 创建探索轨迹线
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        polyline.title = "exploration"  // 标记为探索路径
        mapView.addOverlay(polyline, level: .aboveRoads)

        print("🚶 探索轨迹已更新，共 \(explorationPath.count) 个点")
    }

    /// 更新POI标注
    private func updatePOIAnnotations(on mapView: MKMapView) {
        // 移除旧的POI标记
        let existingAnnotations = mapView.annotations.filter { $0 is POIAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        print("🗺️ [POI标注] 更新检查: isExploring=\(isExploring), nearbyPOIs.count=\(nearbyPOIs.count)")

        // 如果不在探索中，不显示POI
        guard isExploring else {
            print("🗺️ [POI标注] 不在探索中，跳过显示")
            return
        }

        // 如果没有POI，记录日志
        if nearbyPOIs.isEmpty {
            print("🗺️ [POI标注] ⚠️ POI列表为空，没有可显示的POI")
            return
        }

        // 添加新的POI标记
        for poi in nearbyPOIs {
            // 坐标转换（中国地区需要GCJ-02）
            let gcj02Coordinate = CoordinateConverter.wgs84ToGcj02(poi.coordinate)

            let annotation = POIAnnotation(poi: poi, coordinate: gcj02Coordinate)
            mapView.addAnnotation(annotation)
            print("🗺️ [POI标注] 添加: \(poi.name) at (\(String(format: "%.6f", gcj02Coordinate.latitude)), \(String(format: "%.6f", gcj02Coordinate.longitude)))")
        }

        print("🗺️ [POI标注] ✅ 已添加 \(nearbyPOIs.count) 个POI标记到地图")
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

        /// ⭐ 自定义标注视图（POI标记）
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            if annotation is MKUserLocation {
                return nil
            }

            // POI标记
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = poiAnnotation
                }

                // 设置图标和颜色
                view?.glyphImage = UIImage(systemName: poiAnnotation.poi.type.iconName)
                view?.markerTintColor = UIColor(poiAnnotation.poi.type.themeColor)

                // 已搜刮的POI显示灰色
                if poiAnnotation.poi.isScavenged {
                    view?.markerTintColor = .gray
                    view?.alpha = 0.5
                }

                return view
            }

            return nil
        }

        /// ⭐ 渲染覆盖物（轨迹线和多边形）- 关键方法！
        /// 如果不实现这个方法，轨迹添加了也看不见！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // ⭐ 根据轨迹类型设置颜色
                if polyline.title == "exploration" {
                    // 探索路径：橙色
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 4
                } else if parent.isPathClosed {
                    // 圈地已闭环：绿色
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 5
                } else {
                    // 圈地追踪中：青色
                    renderer.strokeColor = UIColor.systemCyan
                    renderer.lineWidth = 5
                }

                renderer.lineCap = .round                       // 圆头
                renderer.lineJoin = .round                      // 圆角连接
                return renderer
            }

            // ⭐ 渲染多边形填充
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据多边形类型设置颜色
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                } else {
                    // 当前追踪的多边形（无 title）：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                }

                renderer.lineWidth = 2.0
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
