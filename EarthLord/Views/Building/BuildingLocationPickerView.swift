//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  地图位置选择器
//  用于选择建筑放置位置，验证点在领地多边形内
//

import SwiftUI
import MapKit

struct BuildingLocationPickerView: View {

    // MARK: - Properties

    let territory: Territory
    let existingBuildings: [PlayerBuilding]
    let onLocationSelected: (CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var isLocationValid: Bool = false
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var showInvalidAlert: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图
                LocationPickerMapView(
                    territory: territory,
                    existingBuildings: existingBuildings,
                    onCenterChanged: { center in
                        mapCenter = center
                        validateLocation(center)
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // 中心准星
                crosshair

                // 底部确认按钮
                VStack {
                    Spacer()
                    confirmButton
                }
            }
            .navigationTitle("选择建造位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("位置无效", isPresented: $showInvalidAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("请选择领地范围内的位置")
            }
        }
    }

    // MARK: - Subviews

    /// 中心准星
    private var crosshair: some View {
        VStack(spacing: 0) {
            // 上半部分
            Rectangle()
                .fill(ApocalypseTheme.primary)
                .frame(width: 2, height: 20)

            // 中心圆环
            Circle()
                .stroke(ApocalypseTheme.primary, lineWidth: 2)
                .frame(width: 24, height: 24)

            // 下半部分
            Rectangle()
                .fill(ApocalypseTheme.primary)
                .frame(width: 2, height: 20)
        }
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: confirmLocation) {
            HStack {
                Image(systemName: isLocationValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(isLocationValid ? "确认位置" : "位置在领地外")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isLocationValid ? ApocalypseTheme.primary : ApocalypseTheme.danger)
            .cornerRadius(12)
        }
        .disabled(!isLocationValid)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Methods

    /// 验证位置是否在领地内
    private func validateLocation(_ location: CLLocationCoordinate2D) {
        let polygon = territory.toCoordinates()
        isLocationValid = isPointInPolygon(point: location, polygon: polygon)
    }

    /// 确认位置
    private func confirmLocation() {
        guard let center = mapCenter, isLocationValid else {
            showInvalidAlert = true
            return
        }
        onLocationSelected(center)
        dismiss()
    }

    /// 射线法判断点是否在多边形内
    private func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }
}

// MARK: - Location Picker Map View

struct LocationPickerMapView: UIViewRepresentable {

    let territory: Territory
    let existingBuildings: [PlayerBuilding]
    let onCenterChanged: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybridFlyover
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 只在首次设置时添加覆盖物
        if mapView.overlays.isEmpty {
            // 添加领地多边形
            let coordinates = territory.toCoordinates()
            guard !coordinates.isEmpty else { return }

            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polygon)

            // 添加已有建筑标记
            for building in existingBuildings {
                if let lat = building.locationLat, let lon = building.locationLon {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    annotation.title = building.template.name
                    mapView.addAnnotation(annotation)
                }
            }

            // 设置初始区域
            setMapRegion(mapView: mapView, coordinates: coordinates)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func setMapRegion(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.002),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.002)
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)

        // 初始回调中心点
        DispatchQueue.main.async {
            self.onCenterChanged(center)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        // 地图区域变化时回调中心点
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onCenterChanged(mapView.centerCoordinate)
        }

        // 渲染多边形
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(ApocalypseTheme.primary).withAlphaComponent(0.15)
                renderer.strokeColor = UIColor(ApocalypseTheme.primary)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // 渲染已有建筑标记
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "ExistingBuilding"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            annotationView?.markerTintColor = UIColor(ApocalypseTheme.warning)
            annotationView?.glyphImage = UIImage(systemName: "building.2.fill")

            return annotationView
        }
    }
}

// MARK: - Preview

#Preview {
    BuildingLocationPickerView(
        territory: Territory(
            id: "test",
            userId: "user",
            name: "测试领地",
            path: [
                ["lat": 31.230, "lon": 121.470],
                ["lat": 31.231, "lon": 121.471],
                ["lat": 31.230, "lon": 121.472],
                ["lat": 31.229, "lon": 121.471]
            ],
            area: 5000,
            pointCount: 4,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: nil
        ),
        existingBuildings: []
    ) { location in
        print("Selected: \(location)")
    }
}
