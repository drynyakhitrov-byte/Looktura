import SwiftUI

struct IntroView: View {
    let index: Int
    let onNext: () -> Void

    @Environment(\.appTheme) private var theme

    private var data: (badge: String, kicker: String, title: String, sub: String, cta: String) {
        switch index {
        case 0:
            return ("01 / 03", "Свайп вместо прокрутки",
                    "Ищи, что зацепило.",
                    "Листай карточки, которые подбирают магазины твоего района. Понравилось — забронируй примерку.",
                    "Дальше")
        case 1:
            return ("02 / 03", "Только офлайн",
                    "Мы не про доставку.",
                    "LOOKTURA показывает, где вещь лежит прямо сейчас. Приходи, меряй, забирай.",
                    "Дальше")
        default:
            return ("03 / 03", "Районный стиль",
                    "Твои магазины — рядом.",
                    "Шесть концепт-сторов Москвы уже в приложении. Дальше — больше.",
                    "Поехали")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Wordmark(size: 13)
                Spacer()
                Text(data.badge)
                    .font(.mono(10))
                    .tracking(1.5)
                    .foregroundStyle(theme.muted)
            }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.pill)
                .frame(height: 290)
                .overlay {
                    Group {
                        switch index {
                        case 0: IntroArt1()
                        case 1: IntroArt2()
                        default: IntroArt3()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.top, 34)

            VStack(alignment: .leading, spacing: 12) {
                Text(data.kicker.uppercased())
                    .font(.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(theme.accentDeep)

                Text(data.title)
                    .font(.serif(38, weight: .regular))
                    .tracking(-1.2)
                    .lineSpacing(-6)
                    .foregroundStyle(theme.ink)

                Text(data.sub)
                    .font(.sans(15))
                    .lineSpacing(3)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: 330, alignment: .leading)
            }
            .padding(.top, 32)

            Spacer()

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i == index ? theme.ink : theme.line)
                            .frame(width: i == index ? 28 : 6, height: 6)
                            // Springier feel for the active-dot stretch;
                            // the default `.spring()` is a touch lazy in
                            // an onboarding context where the user just
                            // tapped something seconds ago.
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.78),
                                value: index
                            )
                    }
                }
                Spacer()
                Button(action: onNext) {
                    HStack(spacing: 10) {
                        Text(data.cta).font(.sans(15, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(theme.accentInk)
                    .padding(.horizontal, 28)
                    .frame(height: 54)
                    .background(theme.ink)
                    .clipShape(Capsule())
                    // Ink-tinted shadow — reads as "floats above the page"
                    // without a hard line. Ports the design's
                    // `boxShadow: 0 8px 20px -8px rgba(17,16,16,.35)`.
                    .shadow(color: theme.ink.opacity(0.28), radius: 16, x: 0, y: 8)
                    .contentShape(Capsule())
                }
                // Spring press-scale gives the primary CTA the same tactile
                // feel as chips elsewhere in the app.
                .buttonStyle(IntroCTAButtonStyle())
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.bg.ignoresSafeArea())
    }
}

/// Press-reactive style for the bottom CTA on intro pages. Spring-scale to
/// 0.97 feels like a physical press without being so squishy it looks soft.
private struct IntroCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct IntroArt1: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#B8A99A"))
                .frame(width: 170, height: 230)
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 12)
                .offset(x: -50, y: 10)
                .overlay(alignment: .bottomLeading) {
                    Text("ПАЛЬТО · 89 000 ₽")
                        .font(.mono(9)).tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(12)
                }
                .offset(x: -50, y: 10)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#5C6F5C"))
                .frame(width: 170, height: 230)
                .rotationEffect(.degrees(3))
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 14)
                .offset(x: 20, y: 0)
                .overlay(alignment: .bottomLeading) {
                    Text("ЖАКЕТ · 47 000 ₽")
                        .font(.mono(9)).tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(12)
                }
                .offset(x: 20, y: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: 32))
                .foregroundStyle(theme.ink.opacity(0.35))
                .offset(x: 110, y: 40)
        }
    }
}

private struct IntroArt2: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        ZStack {
            Circle().stroke(theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                .frame(width: 190, height: 190)
            Circle().stroke(theme.line, lineWidth: 1)
                .frame(width: 120, height: 120)
            Circle().fill(theme.accent).frame(width: 16, height: 16)

            ForEach(Array(zip(["OBJEKT","КОМОД","Shelter"], [(-45, -30), (35, 15), (-25, 50)])), id: \.0) { item in
                Circle().fill(theme.ink).frame(width: 8, height: 8)
                    .offset(x: CGFloat(item.1.0), y: CGFloat(item.1.1))
                Text(item.0)
                    .font(.mono(9))
                    .tracking(0.6)
                    .foregroundStyle(theme.ink)
                    .offset(x: CGFloat(item.1.0 + 36), y: CGFloat(item.1.1))
            }

            Text("В РАДИУСЕ 2 КМ · 6 МАГАЗИНОВ")
                .font(.mono(9)).tracking(2)
                .foregroundStyle(theme.muted)
                .offset(y: 120)
        }
    }
}

private struct IntroArt3: View {
    @Environment(\.appTheme) private var theme
    private let tiles: [(String, String)] = [
        ("OBJEKT","concept"),("КОМОД","vintage"),("SHELTER","local"),
        ("NORD","scandi"),("PARALLEL","street"),("MIRA","tailor")
    ]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { idx, tile in
                VStack(alignment: .leading) {
                    Text(tile.1.uppercased())
                        .font(.mono(9)).tracking(1.2)
                        .foregroundStyle(idx % 2 == 1 ? theme.muted : Color.white.opacity(0.75))
                    Spacer()
                    Text(tile.0)
                        .font(.serif(18, weight: .regular))
                        .foregroundStyle(idx % 2 == 1 ? theme.accent : .white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
                .frame(height: 72, alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(idx % 2 == 1 ? theme.ink : theme.accent))
            }
        }
        .padding(20)
    }
}
