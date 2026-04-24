import SwiftUI

struct NewCollectionSheet: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let seedProductIds: [String]
    let onCreated: (FavCollection) -> Void
    let onClose: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var name: String = ""
    @State private var mood: CollectionMood = .custom
    @FocusState private var nameFocused: Bool

    private let moods: [CollectionMood] = [.spring, .office, .guests, .evening, .travel, .wish, .custom]

    private var seedProducts: [Product] {
        seedProductIds.compactMap { repository.product(id: $0) }
    }

    private var previewProducts: [Product] {
        var ids: [String] = seedProductIds
        let seen = Set(ids)
        let recent = Array(appState.favorites).reversed().filter { !seen.contains($0) }
        ids.append(contentsOf: recent)
        return ids.prefix(3).compactMap { repository.product(id: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber.padding(.top, 8)

            header
                .padding(.horizontal, 22)
                .padding(.top, 14)

            preview
                .padding(.horizontal, 22)
                .padding(.top, 16)

            nameField
                .padding(.horizontal, 22)
                .padding(.top, 20)

            moodRow
                .padding(.top, 18)

            if !seedProducts.isEmpty {
                hint(products: seedProducts)
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
            }

            Spacer(minLength: 0)

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Soft tint — the sheet's .presentationBackground(.thinMaterial) does
        // the heavy lifting; this just nudges the glass toward the theme
        // palette so ivory / black still read as distinct.
        .background(theme.bg.opacity(0.35).ignoresSafeArea())
        .onAppear {
            if name.isEmpty {
                name = suggestedName()
            }
            nameFocused = true
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(theme.line)
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("НОВАЯ КОЛЛЕКЦИЯ")
                .font(.mono(10))
                .tracking(1.8)
                .foregroundStyle(theme.muted)
            Text("Как назовём?")
                .font(.serif(26, weight: .regular))
                .tracking(-0.6)
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 0) {
                ForEach(Array(previewProducts.prefix(3).enumerated()), id: \.element.id) { _, p in
                    ProductImage(product: p, cornerRadius: 0, showImageId: false)
                        .frame(maxWidth: .infinity)
                }
                if previewProducts.count < 3 {
                    ForEach(previewProducts.count..<3, id: \.self) { _ in
                        theme.pill.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                .frame(height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 10) {
                Image(systemName: mood.glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.accent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName().uppercased())
                        .font(.mono(9))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(displayName())
                        .font(.serif(22, weight: .regular))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(14)
        }
        .frame(height: 148)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("НАЗВАНИЕ")
                .font(.mono(9))
                .tracking(1.6)
                .foregroundStyle(theme.muted)
            HStack(spacing: 8) {
                TextField("", text: $name, prompt: Text("Например, Весна 26").foregroundColor(theme.muted))
                    .font(.sans(16, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.sentences)

                if !name.isEmpty {
                    Button {
                        name = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
            )
        }
    }

    private var moodRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("НАСТРОЕНИЕ")
                .font(.mono(9))
                .tracking(1.6)
                .foregroundStyle(theme.muted)
                .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(moods) { m in
                        MoodChip(mood: m, isActive: mood == m) {
                            mood = m
                        }
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private func hint(products: [Product]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.accent)
            Text(hintText(for: products))
                .font(.sans(12))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.accent.opacity(0.1))
        )
    }

    private func hintText(for products: [Product]) -> String {
        if products.count == 1, let first = products.first {
            return "«\(first.title)» добавим первой вещью"
        }
        let n = products.count
        let mod10 = n % 10
        let mod100 = n % 100
        let word: String
        if mod10 == 1 && mod100 != 11 { word = "вещь" }
        else if (2...4).contains(mod10) && !(12...14).contains(mod100) { word = "вещи" }
        else { word = "вещей" }
        return "Добавим \(n) \(word) в новую коллекцию"
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Text("Отмена")
                    .font(.sans(15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .overlay(Capsule().stroke(theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: create) {
                Text("Создать")
                    .font(.sans(15, weight: .semibold))
                    .foregroundStyle(theme.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(theme.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 22)
        // Keep the footer transparent so the sheet's .thinMaterial background
        // reads as one continuous pane of glass.
        .background(Color.clear)
    }

    private func create() {
        let c = appState.createCollection(name: name, mood: mood, seedProductIds: seedProductIds)
        onCreated(c)
    }

    private func displayName() -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? mood.label : trimmed
    }

    private func suggestedName() -> String {
        let existing = Set(appState.collections.map { $0.name.lowercased() })
        let base = mood.label
        if !existing.contains(base.lowercased()) { return base }
        return ""
    }
}

private struct MoodChip: View {
    let mood: CollectionMood
    let isActive: Bool
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: mood.glyph)
                    .font(.system(size: 11, weight: .semibold))
                Text(mood.label)
                    .font(.sans(13, weight: .medium))
            }
            .foregroundStyle(isActive ? theme.accentInk : theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule().fill(isActive ? theme.accent : .clear)
            )
            .overlay(
                Capsule().stroke(isActive ? theme.accent : theme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
