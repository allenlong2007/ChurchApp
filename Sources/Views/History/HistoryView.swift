import SwiftUI

/// Carries both the item and where to resume it -- a plain `MediaItem` route
/// (used elsewhere for "start from 0:00") can't express a resume position.
struct HistoryPlaybackRoute: Hashable {
    let item: MediaItem
    let startAt: Double
}

struct HistoryView: View {
    @EnvironmentObject private var repository: ContentRepository
    @EnvironmentObject private var history: PlaybackHistoryManager

    /// Entries paired with their resolved item -- an entry whose item no
    /// longer exists in the current manifest (e.g. removed content) is
    /// left out rather than shown broken.
    private var resolvedEntries: [(entry: PlaybackHistoryEntry, item: MediaItem)] {
        let itemsByID = Dictionary(uniqueKeysWithValues: repository.items.map { ($0.id, $0) })
        return history.entries.compactMap { entry in
            guard let item = itemsByID[entry.itemID] else { return nil }
            return (entry, item)
        }
    }

    var body: some View {
        List {
            if resolvedEntries.isEmpty {
                Text("No listening history yet")
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            ForEach(resolvedEntries, id: \.entry.id) { pair in
                NavigationLink(value: HistoryPlaybackRoute(item: pair.item, startAt: pair.entry.position)) {
                    HistoryRowView(item: pair.item, entry: pair.entry)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
            .onDelete { offsets in
                for index in offsets {
                    history.remove(itemID: resolvedEntries[index].entry.itemID)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.pageBackground)
        .navigationTitle(Text("History"))
        .toolbar {
            if !resolvedEntries.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        history.clear()
                    }
                }
            }
        }
    }
}

private struct HistoryRowView: View {
    let item: MediaItem
    let entry: PlaybackHistoryEntry

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.themeHeading(15.5))
                    .lineLimit(2)
                (Text("Left off at") + Text(verbatim: " \(timeString(entry.position)) · \(entry.lastPlayedAt.formatted(date: .abbreviated, time: .shortened))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .themeCardShadow()
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                RemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    thumbnailPlaceholder
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(Circle())
    }

    private var thumbnailPlaceholder: some View {
        item.type.gradient
        .overlay(
            Image(systemName: item.type.iconName)
                .foregroundStyle(.white)
                .font(.system(size: 20, weight: .semibold))
        )
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
