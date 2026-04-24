import SwiftUI

struct SwipeCard: View {
    let product: Product
    let store: Store?
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            ProductImage(product: product, cornerRadius: 22, showImageId: true)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .init(x: 0.5, y: 0.4),
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack {
                HStack(alignment: .top) {
                    if let s = store {
                        storeTag(s)
                    }
                    Spacer()
                    FreshBadge(hours: product.freshHours, style: .onLight)
                }
                .padding(14)

                Spacer()

                bottomContent
                    .padding(18)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // Flatten the card (image + gradients + overlays) into a single
        // rasterized layer BEFORE applying the shadow. Without this, every
        // frame of the drag gesture forces Core Animation to re-rasterize the
        // whole stack to feed the blur-based shadow — visible as the "torn"
        // look. With compositingGroup the shadow operates on a cached bitmap
        // that simply translates/rotates as the finger moves.
        .compositingGroup()
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 18)
    }

    private func storeTag(_ s: Store) -> some View {
        // Distance to the store. When we have a real GPS fix we show how far
        // *you* are from it right now — that's what the card really needs to
        // answer ("is this worth walking to?"). Without a fix we fall back to
        // the catalog's static km value so the pill still reads as useful.
        let lm = LocationManager.shared
        let km = lm.userCoord != nil
            ? lm.distance(toKm: s.coordinate)
            : s.distanceKm
        let walkMin = max(1, Int((km * 12).rounded()))
        return HStack(spacing: 5) {
            Image(systemName: "location.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.ink.opacity(0.75))
            Text("\(s.name) · \(formatKm(km)) км · ~\(walkMin) мин")
                .font(.mono(9, weight: .regular))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.82))
        )
        .background(.ultraThinMaterial, in: Capsule())
    }

    /// Drop the trailing ".0" on whole-km values so the pill reads "2 км" and
    /// not "2.0 км" — keeps the overlay compact on narrow cards.
    private func formatKm(_ km: Double) -> String {
        if km >= 10 { return String(Int(km.rounded())) }
        return String(format: "%.1f", km)
    }

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(product.brand.uppercased()) · \(product.category.uppercased())")
                .font(.mono(10))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.75))

            Text(product.title)
                .font(.serif(30, weight: .regular))
                .tracking(-0.7)
                .lineLimit(2)
                .foregroundStyle(.white)

            HStack(alignment: .center, spacing: 8) {
                Text(product.price.formattedRubles)
                    .font(.mono(15, weight: .semibold))
                    .foregroundStyle(.white)
                if let old = product.oldPrice {
                    Text(old.formattedRubles)
                        .font(.mono(12))
                        .foregroundStyle(.white.opacity(0.55))
                        .strikethrough(true, color: .white.opacity(0.55))
                }
                Spacer()
                Text("\(product.availableSizes.count) р-ров в наличии")
                    .font(.sans(11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 4)
        }
    }
}
