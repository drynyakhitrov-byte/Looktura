import SwiftUI
import MapKit

struct MapView: View {
    let repository: DataRepository
    let mapAvailability: MapAvailability
    let hasFavoriteStores: Bool
    let onOpenStore: (String) -> Void
    let onOpenRoute: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var selectedStoreId: String = ""
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 55.7600, longitude: 37.6175),
            span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
        )
    )

    /// Flips true on `.onAppear` to drive the staggered entrance animation
    /// of the floating chrome (search bar, route chip, store card).
    ///
    /// Stays on `@State` so each visit to the Map tab re-triggers the
    /// animation — the user asked for UI elements to "appear with animation"
    /// each time they tap Map in the tab bar, not only on first launch.
    @State private var appeared: Bool = false

    private var selectedStore: Store? {
        repository.store(id: selectedStoreId) ?? repository.stores.first
    }

    private var projection: MapProjection {
        let coords = repository.stores.map(\.coordinate)
        return MapProjection(coordinates: coords)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch mapAvailability.state {
                case .offline:
                    stylizedMap
                case .online, .checking:
                    mapKitMap
                }
            }
            .ignoresSafeArea()

            topSearchBar
                .padding(.horizontal, 18)
                .padding(.top, 8)
                // Search bar drops in from above the safe area. Short delay
                // before the fade so it doesn't race the map itself settling.
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -22)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.86).delay(0.05),
                    value: appeared
                )

            if hasFavoriteStores {
                VStack {
                    // Slots directly below the search bar + filter row
                    // (46pt bar + 8pt top + 10pt breathing = ~64pt).
                    Spacer().frame(height: 64)
                    HStack {
                        routeChip
                        if mapAvailability.state == .offline {
                            OfflineMapBadge()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    Spacer()
                }
                // Route chip slides in from the left, a beat after the
                // search bar so the eye reads them sequentially rather than
                // as a simultaneous pop.
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -28)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.86).delay(0.14),
                    value: appeared
                )
            }

            if let s = selectedStore {
                VStack {
                    Spacer()
                    StoreCard(
                        store: s,
                        productCount: repository.products(inStore: s.id).count,
                        onOpen: { onOpenStore(s.id) },
                        onRoute: onOpenRoute
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 100)
                }
                // Store card rises from below. Last in the stagger so the
                // user's gaze naturally lands on the primary CTA after the
                // top chrome has settled. Larger offset than the search bar
                // because the card is physically bigger — subtle offsets on
                // big elements read as "did it even move?".
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 34)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.84).delay(0.22),
                    value: appeared
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .onAppear {
            if selectedStoreId.isEmpty {
                selectedStoreId = repository.stores.first?.id ?? ""
            }
            // Reset before flipping so that if the user taps Map → Feed →
            // Map, the second visit re-animates (otherwise `appeared` would
            // already be true and the spring would be a no-op). Cheap reset:
            // everything is wrapped in `if appeared { offset: 0 }`, so a brief
            // flicker at 0 → animated-to-0 is imperceptible. We use a
            // non-animated transaction to guarantee the reset itself is not
            // tweened.
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                appeared = false
            }
            // Kick the spring on the next run-loop tick so SwiftUI has a
            // chance to commit the `false` layout before the `true` one
            // animates from it. Without the dispatch, the two state writes
            // coalesce into the same frame and there's nothing to animate
            // against.
            DispatchQueue.main.async {
                appeared = true
            }
        }
        .task {
            await mapAvailability.refreshIfNeeded()
        }
    }

    private var routeChip: some View {
        Button(action: onOpenRoute) {
            HStack(spacing: 8) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Маршрут по Избранному")
                    .font(.sans(12, weight: .semibold))
            }
            .foregroundStyle(theme.accentInk)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(theme.accent))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var mapKitMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            ForEach(repository.stores) { store in
                Annotation(store.name, coordinate: store.coordinate) {
                    StorePin(
                        store: store,
                        productCount: repository.products(inStore: store.id).count,
                        isActive: selectedStoreId == store.id
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedStoreId = store.id
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: store.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                )
                            )
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    private var stylizedMap: some View {
        GeometryReader { geo in
            ZStack {
                StylizedMapBackground(projection: projection)
                    .frame(width: geo.size.width, height: geo.size.height)

                StylizedUserDot()
                    .position(projection.project(
                        CLLocationCoordinate2D(latitude: 55.7600, longitude: 37.6175),
                        in: geo.size
                    ))

                ForEach(repository.stores) { store in
                    let pos = projection.project(store.coordinate, in: geo.size)
                    StorePin(
                        store: store,
                        productCount: repository.products(inStore: store.id).count,
                        isActive: selectedStoreId == store.id
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedStoreId = store.id
                        }
                    }
                    .position(pos)
                }
            }
        }
    }

    private var topSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.ink)
                Text("Тверская · 1.8 км · 6 магазинов")
                    .font(.sans(13))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 46)
            .liquidGlass(in: Capsule(style: .continuous))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 14, y: 6)

            IconButton(icon: "line.3.horizontal.decrease", size: 46, action: {})
                .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
        }
    }
}

