//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地地图视图
//  UIViewRepresentable 包装 MKMapView，显示领地边界和建筑标记
//

import SwiftUI
import MapKit

// MARK: - Territory Map View

struct TerritoryMapView: UIViewRepresentable {

    // MARK: - Properties

    let territory: Territory
    let buildings: [PlayerBuilding]
    var onTap: ((CLLocationCoordinate2D) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybridFlyover
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新 coordinator 的引用
        context.coordinator.onTap = onTap

        // 移除旧的覆盖物和标注
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        // 添加领地多边形
        let coordinates = territory.toCoordinates()
        guard !coordinates.isEmpty else { return }

        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polygon)

        // 添加建筑标注
        for building in buildings {
            if let lat = building.locationLat, let lon = building.locationLon {
                let annotation = BuildingAnnotation(building: building)
                annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                mapView.addAnnotation(annotation)
            }
        }

        // 设置地图区域
        setMapRegion(mapView: mapView, coordinates: coordinates)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Helper Methods

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
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView
        var onTap: ((CLLocationCoordinate2D) -> Void)?

        init(_ parent: TerritoryMapView) {
            self.parent = parent
            self.onTap = parent.onTap
        }

        @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let mapView = gestureRecognizer.view as? MKMapView else { return }
            let point = gestureRecognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onTap?(coordinate)
        }

        // 渲染多边形
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(ApocalypseTheme.primary).withAlphaComponent(0.2)
                renderer.strokeColor = UIColor(ApocalypseTheme.primary)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // 渲染建筑标注
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let buildingAnnotation = annotation as? BuildingAnnotation else { return nil }

            let identifier = "BuildingAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            annotationView?.glyphImage = UIImage(systemName: buildingAnnotation.building.template.icon)
            annotationView?.markerTintColor = buildingAnnotation.building.status == .active
                ? UIColor(ApocalypseTheme.success)
                : UIColor(ApocalypseTheme.warning)

            return annotationView
        }
    }
}

// MARK: - Building Annotation

class BuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D()

    var title: String? {
        return building.template.name
    }

    var subtitle: String? {
        return "Lv.\(building.level) - \(building.status.displayName)"
    }

    init(building: PlayerBuilding) {
        self.building = building
        super.init()
    }
}

// MARK: - Preview

#Preview {
    TerritoryMapView(
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
        buildings: []
    )
    .ignoresSafeArea()
}
