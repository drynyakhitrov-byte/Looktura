import SwiftUI

/// Fullscreen photo viewer presented from DetailView when the user taps a slide
/// in the hero carousel.
///
/// Gives a photo-viewer feel that matches iOS Photos:
///   • horizontally pageable across all gallery URLs,
///   • pinch-to-zoom inside a page (double-tap toggles 1× ↔ 2.6×),
///   • pan while zoomed, clamped to the on-screen frame,
///   • drag-down-to-dismiss when zoomed out (1×),
///   • close button top-right.
///
/// We re-use `CachedImage` so we inherit the decoded-on-a-background-queue
/// behaviour — opening the viewer from a warm card is instant.
struct FullscreenGallery: View {
    let urls: [URL]
    let startIndex: Int
    let onClose: () -> Void

    @State private var page: Int
    @State private var dragDismissOffset: CGFloat = 0
    @State private var backdropOpacity: Double = 1

    init(urls: [URL], startIndex: Int, onClose: @escaping () -> Void) {
        self.urls = urls
        self.startIndex = max(0, min(urls.count - 1, startIndex))
        self.onClose = onClose
        _page = State(initialValue: max(0, min(urls.count - 1, startIndex)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Backdrop darkens with drag-to-dismiss so the gesture feels like a
            // real pull rather than a hard clip.
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                    ZoomablePhoto(
                        url: url,
                        dragDismissOffset: $dragDismissOffset,
                        backdropOpacity: $backdropOpacity,
                        onDismiss: onClose
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragDismissOffset)

            topBar
        }
        .statusBarHidden(true)
    }

    private var topBar: some View {
        HStack {
            Text("\(page + 1) / \(urls.count)")
                .font(.mono(12, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                )

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(Color.white.opacity(0.14))
                    )
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }
}

/// Single page inside `FullscreenGallery`. Owns its own zoom/pan state so
/// swiping between pages resets the transform on the page you left — otherwise
/// you'd come back to a still-zoomed image and lose your place.
private struct ZoomablePhoto: View {
    let url: URL
    @Binding var dragDismissOffset: CGFloat
    @Binding var backdropOpacity: Double
    let onDismiss: () -> Void

    // Committed zoom/pan (persists between gestures).
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    // Live delta during a gesture.
    @GestureState private var pinchDelta: CGFloat = 1
    @GestureState private var panDelta: CGSize = .zero

    private let zoomedScale: CGFloat = 2.6
    private let dismissThreshold: CGFloat = 140

    var body: some View {
        GeometryReader { geo in
            let effectiveScale = scale * pinchDelta
            let effectiveOffset = CGSize(
                width: offset.width + panDelta.width,
                height: offset.height + panDelta.height
            )

            ZStack {
                CachedImage(url: url, contentMode: .fit) {
                    Color.white.opacity(0.04)
                }
                .scaleEffect(effectiveScale)
                .offset(effectiveOffset)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(zoomGesture(size: geo.size))
                .simultaneousGesture(
                    effectiveScale > 1.01
                        ? panGesture(size: geo.size)
                        : nil
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        if scale > 1.01 {
                            scale = 1
                            offset = .zero
                        } else {
                            scale = zoomedScale
                        }
                    }
                }
                // Drag-to-dismiss only when we're at 1× — otherwise vertical
                // drag means "pan the photo", which we handle in panGesture.
                //
                // Must be `.simultaneousGesture`, NOT `.highPriorityGesture`.
                // `.highPriorityGesture` steals the touch stream the moment
                // the drag crosses `minimumDistance`, so the TabView's own
                // paging gesture never gets a chance to recognize horizontal
                // swipes — the gallery appeared "stuck" on a single photo.
                // With `.simultaneousGesture` TabView's paging still competes
                // for the touch, and the vertical-intent guard inside
                // `dismissDrag.onChanged` filters out horizontal drags so the
                // backdrop doesn't fade during paging.
                .simultaneousGesture(
                    effectiveScale <= 1.01
                        ? dismissDrag()
                        : nil
                )
            }
        }
    }

    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnificationGesture()
            .updating($pinchDelta) { current, state, _ in
                state = current
            }
            .onEnded { final in
                let next = (scale * final).clamped(to: 1 ... 4.5)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    scale = next
                    offset = clampedOffset(offset, scale: next, in: size)
                    if next <= 1.01 { offset = .zero }
                }
            }
    }

    private func panGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .updating($panDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    offset = clampedOffset(
                        CGSize(
                            width: offset.width + value.translation.width,
                            height: offset.height + value.translation.height
                        ),
                        scale: scale,
                        in: size
                    )
                }
            }
    }

    private func dismissDrag() -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Only react to clearly vertical intent — otherwise TabView
                // horizontal paging would fight this gesture.
                let dy = value.translation.height
                guard abs(dy) > abs(value.translation.width) else { return }
                dragDismissOffset = dy
                backdropOpacity = max(0.35, 1 - Double(abs(dy)) / 500)
            }
            .onEnded { value in
                if abs(value.translation.height) > dismissThreshold,
                   abs(value.translation.height) > abs(value.translation.width) {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        dragDismissOffset = 0
                        backdropOpacity = 1
                    }
                }
            }
    }

    /// Keep the zoomed photo from being panned off-screen. Works out how much
    /// slack each axis has once scaled, and clamps the committed offset to
    /// ±half of that slack.
    private func clampedOffset(_ proposed: CGSize, scale: CGFloat, in size: CGSize) -> CGSize {
        guard scale > 1 else { return .zero }
        let slackW = max(0, (size.width * scale - size.width) / 2)
        let slackH = max(0, (size.height * scale - size.height) / 2)
        return CGSize(
            width: proposed.width.clamped(to: -slackW ... slackW),
            height: proposed.height.clamped(to: -slackH ... slackH)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
