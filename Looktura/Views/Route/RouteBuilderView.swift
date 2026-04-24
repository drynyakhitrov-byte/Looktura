import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct RouteBuilderView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let mapAvailability: MapAvailability
    let collectionId: String?
    let onBack: () -> Void
    let onOpenStore: (String) -> Void

    @Environment(\.appTheme) private var theme
    @State private var orderedStoreIds: [String] = []
    @State private var expandedStoreId: String? = nil
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 55.7600, longitude: 37.6175),
            span: MKCoordinateSpan(latitudeDelta: 0.030, longitudeDelta: 0.030)
        )
    )
    @State private var didInit: Bool = false
    @State private var showRouteOptions: Bool = false

    // Route origin — pulled from LocationManager so a real GPS fix replaces
    // the demo fallback as soon as it arrives. Reading from the @Observable
    // singleton inside the view body means `.onChange(of: startKey)` sees the
    // transition without any manual wiring.
    private var startCoord: CLLocationCoordinate2D { LocationManager.shared.effectiveStartCoord }
    private var startLabel: String { LocationManager.shared.effectiveStartLabel }

    /// Hashable summary of the effective start that only changes when the coord
    /// moves meaningfully (coarse 3-decimal rounding ≈ 100m) or when we gain /
    /// lose a real fix. Feeds `.onChange` so tiny GPS jitter every 50m doesn't
    /// force a full route recompute.
    private var startKey: String {
        let c = startCoord
        let hasFix = LocationManager.shared.userCoord != nil
        return String(format: "%.3f,%.3f,%d", c.latitude, c.longitude, hasFix ? 1 : 0)
    }

    // MARK: Derived

    private var collection: FavCollection? {
        guard let id = collectionId else { return nil }
        return appState.collection(id: id)
    }

    private var title: String {
        collection?.name ?? "Избранное"
    }

    private var sourceProductIds: [String] {
        if let c = collection { return c.productIds }
        return Array(appState.favorites)
    }

    private var productsByStore: [String: [Product]] {
        var map: [String: [Product]] = [:]
        for id in sourceProductIds {
            guard let p = repository.product(id: id) else { continue }
            map[p.storeId, default: []].append(p)
        }
        return map
    }

    private var allStoreIds: [String] {
        Array(productsByStore.keys)
    }

    private var orderedStores: [Store] {
        orderedStoreIds.compactMap { repository.store(id: $0) }
    }

    private var totalWalkingMeters: Double {
        var meters: Double = 0
        var prev = startCoord
        for s in orderedStores {
            meters += distance(prev, s.coordinate)
            prev = s.coordinate
        }
        return meters
    }

    private var totalWalkingMinutes: Int {
        max(1, Int((totalWalkingMeters / 80.0).rounded()))
    }

    private var totalKm: Double {
        totalWalkingMeters / 1000.0
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                mapSection

                header
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                summaryRow
                    .padding(.horizontal, 22)
                    .padding(.top, 14)

                divider

                storeList
            }

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .onAppear {
            // Kick the location manager — if the user granted permission in
            // onboarding we want updates flowing the first time they open the
            // route builder, not only after they toggle Settings.
            LocationManager.shared.startIfAuthorized()
            guard !didInit else { return }
            didInit = true
            computeDefaultOrder()
            fitCamera()
        }
        .onChange(of: startKey) { _, _ in
            // When the user's real GPS fix lands (or the coord drifts to a new
            // block) re-solve the tour from their actual position. This avoids
            // the "planned from Tverskaya" artefact on someone standing two
            // districts away.
            computeDefaultOrder()
            fitCamera()
        }
        .task {
            await mapAvailability.refreshIfNeeded()
        }
    }

    // MARK: Map

    private var mapSection: some View {
        ZStack(alignment: .topLeading) {
            Group {
                switch mapAvailability.state {
                case .offline:
                    stylizedMapBody
                case .online, .checking:
                    appleMapBody
                }
            }
            .frame(height: 340)

            HStack {
                GlassIconButton(icon: "chevron.left", size: 40, action: onBack)
                Spacer()
                if mapAvailability.state == .offline {
                    OfflineMapBadge()
                } else {
                    GlassIconButton(icon: "arrow.up.left.and.arrow.down.right", size: 40, action: fitCamera)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 60)
        }
        .frame(height: 340)
        .clipped()
    }

    private var appleMapBody: some View {
        Map(position: $cameraPosition) {
            Annotation("Старт", coordinate: startCoord, anchor: .bottom) {
                StartPin()
            }

            ForEach(Array(orderedStores.enumerated()), id: \.element.id) { idx, s in
                Annotation(s.name, coordinate: s.coordinate, anchor: .bottom) {
                    NumberedPin(
                        number: idx + 1,
                        active: expandedStoreId == s.id,
                        color: theme.accent
                    )
                    .onTapGesture {
                        focusStore(s.id)
                    }
                }
            }

            if orderedStores.count >= 1 {
                MapPolyline(coordinates: polylineCoordinates())
                    .stroke(
                        theme.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [2, 6])
                    )
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    private var stylizedMapBody: some View {
        let projection = MapProjection(coordinates: polylineCoordinates())
        return GeometryReader { geo in
            ZStack {
                StylizedMapBackground(projection: projection)

                StylizedMapPolyline(
                    coordinates: polylineCoordinates(),
                    projection: projection,
                    color: theme.accent,
                    lineWidth: 2.5,
                    dash: [2, 6]
                )

                StartPin()
                    .position(projection.project(startCoord, in: geo.size))

                ForEach(Array(orderedStores.enumerated()), id: \.element.id) { idx, s in
                    NumberedPin(
                        number: idx + 1,
                        active: expandedStoreId == s.id,
                        color: theme.accent
                    )
                    .onTapGesture { focusStore(s.id) }
                    .position(projection.project(s.coordinate, in: geo.size))
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("МАРШРУТ")
                    .font(.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(theme.muted)
                Text(title)
                    .font(.serif(28, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(theme.ink)
            }
            Spacer()
        }
    }

    // MARK: Summary

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryPill(value: "\(orderedStores.count)", label: "магазинов")
            summaryPill(value: String(format: "%.1f", totalKm), label: "км")
            summaryPill(value: "~\(totalWalkingMinutes)", label: "мин")
        }
    }

    private func summaryPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.serif(20, weight: .regular))
                .tracking(-0.4)
                .foregroundStyle(theme.ink)
            Text(label.uppercased())
                .font(.mono(9))
                .tracking(1.4)
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        // Summary pills float under the map — glass keeps the card
        // airy and visually tied to the liquid-glass chrome above.
        .liquidGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }

    private var divider: some View {
        HStack(spacing: 10) {
            Text("ПОРЯДОК · УДЕРЖИ И ПЕРЕТАЩИ")
                .font(.mono(9))
                .tracking(1.6)
                .foregroundStyle(theme.muted)
            Rectangle()
                .fill(theme.line)
                .frame(height: 1)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }

    // MARK: List (reorderable)

    private var storeList: some View {
        List {
            ForEach(Array(orderedStoreIds.enumerated()), id: \.element) { idx, storeId in
                if let s = repository.store(id: storeId) {
                    RouteStoreRow(
                        index: idx + 1,
                        store: s,
                        legMinutes: legMinutes(for: idx),
                        products: productsByStore[storeId] ?? [],
                        expanded: expandedStoreId == storeId,
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                                expandedStoreId = expandedStoreId == storeId ? nil : storeId
                            }
                            focusStore(storeId)
                        },
                        onOpenStore: { onOpenStore(storeId) }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .onMove { src, dst in
                orderedStoreIds.move(fromOffsets: src, toOffset: dst)
            }

            Color.clear
                .frame(height: 130)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.bg)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: { showRouteOptions = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Открыть маршрут")
                            .font(.sans(14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(theme.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(theme.ink))
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Открыть маршрут в",
                    isPresented: $showRouteOptions,
                    titleVisibility: .visible
                ) {
                    Button("Apple Maps") { openInAppleMaps() }
                    Button("Яндекс Карты") { openInYandexMaps() }
                    Button("Отмена", role: .cancel) { }
                }

                Button(action: { onBack() }) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 30)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [theme.bg.opacity(0), theme.bg, theme.bg],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    // MARK: Logic

    private func computeDefaultOrder() {
        var remaining = allStoreIds
        var ordered: [String] = []
        var prev = startCoord
        while !remaining.isEmpty {
            let nearest = remaining.min { a, b in
                let da = distance(prev, repository.store(id: a)?.coordinate ?? prev)
                let db = distance(prev, repository.store(id: b)?.coordinate ?? prev)
                return da < db
            }!
            ordered.append(nearest)
            if let c = repository.store(id: nearest)?.coordinate { prev = c }
            remaining.removeAll { $0 == nearest }
        }
        // 2-opt polish on top of nearest-neighbour. NN alone can produce tours
        // up to ~25% worse than optimal; 2-opt gets close to optimal in O(n²)
        // per pass for the ~5-15 stop tours this screen deals with.
        orderedStoreIds = twoOptImprove(ordered)
    }

    /// Classic 2-opt on an open tour pinned at `startCoord`.
    /// Repeatedly finds two edges (i, i+1) and (j, j+1) whose combined length
    /// can be shortened by reversing the segment between them, and applies
    /// that swap. Bails after the first pass that finds no improvement.
    private func twoOptImprove(_ ids: [String]) -> [String] {
        guard ids.count >= 3 else { return ids }
        var tour = ids
        var iter = 0
        // Safety cap — we never want a pathological input to block the
        // main thread. 80 passes is far more than needed for 15 stops.
        let cap = 80
        improve: while iter < cap {
            iter += 1
            // coords[0] is the fixed origin; coords[k] = tour[k-1].coord.
            var coords: [CLLocationCoordinate2D] = [startCoord]
            coords.append(contentsOf: tour.compactMap { repository.store(id: $0)?.coordinate })
            guard coords.count == tour.count + 1 else { return tour }
            let n = coords.count
            for i in 0..<(n - 2) {
                for j in (i + 2)..<n {
                    let a = coords[i]
                    let b = coords[i + 1]
                    let c = coords[j]
                    // If j is the last index there's no successor edge, so
                    // only the prefix edge cost changes after the reversal.
                    let dOpt: CLLocationCoordinate2D? = j + 1 < n ? coords[j + 1] : nil
                    let oldCost = distance(a, b) + (dOpt.map { distance(c, $0) } ?? 0)
                    let newCost = distance(a, c) + (dOpt.map { distance(b, $0) } ?? 0)
                    if newCost + 1e-6 < oldCost {
                        // Reversing coords[i+1 ... j] is equivalent to
                        // reversing tour[i ... j-1] because of the origin
                        // prepended at coords[0].
                        tour[i...(j - 1)].reverse()
                        continue improve
                    }
                }
            }
            break
        }
        return tour
    }

    private func polylineCoordinates() -> [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = [startCoord]
        coords.append(contentsOf: orderedStores.map(\.coordinate))
        return coords
    }

    private func fitCamera() {
        let coords = polylineCoordinates()
        guard !coords.isEmpty else { return }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min() ?? 55.76
        let maxLat = lats.max() ?? 55.76
        let minLon = lons.min() ?? 37.6175
        let maxLon = lons.max() ?? 37.6175
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.012, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.012, (maxLon - minLon) * 1.5)
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func focusStore(_ id: String) {
        guard let s = repository.store(id: id) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: s.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )
            )
        }
    }

    private func legMinutes(for index: Int) -> Int {
        let stores = orderedStores
        guard index < stores.count else { return 0 }
        let prev: CLLocationCoordinate2D = index == 0 ? startCoord : stores[index - 1].coordinate
        let meters = distance(prev, stores[index].coordinate)
        return max(1, Int((meters / 80.0).rounded()))
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let la = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let lb = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return la.distance(from: lb)
    }

    private func openInAppleMaps() {
        let stores = orderedStores
        guard !stores.isEmpty else { return }
        let daddr = stores.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" }.joined(separator: "+to:")
        let encoded = daddr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? daddr
        let urlString = "http://maps.apple.com/?saddr=Current+Location&daddr=" + encoded + "&dirflg=w"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func openInYandexMaps() {
        let stores = orderedStores
        guard !stores.isEmpty else { return }
        let waypoints: [String] = [
            "\(startCoord.latitude),\(startCoord.longitude)"
        ] + stores.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" }
        let rtext = waypoints.joined(separator: "~")
        guard let encoded = rtext.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let webURL = URL(string: "https://yandex.ru/maps/?rtext=\(encoded)&rtt=pd")
        let appURL = URL(string: "yandexmaps://maps.yandex.ru/?rtext=\(encoded)&rtt=pd")
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL {
            UIApplication.shared.open(webURL)
        }
    }
}

// MARK: Map pins

private struct NumberedPin: View {
    let number: Int
    let active: Bool
    let color: Color

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: -1) {
            ZStack {
                Circle()
                    .fill(active ? theme.ink : color)
                    .frame(width: active ? 40 : 34, height: active ? 40 : 34)
                Circle()
                    .stroke(theme.surface, lineWidth: 2.5)
                    .frame(width: active ? 40 : 34, height: active ? 40 : 34)
                Text(String(format: "%02d", number))
                    .font(.mono(active ? 13 : 12, weight: .bold))
                    .foregroundStyle(active ? theme.accent : .white)
            }
            .shadow(color: .black.opacity(0.20), radius: 4, y: 2)

            Triangle()
                .fill(active ? theme.ink : color)
                .frame(width: 8, height: 5)
        }
    }
}

private struct StartPin: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: -1) {
            ZStack {
                Circle()
                    .fill(theme.surface)
                    .frame(width: 30, height: 30)
                Circle()
                    .stroke(theme.ink, lineWidth: 2)
                    .frame(width: 30, height: 30)
                Text("●")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.ink)
            }
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)

            Triangle()
                .fill(theme.surface)
                .frame(width: 8, height: 5)
                .overlay(
                    Triangle()
                        .stroke(theme.ink, lineWidth: 2)
                        .frame(width: 8, height: 5)
                )
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: Row

