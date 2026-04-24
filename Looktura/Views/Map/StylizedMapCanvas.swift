import SwiftUI
import CoreLocation

struct MapProjection {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    init(coordinates: [CLLocationCoordinate2D], paddingFraction: Double = 0.26) {
        let safe = coordinates.isEmpty
            ? [CLLocationCoordinate2D(latitude: 55.7520, longitude: 37.6175)]
            : coordinates
        let lats = safe.map(\.latitude)
        let lons = safe.map(\.longitude)
        let rawMinLat = lats.min() ?? 55.75
        let rawMaxLat = lats.max() ?? 55.77
        let rawMinLon = lons.min() ?? 37.58
        let rawMaxLon = lons.max() ?? 37.63
        let latPad = max((rawMaxLat - rawMinLat) * paddingFraction, 0.008)
        let lonPad = max((rawMaxLon - rawMinLon) * paddingFraction, 0.010)
        self.minLat = rawMinLat - latPad
        self.maxLat = rawMaxLat + latPad
        self.minLon = rawMinLon - lonPad
        self.maxLon = rawMaxLon + lonPad
    }

    func project(_ c: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let nx = (c.longitude - minLon) / max(0.00001, maxLon - minLon)
        let ny = (c.latitude - minLat) / max(0.00001, maxLat - minLat)
        return CGPoint(x: CGFloat(nx) * size.width, y: CGFloat(1 - ny) * size.height)
    }
}

struct StylizedMapBackground: View {
    let projection: MapProjection

    @Environment(\.appTheme) private var theme

    private let kremlin = CLLocationCoordinate2D(latitude: 55.7520, longitude: 37.6175)

    private let radialStreets: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = [
        (CLLocationCoordinate2D(latitude: 55.7540, longitude: 37.6180),
         CLLocationCoordinate2D(latitude: 55.7810, longitude: 37.6020)),
        (CLLocationCoordinate2D(latitude: 55.7540, longitude: 37.6130),
         CLLocationCoordinate2D(latitude: 55.7800, longitude: 37.5850)),
        (CLLocationCoordinate2D(latitude: 55.7520, longitude: 37.6080),
         CLLocationCoordinate2D(latitude: 55.7490, longitude: 37.5760)),
        (CLLocationCoordinate2D(latitude: 55.7500, longitude: 37.6110),
         CLLocationCoordinate2D(latitude: 55.7300, longitude: 37.5950)),
        (CLLocationCoordinate2D(latitude: 55.7490, longitude: 37.6200),
         CLLocationCoordinate2D(latitude: 55.7260, longitude: 37.6350)),
        (CLLocationCoordinate2D(latitude: 55.7530, longitude: 37.6280),
         CLLocationCoordinate2D(latitude: 55.7620, longitude: 37.6520)),
        (CLLocationCoordinate2D(latitude: 55.7580, longitude: 37.6230),
         CLLocationCoordinate2D(latitude: 55.7720, longitude: 37.6400))
    ]

    var body: some View {
        GeometryReader { geo in
            let kPos = projection.project(kremlin, in: geo.size)

            ZStack {
                LinearGradient(
                    colors: [theme.bg, theme.stage.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Garden Ring (outer elliptical ring)
                Ellipse()
                    .stroke(theme.ink.opacity(0.06), style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
                    .frame(width: geo.size.width * 1.25, height: geo.size.height * 1.0)
                    .position(kPos)

                // Boulevard Ring (inner)
                Ellipse()
                    .stroke(theme.ink.opacity(0.08), style: StrokeStyle(lineWidth: 1.0, dash: [2, 4]))
                    .frame(width: geo.size.width * 0.62, height: geo.size.height * 0.50)
                    .position(kPos)

                // Radial streets
                Path { path in
                    for s in radialStreets {
                        let a = projection.project(s.0, in: geo.size)
                        let b = projection.project(s.1, in: geo.size)
                        path.move(to: a)
                        path.addLine(to: b)
                    }
                }
                .stroke(theme.ink.opacity(0.08), lineWidth: 1.4)

                // Moskva river
                Path { p in
                    let y = kPos.y + geo.size.height * 0.08
                    p.move(to: CGPoint(x: -20, y: y + 10))
                    p.addCurve(
                        to: CGPoint(x: geo.size.width + 20, y: y - 30),
                        control1: CGPoint(x: geo.size.width * 0.30, y: y + 48),
                        control2: CGPoint(x: geo.size.width * 0.70, y: y - 58)
                    )
                }
                .stroke(Color(hex: "#BFCCD5").opacity(0.55), style: StrokeStyle(lineWidth: 7, lineCap: .round))

                // Kremlin marker
                VStack(spacing: 2) {
                    Circle()
                        .fill(theme.ink.opacity(0.35))
                        .frame(width: 5, height: 5)
                    Text("КРЕМЛЬ")
                        .font(.mono(7))
                        .tracking(1.4)
                        .foregroundStyle(theme.muted)
                }
                .position(x: kPos.x, y: kPos.y - 6)

                // Subtle grid dots (paper feel)
                Canvas { ctx, size in
                    let spacing: CGFloat = 44
                    let cols = Int(size.width / spacing) + 1
                    let rows = Int(size.height / spacing) + 1
                    for r in 0..<rows {
                        for c in 0..<cols {
                            let x = CGFloat(c) * spacing
                            let y = CGFloat(r) * spacing
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                                with: .color(theme.ink.opacity(0.045))
                            )
                        }
                    }
                }
                .blendMode(.multiply)
            }
        }
        .allowsHitTesting(false)
    }
}

struct StylizedMapPolyline: View {
    let coordinates: [CLLocationCoordinate2D]
    let projection: MapProjection
    let color: Color
    var lineWidth: CGFloat = 2.5
    var dash: [CGFloat] = [2, 6]

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let pts = coordinates.map { projection.project($0, in: geo.size) }
                guard let first = pts.first else { return }
                p.move(to: first)
                for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: dash))
        }
        .allowsHitTesting(false)
    }
}

struct StylizedUserDot: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#2E8BFF").opacity(0.18))
                .frame(width: 28, height: 28)
            Circle()
                .fill(Color(hex: "#2E8BFF"))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
    }
}

struct OfflineMapBadge: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 10, weight: .semibold))
            Text("OFFLINE · МАРШРУТ ОРИЕНТИРОВОЧНЫЙ")
                .font(.mono(9, weight: .semibold))
                .tracking(1.4)
        }
        .foregroundStyle(theme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        // Floating offline chip above the map — lives on the map's own
        // blurry surface, so liquid glass + a thin white stroke reads as
        // a proper piece of chrome instead of a flat pill.
        .liquidGlass(in: Capsule(style: .continuous))
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
        )
    }
}
