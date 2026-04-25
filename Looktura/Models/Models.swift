import Foundation
import CoreLocation

struct Size: Codable, Hashable, Identifiable {
    let s: String
    let a: Bool
    var id: String { s }
}

struct Product: Codable, Identifiable, Hashable {
    let id: String
    let storeId: String
    let title: String
    let brand: String
    let price: Int
    let oldPrice: Int?
    let sizes: [Size]
    let category: String
    let style: String
    let color: String
    let freshHours: Int
    let imageId: String

    var imageURL: URL? {
        URL(string: "https://images.unsplash.com/photo-\(imageId)?w=900&h=1200&fit=crop&q=80&auto=format")
    }

    /// Variations of the product photo used by the DetailView carousel.
    /// Unsplash's `crop` param produces visibly different framings from the
    /// same photo — "center/top/bottom/entropy" gives us a plausible
    /// front/back/detail/lifestyle rotation without needing extra assets.
    var galleryURLs: [URL] {
        let crops = ["center", "top", "bottom", "entropy"]
        return crops.compactMap {
            URL(string: "https://images.unsplash.com/photo-\(imageId)?w=1200&h=1600&fit=crop&crop=\($0)&q=85&auto=format")
        }
    }

    var availableSizes: [Size] { sizes.filter { $0.a } }
    var hasDiscount: Bool { oldPrice != nil && (oldPrice ?? 0) > price }
    var discountPercent: Int {
        guard let old = oldPrice, old > 0 else { return 0 }
        return Int((1.0 - Double(price) / Double(old)) * 100)
    }
}

struct Store: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let vibe: String
    let addr: String
    let district: String
    let hours: String
    let openUntil: String
    let isOpen: Bool
    let distanceKm: Double
    let brands: [String]
    let bio: String
    let cover: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coverURL: URL? { URL(string: cover) }
    var walkingMinutes: Int { max(5, Int(distanceKm * 14)) }
}

enum NotificationKind: String, Codable {
    case restock, booking, new, drop, reminder
}

struct AppNotification: Codable, Identifiable, Hashable {
    let id: String
    let kind: NotificationKind
    let timeLabel: String
    let title: String
    let body: String
    let productId: String?
    let storeId: String?
}

struct CatalogData: Codable {
    let stores: [Store]
    let products: [Product]
    let notifications: [AppNotification]
}

struct Booking: Identifiable, Hashable {
    let id: UUID
    let productId: String
    let storeId: String
    let size: String
    let date: Date
    let time: String
}

enum CollectionMood: String, Codable, CaseIterable, Identifiable {
    case spring, office, guests, evening, travel, wish, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .spring: return "Весна 26"
        case .office: return "Офис"
        case .guests: return "К гостям"
        case .evening: return "Вечер"
        case .travel: return "Поездка"
        case .wish: return "В мечтах"
        case .custom: return "Своё"
        }
    }

    var glyph: String {
        switch self {
        case .spring: return "leaf.fill"
        case .office: return "briefcase.fill"
        case .guests: return "fork.knife"
        case .evening: return "moon.stars.fill"
        case .travel: return "airplane"
        case .wish: return "sparkles"
        case .custom: return "square.stack.3d.up"
        }
    }
}

struct FavCollection: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var mood: CollectionMood
    var productIds: [String]
    var createdAt: Date

    /// Custom glyph chosen in the rich new-collection creator (small serif
    /// sigil like "✦", "◌", "❋" from the design handoff). `nil` for legacy
    /// collections made before the creator existed — those fall back to the
    /// mood's SF Symbol glyph in display helpers.
    var customEmoji: String?

    /// Custom accent hex (e.g. "#528A68") picked alongside the emoji. When
    /// present, UI that shows the collection's chip / puck / preview tints
    /// with this color instead of the global `theme.accent`. `nil` means
    /// "use the theme accent" (legacy behaviour).
    var customAccentHex: String?

    init(id: String = UUID().uuidString,
         name: String,
         mood: CollectionMood = .custom,
         productIds: [String] = [],
         customEmoji: String? = nil,
         customAccentHex: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.mood = mood
        self.productIds = productIds
        self.customEmoji = customEmoji
        self.customAccentHex = customAccentHex
        self.createdAt = createdAt
    }

    // Codable keys are auto-synthesised; the two new fields are optional so
    // decoding older persisted collections (pre-creator) Just Works — they
    // arrive with both customs as nil and fall back to mood.glyph/theme.accent.
}

extension FavCollection {
    /// True when the collection was created via the rich creator (icon + color
    /// pick). Consumers use this to decide whether to render a serif emoji
    /// "puck" or the default SF Symbol moodIcon.
    var hasCustomStyling: Bool {
        (customEmoji?.isEmpty == false) && (customAccentHex?.isEmpty == false)
    }
}

enum FreshnessLevel {
    case fresh, recent, stale

    static func from(hours: Int) -> FreshnessLevel {
        if hours < 2 { return .fresh }
        if hours < 8 { return .recent }
        return .stale
    }

    var label: String {
        switch self {
        case .fresh: return "Свежее"
        case .recent: return "Недавно"
        case .stale: return "Старое"
        }
    }
}

enum ProductStyle: String, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case vintage = "Vintage"
    case casual = "Casual"
    case street = "Street"
    case tailoring = "Tailoring"
    var id: String { rawValue }
}

enum StandardSize: String, CaseIterable, Identifiable {
    case xs = "XS", s = "S", m = "M", l = "L", xl = "XL"
    var id: String { rawValue }
}

struct NamedColor: Identifiable, Hashable {
    let name: String
    let hex: String
    var id: String { name }
}

enum Catalog {
    static let categories = ["Всё","Верхняя одежда","Верх","Брюки","Джинсы","Платья","Юбки","Трикотаж","Жакеты","Жилеты"]

    /// Keep this list aligned with the distinct `color` values the catalog
    /// actually emits in mock_data.json — otherwise color chips can refer to
    /// filters that match zero products (dead UI).
    static let namedColors: [NamedColor] = [
        .init(name: "Black", hex: "#111010"),
        .init(name: "White", hex: "#EEEEEE"),
        .init(name: "Ivory", hex: "#F1EADC"),
        .init(name: "Cream", hex: "#E8DDC5"),
        .init(name: "Oat", hex: "#CBB78F"),
        .init(name: "Sand", hex: "#D4C4B0"),
        .init(name: "Camel", hex: "#B8A99A"),
        .init(name: "Stone", hex: "#B0A89C"),
        .init(name: "Grey", hex: "#A8AEB0"),
        .init(name: "Khaki", hex: "#7A7250"),
        .init(name: "Olive", hex: "#5C6F5C"),
        .init(name: "Navy", hex: "#3A4550"),
        .init(name: "Indigo", hex: "#2B3A5C"),
        .init(name: "Burgundy", hex: "#6B4F4F"),
        .init(name: "Chocolate", hex: "#4A332A")
    ]
}

extension Int {
    var formattedRubles: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.groupingSeparator = " "
        let formatted = formatter.string(from: NSNumber(value: self)) ?? "\(self)"
        return "\(formatted) ₽"
    }
}
