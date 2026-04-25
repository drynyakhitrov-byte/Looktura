import SwiftUI
import UIKit

/// Step-based onboarding coordinator.
///
/// Order (as of the Claude Design "marketing-final" handoff):
///   0. Intro page 1      — "Свайп вместо прокрутки"
///   1. Intro page 2      — "Только офлайн"
///   2. Intro page 3      — "Районный стиль"
///   3. Mood warm-up      — "Что тебе к лицу сегодня?" (new from design)
///   4. Auth              — Sign in with Apple / email / phone
///   5. Quiz              — size + budget (styles already seeded by #3)
///   6. Geo permission    — final step, finishes onboarding
///
/// Transition between steps: a snappy slide-from-trailing + opacity for
/// insertion and a soft opacity-only removal. The spring's damping keeps
/// this tactile — noticeably alive without feeling spongy.
struct OnboardingFlow: View {
    @Bindable var appState: AppState
    @State private var step: Int = 0

    var body: some View {
        Group {
            switch step {
            case 0: IntroView(index: 0, onNext: { advance() })
            case 1: IntroView(index: 1, onNext: { advance() })
            case 2: IntroView(index: 2, onNext: { advance() })
            case 3:
                MoodPickerView(
                    appState: appState,
                    onNext: { advance() },
                    onSkip: { advance() }
                )
            case 4: AuthView(onNext: { advance() })
            case 5: QuizView(appState: appState, onNext: { advance() })
            default: GeoView(onDone: {
                // Finish with a slightly slower, springier fade so the
                // handoff into RootView's SwipeFeed feels arrived-at rather
                // than snapped-to.
                withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                    appState.hasCompletedOnboarding = true
                }
            })
            }
        }
        // Forward motion: the next screen slides in from the right with a
        // subtle fade so there's always a direction cue. Removal is an
        // opacity-only melt so it doesn't fight the incoming screen.
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            )
        )
        // Step-change spring: responsive enough that taps feel connected
        // to the screen change, damping high enough not to overshoot.
        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: step)
    }

    private func advance() {
        // A soft tick on every forward step so each transition feels
        // physically acknowledged — matches the haptic language used
        // throughout the rest of the app (swipe save, bulk-select enter).
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        step += 1
    }
}
