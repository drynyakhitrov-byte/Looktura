import SwiftUI
import AuthenticationServices

struct AuthView: View {
    let onNext: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(size: 13)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 12) {
                Text("ВХОД / РЕГИСТРАЦИЯ")
                    .font(.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(theme.accentDeep)

                Text("Привет.\nЗалетай в свой стиль.")
                    .font(.serif(34, weight: .regular))
                    .tracking(-1)
                    .foregroundStyle(theme.ink)
            }
            .padding(.top, 56)

            VStack(spacing: 10) {
                SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in onNext() })
                    .signInWithAppleButtonStyle(theme.isDark ? .white : .black)
                    .frame(height: 54)
                    .clipShape(Capsule())

                AuthMethodButton(icon: "envelope", label: "Войти через email") { onNext() }
                AuthMethodButton(icon: "phone", label: "По номеру телефона") { onNext() }
            }
            .padding(.top, 36)

            Spacer()

            Text("Продолжая, ты принимаешь условия использования\nи политику конфиденциальности")
                .font(.sans(11))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            PrimaryButton(title: "Продолжить", action: onNext)
                .padding(.top, 18)
        }
        .padding(.horizontal, 28)
        .padding(.top, 50)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.bg.ignoresSafeArea())
    }
}

private struct AuthMethodButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16))
                Text(label).font(.sans(15, weight: .medium))
            }
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .overlay(Capsule().stroke(theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
