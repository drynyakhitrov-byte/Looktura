import SwiftUI

struct NotificationsView: View {
    let repository: DataRepository
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void
    let onOpenStore: (String) -> Void

    @Environment(\.appTheme) private var theme

    private var groups: [(label: String, items: [AppNotification])] {
        let todayKeys: Set<String> = ["30 мин назад","2 часа назад","Сегодня"]
        let olderKeys: Set<String> = ["Вчера","3 дня назад","Неделю назад"]

        let today = repository.notifications.filter { todayKeys.contains($0.timeLabel) }
        let earlier = repository.notifications.filter { olderKeys.contains($0.timeLabel) }
        var out: [(String, [AppNotification])] = []
        if !today.isEmpty { out.append(("Сегодня", today)) }
        if !earlier.isEmpty { out.append(("Ранее", earlier)) }
        if out.isEmpty && !repository.notifications.isEmpty {
            out.append(("Все", repository.notifications))
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.horizontal, 22)
                    .padding(.top, 58)

                heading
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(g.label.uppercased())
                            .font(.mono(10))
                            .tracking(1.6)
                            .foregroundStyle(theme.muted)
                        VStack(spacing: 8) {
                            ForEach(g.items) { n in
                                NotificationRow(notif: n, onTap: { handleTap(n) })
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                }

                Spacer().frame(height: 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Назад")
                        .font(.sans(14))
                }
                .foregroundStyle(theme.ink)
            }
            .buttonStyle(.plain)
            Spacer()
            Button("Прочитать всё") {}
                .font(.sans(13))
                .foregroundStyle(theme.muted)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("УВЕДОМЛЕНИЯ")
                .font(.mono(10))
                .tracking(1.6)
                .foregroundStyle(theme.muted)
            Text("Что нового")
                .font(.serif(30, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(theme.ink)
        }
    }

    private func handleTap(_ n: AppNotification) {
        if let pid = n.productId { onOpenProduct(pid) }
        else if let sid = n.storeId { onOpenStore(sid) }
    }
}

private struct NotificationRow: View {
    let notif: AppNotification
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var visual: (bg: Color, fg: Color, icon: String) {
        switch notif.kind {
        case .restock: return (theme.accent, theme.accentInk, "arrow.clockwise")
        case .booking: return (theme.ink, theme.accentInk, "checkmark")
        case .new: return (theme.pill, theme.ink, "star.fill")
        case .drop: return (theme.danger, .white, "percent")
        case .reminder: return (theme.pill, theme.ink, "bell.fill")
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(visual.bg)
                    Image(systemName: visual.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(visual.fg)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(notif.title)
                            .font(.sans(14, weight: .semibold))
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Text(notif.timeLabel.uppercased())
                            .font(.mono(9))
                            .tracking(1.2)
                            .foregroundStyle(theme.muted)
                    }
                    Text(notif.body)
                        .font(.sans(12))
                        .lineSpacing(3)
                        .foregroundStyle(theme.muted)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            // Floating notification cards: liquid glass gives them a
            // continuous blurred substrate, and the white strokeBorder
            // restores the hairline edge definition lost with glass.
            .liquidGlassInteractive(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }
}
