import SwiftUI

struct BookingView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let productId: String
    let onBack: () -> Void
    let onConfirmed: (Booking) -> Void

    @Environment(\.appTheme) private var theme
    @State private var selectedSize: String = ""
    @State private var selectedDate: Int = 22
    @State private var selectedTime: String = "14:00"

    private var product: Product? { repository.product(id: productId) }
    private var store: Store? {
        guard let p = product else { return nil }
        return repository.store(id: p.storeId)
    }

    private let days: [Day] = [
        .init(label: "Сегодня", number: 21, available: false),
        .init(label: "Завтра", number: 22, available: true),
        .init(label: "Сб", number: 23, available: true),
        .init(label: "Вс", number: 24, available: false),
        .init(label: "Пн", number: 25, available: true),
        .init(label: "Вт", number: 26, available: true),
        .init(label: "Ср", number: 27, available: true),
    ]

    private let times: [String] = ["12:00","13:30","14:00","15:30","17:00","18:30","20:00"]

    struct Day: Hashable {
        let label: String
        let number: Int
        let available: Bool
    }

    var body: some View {
        if let p = product, let s = store {
            content(p: p, s: s)
                .onAppear {
                    if selectedSize.isEmpty {
                        selectedSize = p.availableSizes.first?.s ?? ""
                    }
                }
        } else {
            Color.clear.onAppear { onBack() }
        }
    }

    private func content(p: Product, s: Store) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(s: s)

                    VStack(alignment: .leading, spacing: 0) {
                        productRow(p: p)
                            .padding(.top, 16)

                        sizesBlock(p: p)
                            .padding(.top, 24)

                        datesBlock()
                            .padding(.top, 24)

                        timesBlock()
                            .padding(.top, 24)

                        howItWorks()
                            .padding(.top, 28)
                            .padding(.bottom, 140)
                    }
                    .padding(.horizontal, 22)
                }
            }

            confirmButton(p: p, s: s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }

    private func header(s: Store) -> some View {
        HStack(spacing: 14) {
            IconButton(icon: "chevron.left", action: onBack)
            VStack(alignment: .leading, spacing: 2) {
                Text("БРОНЬ ПРИМЕРКИ")
                    .font(.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(theme.muted)
                Text(s.name)
                    .font(.serif(22, weight: .regular))
                    .tracking(-0.4)
                    .foregroundStyle(theme.ink)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 58)
        .padding(.bottom, 12)
    }

    private func productRow(p: Product) -> some View {
        HStack(spacing: 12) {
            ProductImage(product: p, cornerRadius: 10, showImageId: false)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(p.brand.uppercased())
                    .font(.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(theme.muted)
                Text(p.title)
                    .font(.sans(14, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text(p.price.formattedRubles)
                    .font(.mono(12, weight: .semibold))
                    .foregroundStyle(theme.ink)
            }
            Spacer()
        }
        .padding(14)
        // Product summary row at the top of booking — liquid glass so
        // it feels like chrome wrapping the product rather than a slab.
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }

    private func sizesBlock(p: Product) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("РАЗМЕР")
            FlowLayout(spacing: 8) {
                ForEach(p.availableSizes) { sz in
                    SizeChip(
                        label: sz.s,
                        available: true,
                        selected: selectedSize == sz.s,
                        minWidth: 50,
                        height: 50,
                        cornerRadius: 14
                    ) { selectedSize = sz.s }
                }
            }
        }
    }

    private func datesBlock() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("ДАТА")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { d in
                        Button {
                            if d.available { selectedDate = d.number }
                        } label: {
                            VStack(spacing: 2) {
                                Text(d.label.uppercased())
                                    .font(.mono(10))
                                    .tracking(1.2)
                                Text("\(d.number)")
                                    .font(.serif(22, weight: .semibold))
                            }
                            .frame(width: 70)
                            .padding(.vertical, 12)
                            .foregroundStyle(selectedDate == d.number ? theme.accentInk : (d.available ? theme.ink : theme.muted))
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedDate == d.number ? theme.ink : .clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedDate == d.number ? theme.ink : theme.line, lineWidth: 1)
                            )
                            .opacity(d.available ? 1 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .disabled(!d.available)
                    }
                }
            }
        }
    }

    private func timesBlock() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("ВРЕМЯ")
            FlowLayout(spacing: 8) {
                ForEach(times, id: \.self) { t in
                    Button { selectedTime = t } label: {
                        Text(t)
                            .font(.mono(13, weight: .semibold))
                            .foregroundStyle(selectedTime == t ? theme.accentInk : theme.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(selectedTime == t ? theme.ink : .clear))
                            .overlay(Capsule().stroke(selectedTime == t ? theme.ink : theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func howItWorks() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("КАК ЭТО РАБОТАЕТ")
                .font(.mono(9))
                .tracking(1.5)
                .foregroundStyle(theme.accentDeep)
            Text("Магазин отложит вещь на час до начала брони. Не нужно выкупать — просто приходи мерить.")
                .font(.sans(13))
                .lineSpacing(3)
                .foregroundStyle(theme.ink)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.accent.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.mono(10))
            .tracking(1.6)
            .foregroundStyle(theme.muted)
    }

    private func confirmButton(p: Product, s: Store) -> some View {
        VStack {
            PrimaryButton(title: "Забронировать · бесплатно") {
                let booking = Booking(
                    id: UUID(),
                    productId: p.id,
                    storeId: s.id,
                    size: selectedSize,
                    date: Date().addingTimeInterval(TimeInterval((selectedDate - 21) * 86400)),
                    time: selectedTime
                )
                appState.addBooking(booking)
                onConfirmed(booking)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [theme.bg.opacity(0), theme.bg.opacity(0.55), theme.bg.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }
}

struct BookingConfirmedView: View {
    let repository: DataRepository
    let booking: Booking
    let onHome: () -> Void
    let onMyBookings: () -> Void

    @Environment(\.appTheme) private var theme

    private var product: Product? { repository.product(id: booking.productId) }
    private var store: Store? { repository.store(id: booking.storeId) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let p = product, let s = store {
                successBlock(p: p, s: s)
            }
            Spacer()
            ctaRow
        }
        .padding(.horizontal, 22)
        .padding(.top, 60)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }

    private func successBlock(p: Product, s: Store) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(theme.accent).frame(width: 90, height: 90)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(theme.accentInk)
            }

            Text("Забронировали!")
                .font(.serif(32, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)

            Text(successSubtitle(p: p, s: s))
                .font(.sans(14))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: 300)

            HStack(spacing: 12) {
                ProductImage(product: p, cornerRadius: 10, showImageId: false)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.title)
                        .font(.sans(13, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Text("\(p.brand) · размер \(booking.size)")
                        .font(.mono(11))
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            // Success screen product callout — glass keeps this chip
            // consistent with the rest of the app's floating cards.
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
            )
        }
    }

    private var ctaRow: some View {
        HStack(spacing: 10) {
            SecondaryButton(title: "На главную", action: onHome)
            PrimaryButton(title: "Мои брони", action: onMyBookings)
        }
    }

    private func successSubtitle(p: Product, s: Store) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: "ru_RU")
        let dateString = formatter.string(from: booking.date)
        return "\(dateString) · \(booking.time) · \(s.name). Размер \(booking.size) отложен на час после начала примерки."
    }
}
