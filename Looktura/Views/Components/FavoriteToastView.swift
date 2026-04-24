import SwiftUI

struct FavoriteToastView: View {
    let product: Product?
    let onPickCollection: () -> Void
    let onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var isVisible: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text("ДОБАВЛЕНО")
                    .font(.mono(9))
                    .tracking(1.6)
                    .foregroundStyle(theme.muted)
                Text("В Избранное")
                    .font(.sans(14, weight: .semibold))
                    .foregroundStyle(theme.ink)
            }
            Spacer(minLength: 8)
            Button(action: onPickCollection) {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 12, weight: .semibold))
                    Text("в коллекцию")
                        .font(.sans(12, weight: .semibold))
                }
                .foregroundStyle(theme.accentInk)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(theme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .padding(.trailing, 4)
        .liquidGlass(in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : 90)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                onDismiss()
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let p = product {
            ProductImage(product: p, cornerRadius: 10, showImageId: false)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.line, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accent.opacity(0.25))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accentDeep)
                )
        }
    }
}