private struct RouteStoreRow: View {
    let index: Int
    let store: Store
    let legMinutes: Int
    let products: [Product]
    let expanded: Bool
    let onToggleExpand: () -> Void
    let onOpenStore: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if expanded {
                expandedBlock
                    .padding(.top, 10)
            }
        }
        .padding(14)
        // Route store rows — liquid glass with the stroke colour
        // switching to accent while expanded so the selected row still
        // reads as the focused one.
        .liquidGlassInteractive(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    expanded ? theme.accent.opacity(0.55) : Color.white.opacity(0.22),
                    lineWidth: expanded ? 1.2 : 0.6
                )
        )
    }

    private var mainRow: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 12) {
                numberBadge

                StoreCoverImage(store: store)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.vibe.uppercased())
                        .font(.mono(9))
                        .tracking(1.4)
                        .foregroundStyle(theme.muted)
                    Text(store.name)
                        .font(.sans(15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text("\(products.count) " + countSuffix(products.count))
                            .font(.mono(10))
                            .foregroundStyle(theme.ink)
                        Text("·").foregroundStyle(theme.muted)
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 9, weight: .medium))
                            Text("~\(legMinutes) мин")
                                .font(.mono(10))
                        }
                        .foregroundStyle(theme.muted)
                    }
                }

                Spacer()

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private var numberBadge: some View {
        ZStack {
            Circle()
                .fill(theme.ink)
                .frame(width: 34, height: 34)
            Text(String(format: "%02d", index))
                .font(.mono(12, weight: .bold))
                .foregroundStyle(theme.accent)
        }
    }

    private var expandedBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("ИЗ КОЛЛЕКЦИИ")
                    .font(.mono(9))
                    .tracking(1.6)
                    .foregroundStyle(theme.muted)
                Rectangle().fill(theme.line).frame(height: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(products) { p in
                        VStack(alignment: .leading, spacing: 5) {
                            ProductImage(product: p, cornerRadius: 10, showImageId: false)
                                .frame(width: 90, height: 116)
                            Text(p.title)
                                .font(.sans(11, weight: .medium))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                                .frame(width: 90, alignment: .leading)
                            Text(p.price.formattedRubles)
                                .font(.mono(10))
                                .foregroundStyle(theme.muted)
                        }
                    }
                }
            }

            Button(action: onOpenStore) {
                HStack(spacing: 6) {
                    Text("Открыть магазин")
                        .font(.sans(12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(theme.accentDeep)
            }
            .buttonStyle(.plain)
        }
    }

    private func countSuffix(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "вещь" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "вещи" }
        return "вещей"
    }
}
