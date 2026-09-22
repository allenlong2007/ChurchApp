import Foundation

struct PlaybackHistoryEntry: Codable, Identifiable, Equatable {
    let itemID: String
    var position: Double
    var lastPlayedAt: Date

    var id: String { itemID }
}

/// Remembers where playback left off for each item the user has played,
/// so the History tab can list everything listened to and resume each one
/// from its exact exit point. One entry per item, updated in place each
/// time that item is played again.
@MainActor
final class PlaybackHistoryManager: ObservableObject {
    static let shared = PlaybackHistoryManager()

    @Published private(set) var entries: [PlaybackHistoryEntry] = []

    private let storageKey = "playbackHistory.entries"

    private init() {
        load()
    }

    func record(itemID: String, position: Double) {
        if let index = entries.firstIndex(where: { $0.itemID == itemID }) {
            entries[index].position = position
            entries[index].lastPlayedAt = Date()
        } else {
            entries.append(PlaybackHistoryEntry(itemID: itemID, position: position, lastPlayedAt: Date()))
        }
        entries.sort { $0.lastPlayedAt > $1.lastPlayedAt }
        save()
    }

    func remove(itemID: String) {
        entries.removeAll { $0.itemID == itemID }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PlaybackHistoryEntry].self, from: data) else { return }
        entries = decoded.sorted { $0.lastPlayedAt > $1.lastPlayedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
