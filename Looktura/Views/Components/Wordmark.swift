import SwiftUI

struct Wordmark: View {
    var size: CGFloat = 14
    var color: Color? = nil
    var tracking: CGFloat = 5

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text("LOOKTURA")
            .font(.mono(size, weight: .semibold))
            .tracking(tracking)
            .foregroundStyle(color ?? theme.ink)
    }
}
