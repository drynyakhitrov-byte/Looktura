import SwiftUI

struct ProfileView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let onOpenNotifications: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL

    @State private var showSignOutAlert = false
    @State private var showProfileEditor = false
    @State private var showDistrictSheet = false
    @State private var showHelpSheet = false
    @State private var showLegalSheet = false
    @State private var showQuizConfirm = false
    @State private var comingSoonMessage: String? = nil
    @State private var showComingSoon = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                    .padding(.horizontal, 22)
                    .padding(.top, 58)
                    .padding(.bottom, 10)

                profileHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                stats
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                upcomingSection
                    .padding(.horizontal, 22)
                    .padding(.top, 24)

                settingsSection
                    .padding(.horizontal, 22)
                    .padding(.top, 28)

                legalSection
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                footer
                    .padding(.top, 20)
                    .padding(.bottom, 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .alert("Выйти из аккаунта?", isPresented: $showSignOutAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Выйти", role: .destructive) { signOut() }
        } message: {
            Text("Сбросятся избранное, коллекции и брони. Онбординг запустится заново.")
        }
        .alert("Запустить подбор заново?", isPresented: $showQuizConfirm) {
            Button("Отмена", role: .cancel) { }
            Button("Запустить") { appState.hasCompletedOnboarding = false }
        } message: {
            Text("Пройдёшь короткий квиз о стилях, размерах и бюджете — подбор под тебя обновится.")
        }
        .alert(comingSoonMessage ?? "Скоро", isPresented: $showComingSoon) {
            Button("Ок", role: .cancel) { }
        }
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorSheet(appState: appState, onClose: { showProfileEditor = false })
                .environment(\.appTheme, theme)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .sheet(isPresented: $showDistrictSheet) {
            DistrictSheet(onClose: { showDistrictSheet = false })
                .environment(\.appTheme, theme)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpSheet(onClose: { showHelpSheet = false })
                .environment(\.appTheme, theme)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .sheet(isPresented: $showLegalSheet) {
            LegalSheet(onClose: { showLegalSheet = false })
                .environment(\.appTheme, theme)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
    }

    private var topBar: some View {
        HStack {
            Wordmark(size: 13)
            Spacer()
            HStack(spacing: 8) {
                IconButton(icon: appState.themeKey == .ivory ? "moon" : "sun.max") {
                    appState.themeKey = appState.themeKey == .ivory ? .black : .ivory
                }
                IconButton(icon: "bell", action: onOpenNotifications)
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                LinearGradient(colors: [theme.accent, theme.accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(Circle())
                Text("А")
                    .font(.serif(28, weight: .semibold))
                    .foregroundStyle(theme.accentInk)
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 4) {
                Text("Аня Петрова")
                    .font(.serif(26, weight: .regular))
                    .tracking(-0.5)
                    .foregroundStyle(theme.ink)
                Text("Москва · Тверская · с октября 2025")
                    .font(.sans(13))
                    .foregroundStyle(theme.muted)
            }
            Spacer()
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            StatCard(number: "\(appState.favorites.count)", label: "СВАЙПОВ →")
            StatCard(number: "\(appState.bookings.count)", label: "ПРИМЕРОК")
            StatCard(number: "4", label: "ПОКУПОК")
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("ПРЕДСТОЯЩИЕ ПРИМЕРКИ")

            if appState.bookings.isEmpty {
                UpcomingBookingRow(day: "АПР", dayNumber: "22", when: "Завтра · 14:00", who: "OBJEKT", what: "Пальто oversized · Totême · M")
                UpcomingBookingRow(day: "АПР", dayNumber: "26", when: "Сб · 17:30", who: "Shelter", what: "Платье-миди · Kruzhok · S")
            } else {
                ForEach(appState.bookings.prefix(3)) { b in
                    let p = repository.product(id: b.productId)
                    let s = repository.store(id: b.storeId)
                    UpcomingBookingRow(
                        day: "АПР",
                        dayNumber: dayNumber(from: b.date),
                        when: "\(shortDay(from: b.date)) · \(b.time)",
                        who: s?.name ?? "",
                        what: "\(p?.title ?? "") · размер \(b.size)"
                    )
                }
            }
        }
    }

    private func dayNumber(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func shortDay(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EE d MMM"
        return f.string(from: date).capitalized
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("НАСТРОЙКИ")
            SettingsGroup {
                SettingRow(icon: "person", label: "Профиль", sub: "Имя, фото, размеры") {
                    showProfileEditor = true
                }
                Divider().background(theme.line)
                SettingRow(icon: "slider.horizontal.3", label: "Подбор", sub: "Стили, бренды, бюджет") {
                    showQuizConfirm = true
                }
                Divider().background(theme.line)
                SettingRow(icon: "bell", label: "Уведомления", sub: "Свежие дропы и брони") {
                    onOpenNotifications()
                }
                Divider().background(theme.line)
                SettingRow(icon: "map", label: "Районы", sub: "Тверская · Патриаршие · +1") {
                    showDistrictSheet = true
                }
                Divider().background(theme.line)
                SettingRow(
                    icon: appState.themeKey == .ivory ? "moon" : "sun.max",
                    label: "Тема",
                    sub: appState.themeKey.label
                ) {
                    appState.themeKey = appState.themeKey == .ivory ? .black : .ivory
                }
            }
        }
    }

    private var legalSection: some View {
        SettingsGroup {
            SettingRow(icon: "questionmark.circle", label: "Помощь") {
                showHelpSheet = true
            }
            Divider().background(theme.line)
            SettingRow(icon: "doc.text", label: "Условия и приватность") {
                showLegalSheet = true
            }
            Divider().background(theme.line)
            SettingRow(icon: "rectangle.portrait.and.arrow.right", label: "Выйти", danger: true) {
                showSignOutAlert = true
            }
        }
    }

    private var footer: some View {
        Text("LOOKTURA · v 1.0 · MADE IN MOSCOW")
            .font(.mono(10))
            .tracking(1.5)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.mono(10))
            .tracking(1.6)
            .foregroundStyle(theme.muted)
    }

    private func signOut() {
        appState.favorites.removeAll()
        appState.collections.removeAll()
        appState.bookings.removeAll()
        appState.hasCompletedOnboarding = false
        appState.selectedTab = .feed
    }
}

private struct StatCard: View {
    let number: String
    let label: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(number)
                .font(.serif(28, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text(label)
                .font(.mono(9))
                .tracking(1.2)
                .foregroundStyle(theme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Profile stat cards — glass row so the numbers float instead
        // of sitting on an opaque tile.
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }
}

private struct UpcomingBookingRow: View {
    let day: String
    let dayNumber: String
    let when: String
    let who: String
    let what: String

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(day)
                    .font(.mono(8, weight: .semibold))
                    .foregroundStyle(theme.accentInk.opacity(0.85))
                Text(dayNumber)
                    .font(.serif(18, weight: .semibold))
                    .foregroundStyle(theme.accentInk)
            }
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(theme.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(when) · \(who)")
                    .font(.sans(13, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(what)
                    .font(.sans(12))
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.muted)
        }
        .padding(14)
        // Upcoming booking rows — floating glass cards over the feed.
        .liquidGlassInteractive(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        // Settings container — one continuous glass panel grouping
        // the rows with a hairline stroke for edge definition.
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.clear)
        )
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }
}

private struct SettingRow: View {
    let icon: String
    let label: String
    var sub: String? = nil
    var danger: Bool = false
    var action: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(danger ? theme.danger.opacity(0.12) : theme.pill)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(danger ? theme.danger : theme.ink)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.sans(14, weight: .medium))
                        .foregroundStyle(danger ? theme.danger : theme.ink)
                    if let sub {
                        Text(sub)
                            .font(.sans(12))
                            .foregroundStyle(theme.muted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheets

private struct ProfileEditorSheet: View {
    @Bindable var appState: AppState
    let onClose: () -> Void
    @Environment(\.appTheme) private var theme

    @State private var name: String = "Аня Петрова"
    @State private var city: String = "Москва"
    @State private var size: String = "M"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    formField(title: "ИМЯ", text: $name)
                    formField(title: "ГОРОД", text: $city)
                    formField(title: "ОСНОВНОЙ РАЗМЕР", text: $size)
                    Text("Данные хранятся на устройстве. В MVP редактирование профиля сохраняется локально.")
                        .font(.sans(12))
                        .foregroundStyle(theme.muted)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            // Tint the glass substrate so ivory / black still reads as
            // distinct without killing the blur the sheet sits on.
            .background(theme.bg.opacity(0.35).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { onClose() }.foregroundStyle(theme.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { onClose() }.foregroundStyle(theme.ink).fontWeight(.semibold)
                }
                ToolbarItem(placement: .principal) {
                    Text("Профиль").font(.serif(17, weight: .semibold)).foregroundStyle(theme.ink)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
    }

    private func formField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.mono(10)).tracking(1.6).foregroundStyle(theme.muted)
            TextField("", text: text)
                .font(.sans(15))
                .foregroundStyle(theme.ink)
                .padding(14)
                // Glass input field — consistent with NewCollectionSheet.
                .liquidGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                )
        }
    }
}

private struct DistrictSheet: View {
    let onClose: () -> Void
    @Environment(\.appTheme) private var theme
    @State private var selection: Set<String> = ["Тверская", "Патриаршие"]

    private let districts = ["Тверская", "Патриаршие", "Китай-город", "Хамовники", "Дорогомилово", "Басманный"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Покажем магазины и примерки только в выбранных районах.")
                        .font(.sans(13))
                        .foregroundStyle(theme.muted)
                        .padding(.bottom, 8)

                    ForEach(districts, id: \.self) { d in
                        Button {
                            if selection.contains(d) { selection.remove(d) } else { selection.insert(d) }
                        } label: {
                            HStack {
                                Text(d).font(.sans(15, weight: .medium)).foregroundStyle(theme.ink)
                                Spacer()
                                Image(systemName: selection.contains(d) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selection.contains(d) ? theme.ink : theme.muted)
                            }
                            .padding(16)
                            // Glass list row for district selection.
                            .liquidGlassInteractive(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        selection.contains(d) ? theme.accent.opacity(0.45) : Color.white.opacity(0.22),
                                        lineWidth: selection.contains(d) ? 1.2 : 0.6
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            // Tint the glass substrate so ivory / black still reads as
            // distinct without killing the blur the sheet sits on.
            .background(theme.bg.opacity(0.35).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { onClose() }.foregroundStyle(theme.ink).fontWeight(.semibold)
                }
                ToolbarItem(placement: .principal) {
                    Text("Районы").font(.serif(17, weight: .semibold)).foregroundStyle(theme.ink)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
    }
}

private struct HelpSheet: View {
    let onClose: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    helpItem(icon: "questionmark.bubble", title: "Как работает LOOKTURA?", text: "Листай карточки в Swipe — то, что нравится, свайпай вправо. Потом открой избранное, построй маршрут и брони примерки в магазинах за 2 минуты.")
                    helpItem(icon: "mappin.and.ellipse", title: "Где сейчас работает?", text: "Центр Москвы — Тверская, Патриаршие, Китай-город. Новые районы подключаем.")
                    helpItem(icon: "creditcard", title: "Оплата и бронь", text: "Бронь примерки — бесплатна. Отменить можно в разделе «Профиль» → «Предстоящие примерки».")
                    helpItem(icon: "envelope", title: "Связаться с нами", text: "hello@looktura.app — ответим в течение суток.")
                    Button {
                        if let url = URL(string: "mailto:hello@looktura.app") { openURL(url) }
                    } label: {
                        Text("Написать в поддержку")
                            .font(.sans(15, weight: .semibold))
                            .foregroundStyle(theme.accentInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Capsule().fill(theme.ink))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            // Tint the glass substrate so ivory / black still reads as
            // distinct without killing the blur the sheet sits on.
            .background(theme.bg.opacity(0.35).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { onClose() }.foregroundStyle(theme.muted)
                }
                ToolbarItem(placement: .principal) {
                    Text("Помощь").font(.serif(17, weight: .semibold)).foregroundStyle(theme.ink)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
    }

    private func helpItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(theme.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.pill))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.sans(14, weight: .semibold)).foregroundStyle(theme.ink)
                Text(text).font(.sans(13)).lineSpacing(3).foregroundStyle(theme.muted)
            }
        }
    }
}

private struct LegalSheet: View {
    let onClose: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    legalBlock(title: "ПОЛЬЗОВАТЕЛЬСКОЕ СОГЛАШЕНИЕ", text: "LOOKTURA — сервис подбора одежды в районных магазинах. Используя приложение, ты соглашаешься с условиями: мы обрабатываем только минимум данных (избранное, брони), не передаём их третьим лицам без согласия. Ты можешь удалить аккаунт в любой момент через «Выйти».")
                    legalBlock(title: "ОБРАБОТКА ДАННЫХ", text: "На устройстве хранятся: избранное, коллекции, брони, настройки темы и района. На сервер отправляются только анонимные метрики использования.")
                    legalBlock(title: "КОНТАКТЫ", text: "ИП Хитров А. · hello@looktura.app · г. Москва")
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            // Tint the glass substrate so ivory / black still reads as
            // distinct without killing the blur the sheet sits on.
            .background(theme.bg.opacity(0.35).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { onClose() }.foregroundStyle(theme.muted)
                }
                ToolbarItem(placement: .principal) {
                    Text("Условия").font(.serif(17, weight: .semibold)).foregroundStyle(theme.ink)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
    }

    private func legalBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.mono(10)).tracking(1.6).foregroundStyle(theme.muted)
            Text(text).font(.sans(14)).lineSpacing(4).foregroundStyle(theme.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Legal / policy block — glass panel consistent with the
        // rest of the app's floating card chrome.
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }
}