private struct StorePin: View {
    let store: Store
    let productCount: Int
    let isActive: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: -1) {
                HStack(spacing: 6) {
                    Text(store.name.uppercased())
                        .font(.mono(isActive ? 11 : 10, weight: .semibold))
                        .tracking(1.0)
                    Text("\(productCount)")
                        .font(.mono(9))
                        .opacity(0.55)
                }
                .foregroundStyle(isActive ? theme.accentInk : theme.ink)
                .padding(.horizontal, isActive ? 12 : 10)
                .padding(.vertical, isActive ? 7 : 5)
                .background(
                    Capsule().fill(isActive ? theme.ink : theme.surface)
                )
                .overlay(
                    Capsule().stroke(isActive ? theme.accent : theme.line, lineWidth: isActive ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

                Triangle()
                    .fill(isActive ? theme.ink : theme.surface)
                    .frame(width: 10, height: 6)
                    .overlay(
                        Triangle()
                            .stroke(isActive ? theme.accent : theme.line, lineWidth: isActive ? 2 : 1)
                            .frame(width: 10, height: 6)
                    )
            }
        }
        .buttonStyle(.plain)
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

private struct StoreCard: View {
    let store: Store
    let productCount: Int
    let onOpen: () -> Void
    let onRoute: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                StoreCoverImage(store: store)
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.vibe.uppercased())
                        .font(.mono(9))
                        .tracking(1.5)
                        .foregroundStyle(theme.muted)

                    Text(store.name)
                        .font(.serif(22, weight: .regular))
                        .tracking(-0.4)
                        .foregroundStyle(theme.ink)

                    Text(store.addr)
                        .font(.sans(12))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Text("● ОТКРЫТ")
                            .font(.mono(10, weight: .semibold))
                            .foregroundStyle(theme.success)
                        Text("·").foregroundStyle(theme.muted)
                        Text("\(String(format: "%.1f", store.distanceKm)) км")
                            .font(.mono(10))
                            .foregroundStyle(theme.ink)
                        Text("·").foregroundStyle(theme.muted)
                        Text("\(productCount) ВЕЩЕЙ")
                            .font(.mono(10))
                            .foregroundStyle(theme.ink)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(action: onOpen) {
                    Text("Открыть магазин")
                        .font(.sans(13, weight: .semibold))
                        .foregroundStyle(theme.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(theme.ink))
                }
                .buttonStyle(.plain)

                Button(action: onRoute) {
                    HStack(spacing: 6) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Маршрут")
                            .font(.sans(13, weight: .semibold))
                    }
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(Capsule().stroke(theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 26, y: 14)
    }
}
