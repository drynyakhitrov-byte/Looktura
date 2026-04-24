import SwiftUI

struct ProductImage: View {
    let product: Product
    var cornerRadius: CGFloat = 0
    var showImageId: Bool = true

    private var fallbackColor: Color {
        let palette = ["#B8A99A","#5C6F5C","#D4C4B0","#9E8BAF","#6B4F4F","#A8AEB0","#3A4550","#C8B8A8"]
        let idx = Int(product.id.unicodeScalars.first?.value ?? 97) % palette.count
        return Color(hex: palette[idx])
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(fallbackColor)
            CachedImage(url: product.imageURL, contentMode: .fill) {
                // Stay on fallback color while loading — no loading spinner.
                // Prevents flash of white between fallback and final image.
                Color.clear
            }
            if showImageId {
                Text("№\(product.id.uppercased()) · \(product.color)")
                    .font(.mono(9))
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.9))
                    .textCase(.uppercase)
                    .padding(12)
                    .blendMode(.difference)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct StoreCoverImage: View {
    let store: Store
    var body: some View {
        CachedImage(url: store.coverURL, contentMode: .fill) {
            Color(hex: "#E8E3D8")
        }
    }
}
