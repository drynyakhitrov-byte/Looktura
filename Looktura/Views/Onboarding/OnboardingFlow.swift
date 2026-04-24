import SwiftUI

struct OnboardingFlow: View {
    @Bindable var appState: AppState
    @State private var step: Int = 0

    var body: some View {
        Group {
            switch step {
            case 0: IntroView(index: 0, onNext: { step = 1 })
            case 1: IntroView(index: 1, onNext: { step = 2 })
            case 2: IntroView(index: 2, onNext: { step = 3 })
            case 3: AuthView(onNext: { step = 4 })
            case 4: QuizView(appState: appState, onNext: { step = 5 })
            default: GeoView(onDone: {
                withAnimation(.easeInOut(duration: 0.35)) {
                    appState.hasCompletedOnboarding = true
                }
            })
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity))
    }
}
