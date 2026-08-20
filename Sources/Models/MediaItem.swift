import Foundation

enum MediaType: String, Codable, CaseIterable {
    case sermon
    case song
}

enum ContentLanguage: String, Codable {
    case en
    case zh
}

struct MediaItem: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let type: MediaType
    let title: String
    let speaker: String?
    let series: String?
    let category: String?
    let dateAdded: String
    let durationSeconds: Int?
    let audioURL: String
    let imageURL: String?
    let language: ContentLanguage
    let isRecommended: Bool

    var dateAddedValue: Date? {
        ISO8601DateFormatter().date(from: dateAdded)
    }

    var formattedDuration: String {
        guard let seconds = durationSeconds else { return "" }
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

struct ContentManifest: Codable {
    let updatedAt: String?
    let items: [MediaItem]
}
