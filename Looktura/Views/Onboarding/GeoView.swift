import SwiftUI
import CoreLocation

struct GeoView: View {
    let onDone: () -> Void
    @Environment(\.appTheme) private var theme
    @StateObject private var locationDelegate = LocationRequestDelegate()
    @State private var pulse: CGFloat = 0.9

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(size: 13)
                .padding(.top, 20)

            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 130, height: 130)
                    Circle()
                        .fill(theme.accent.opacity(0.35))
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulse)
                        .opacity(Double(2 - pulse))
                    Image(systemName: "location.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(theme.accentDeep)
                }
                .frame(width: 130, height: 130)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                        pulse = 1.4
                    }
                }

                Text("Разреши доступ к геолокации")
                    .font(.serif(30, weight: .regular))
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: 300)

                Text("Покажем магазины в радиусе 2 км от тебя — начнём со Столешникова и Патриарших.")
                    .font(.sans(14))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            PrimaryButton(title: "Разрешить") {
                locationDelegate.request()
                onDone()
            }

            Button("Пока не надо") { onDone() }
                .font(.sans(13, weight: .medium))
                .foregroundStyle(theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .padding(.top, 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 50)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.bg.ignoresSafeArea())
    }
}

final class LocationRequestDelegate: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rows[rows.count - 1].isEmpty ? 0 : spacing) > maxWidth {
                rows.append([size])
                rowWidth = size.width
            } else {
                rows[rows.count - 1].append(size)
                rowWidth += size.width + (rows[rows.count - 1].count > 1 ? spacing : 0)
            }
        }
        let totalHeight = rows.reduce(0.0) { acc, row in
            acc + (row.map { $0.height }.max() ?? 0) + spacing
        } - spacing
        return CGSize(width: maxWidth, height: max(0, totalHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
