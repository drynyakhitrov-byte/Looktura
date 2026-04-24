import SwiftUI

struct PrimaryButton: View {
    let title: String
    var trailingArrow: Bool = false
    var filled: Bool = true
    var accent: Bool = false
    var action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.sans(15, weight: .semibold))
                    .tracking(0.2)
                if trailingArrow {
                    Text("→").font(.sans(17, weight: .medium))
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if !filled { return theme.ink }
        return accent ? theme.accentInk : theme.accentInk
    }

    private var background: Color {
        if !filled { return .clear }
        return accent ? theme.accent : theme.ink
    }
}

struct SecondaryButton: View {
    let title: String
    var action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.sans(15, weight: .semibold))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .overlay(
                    Capsule().stroke(theme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
