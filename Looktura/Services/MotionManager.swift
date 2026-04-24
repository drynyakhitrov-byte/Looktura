import Foundation
import CoreMotion
import SwiftUI
import Observation

/// Device-attitude tap for liquid-glass specular. Apple's native `.glassEffect`
/// on iOS 26 already lenses the content behind it with motion, but our overlay
/// adds an additional roaming specular highlight so the glass feels alive on
/// every iOS we support.
///
/// We intentionally cap the update rate (60fps feels silky; 120hz is overkill
/// for a shimmer that moves only a few pixels), and smooth the roll/pitch with
/// a low-pass filter so sudden micro-jitters don't make the highlight buzz.
@Observable
final class MotionManager {
    static let shared = MotionManager()

    /// Smoothed roll, in radians. Negative = device tilted left.
    var roll: Double = 0
    /// Smoothed pitch, in radians. Negative = top of device tilted toward user.
    var pitch: Double = 0

    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    private let smoothing: Double = 0.12 // 0 = no smoothing (jittery), 1 = frozen

    private init() {
        queue.name = "com.looktura.motion"
        queue.qualityOfService = .userInitiated
        start()
    }

    private func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
            guard let self, let a = data?.attitude else { return }
            let r = a.roll
            let p = a.pitch
            DispatchQueue.main.async {
                // Low-pass: blend new sample into stored value. Produces
                // the "drifting specular" feel instead of snap-to-sensor noise.
                self.roll = self.roll * (1 - self.smoothing) + r * self.smoothing
                self.pitch = self.pitch * (1 - self.smoothing) + p * self.smoothing
            }
        }
    }
}

/// An absolutely-positioned white-gradient highlight that shifts across a
/// shape in response to device tilt. Additive over the glass material so the
/// underlying refraction still dominates — this is a garnish, not a surface.
struct SpecularHighlight<S: Shape>: View {
    let shape: S
    var intensity: Double = 1.0

    @State private var roll: Double = 0
    @State private var pitch: Double = 0

    var body: some View {
        // Map roll (±~0.6 rad = ±35°) to a unit-space offset. Clamp both
        // components so the gradient never fully exits the shape.
        let nx = max(-1, min(1, roll / 0.6))
        let ny = max(-1, min(1, pitch / 0.6))

        // Start the gradient on the opposite side of the tilt and fade to
        // transparent — feels like light rolling off a curved pane.
        let start = UnitPoint(x: 0.5 - nx * 0.55, y: 0.5 - ny * 0.55)
        let end = UnitPoint(x: 0.5 + nx * 0.55, y: 0.5 + ny * 0.55)

        shape
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.24 * intensity), location: 0.0),
                        .init(color: .white.opacity(0.06 * intensity), location: 0.45),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: start,
                    endPoint: end
                )
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .onAppear { subscribe() }
    }

    private func subscribe() {
        // SwiftUI doesn't re-render when a non-@State property on a non-view
        // object changes, but since we're observing MotionManager.shared via
        // the @Observable macro, binding through local @State via TimelineView
        // keeps this lightweight. Here we rely on the observability tracker:
        // reading motion inside the view body would trigger re-renders at 60fps
        // for every view using it. Instead we sample at the CMMotion callback
        // cadence via a timer, which the runtime can batch.
        Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            let m = MotionManager.shared
            if abs(m.roll - roll) > 0.002 || abs(m.pitch - pitch) > 0.002 {
                roll = m.roll
                pitch = m.pitch
            }
        }
    }
}

extension View {
    /// Overlays a gyroscope-driven specular sheen on top of an existing
    /// liquid-glass surface. Clipped to the same shape as the glass so the
    /// highlight hugs the button/pill edges.
    ///
    /// Use sparingly — best reserved for prominent surfaces (icon buttons,
    /// hero pills). Every subscribed view costs a few hundred microseconds
    /// of update work at 30Hz.
    func gyroSpecular<S: Shape>(in shape: S, intensity: Double = 1.0) -> some View {
        self.overlay(
            SpecularHighlight(shape: shape, intensity: intensity)
        )
    }
}
