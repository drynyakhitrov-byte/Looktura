import SwiftUI

struct QuizView: View {
    @Bindable var appState: AppState
    let onNext: () -> Void

    @State private var currentQuestion: Int = 0
    @Environment(\.appTheme) private var theme

    private let questions: [Question] = [
        Question(key: "styles", title: "Какой стиль тебе ближе?", sub: "Можно несколько",
                 options: ["Minimal","Vintage","Street","Tailoring","Casual","Archive"], multi: true),
        Question(key: "sizes", title: "Твои размеры?", sub: "Так мы не покажем то, чего нет",
                 options: ["XS","S","M","L","XL"], multi: true),
        Question(key: "budget", title: "Комфортный бюджет?", sub: "На одну вещь",
                 options: ["до 15k","15–40k","40–80k","80k+","Неважно"], multi: false)
    ]

    struct Question {
        let key: String
        let title: String
        let sub: String
        let options: [String]
        let multi: Bool
    }

    var body: some View {
        let q = questions[currentQuestion]
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Wordmark(size: 13)
                Spacer()
                Text("\(currentQuestion + 1) / \(questions.count)")
                    .font(.mono(10)).tracking(1.5)
                    .foregroundStyle(theme.muted)
            }
            .padding(.top, 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.line)
                    Capsule().fill(theme.accent)
                        .frame(width: geo.size.width * CGFloat(currentQuestion + 1) / CGFloat(questions.count))
                }
            }
            .frame(height: 3)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text(q.title)
                    .font(.serif(30, weight: .regular))
                    .tracking(-0.8)
                    .foregroundStyle(theme.ink)
                Text(q.sub)
                    .font(.sans(14))
                    .foregroundStyle(theme.muted)
            }
            .padding(.top, 42)

            FlowLayout(spacing: 8) {
                ForEach(q.options, id: \.self) { opt in
                    Button {
                        toggle(opt, for: q)
                    } label: {
                        Text(opt)
                            .font(.sans(14, weight: .medium))
                            .foregroundStyle(isSelected(opt, for: q) ? theme.accentInk : theme.ink)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                Capsule().fill(isSelected(opt, for: q) ? theme.ink : .clear)
                            )
                            .overlay(
                                Capsule().stroke(isSelected(opt, for: q) ? theme.ink : theme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 26)

            Spacer()

            PrimaryButton(title: currentQuestion < questions.count - 1 ? "Дальше" : "Показать подборку") {
                if currentQuestion < questions.count - 1 {
                    withAnimation(.easeInOut) { currentQuestion += 1 }
                } else {
                    onNext()
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 50)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.bg.ignoresSafeArea())
    }

    private func isSelected(_ opt: String, for q: Question) -> Bool {
        switch q.key {
        case "styles": return appState.quizPicks.styles.contains(opt)
        case "sizes": return appState.quizPicks.sizes.contains(opt)
        case "budget": return appState.quizPicks.budget == opt
        default: return false
        }
    }

    private func toggle(_ opt: String, for q: Question) {
        switch q.key {
        case "styles":
            if appState.quizPicks.styles.contains(opt) { appState.quizPicks.styles.remove(opt) }
            else { appState.quizPicks.styles.insert(opt) }
        case "sizes":
            if appState.quizPicks.sizes.contains(opt) { appState.quizPicks.sizes.remove(opt) }
            else { appState.quizPicks.sizes.insert(opt) }
        case "budget":
            appState.quizPicks.budget = opt
        default: break
        }
    }
}
