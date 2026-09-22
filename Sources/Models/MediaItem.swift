import Foundation

enum MediaType: String, Codable, CaseIterable {
    case podcast
    case hymn
    case video
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
    /// The media file's URL -- an audio file for `.podcast`/`.hymn`, or a
    /// video file for `.video`. Named `audioURL` since that was the only
    /// kind of media this app had when the field was added; kept as-is
    /// rather than renamed, since renaming a manifest field would need
    /// every already-published `content.json` (and the upload tooling) to
    /// change in lockstep.
    let audioURL: String
    let imageURL: String?
    let language: ContentLanguage
    /// Position within its series+language group (e.g. episode 1, 2, 3...).
    /// Nil falls back to whatever order the manifest lists items in.
    let order: Int?

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

/// A podcast folder. Top-level folders have `parent == nil` (e.g. "Morning
/// Watch Guide"); a folder can itself hold sub-folders instead of episodes
/// directly (e.g. "Pre-Study" holding "Genesis", "Exodus", ...), identified
/// by other entries whose `parent` equals this folder's `name`.
struct PodcastSeriesInfo: Codable, Identifiable, Hashable {
    let name: String
    let parent: String?
    let imageURL: String?
    let speaker: String?

    var id: String { parent.map { "\($0)/\(name)" } ?? name }
}

struct ContentManifest: Codable {
    let updatedAt: String?
    /// Known podcast series/folders, shown even before any episode has been
    /// published under them. Any series name found on an item but missing
    /// here is still shown as a plain top-level folder -- this list just
    /// adds cover art, speaker info, and lets an empty or parent folder
    /// exist ahead of its first episode.
    let series: [PodcastSeriesInfo]?
    let items: [MediaItem]
}
