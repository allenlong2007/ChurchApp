import SwiftUI

/// Identifies a series/folder for navigation -- used for both podcast and
/// hymn folders, so `mediaType` says which kind of item the folder (and its
/// sub-folders) actually holds. A dedicated type (rather than a bare
/// String) keeps this route distinct from any other String-keyed
/// navigation the app adds later.
struct PodcastSeriesRoute: Hashable {
    let name: String
    let mediaType: MediaType
}

/// A folder tile. Pass `childCount` for a parent folder that holds
/// sub-folders instead of episodes (e.g. "Pre-Study"); pass `episodes` for a
/// leaf folder that holds episodes directly.
struct PodcastFolderCard: View {
    let name: String
    let imageURL: String?
    let speaker: String?
    let episodes: [MediaItem]
    var childCount: Int? = nil

    @ViewBuilder
    private var subtitle: some View {
        if let childCount {
            Text(verbatim: "\(childCount)") + Text(childCount == 1 ? " book" : " books")
        } else if episodes.isEmpty {
            Text("No episodes yet")
        } else if let speaker, !speaker.isEmpty {
            Text("By") + Text(verbatim: " \(speaker) · \(episodes.count)") + Text(episodes.count == 1 ? " episode" : " episodes")
        } else {
            Text(verbatim: "\(episodes.count)") + Text(episodes.count == 1 ? " episode" : " episodes")
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            FolderThumbnail(imageURL: imageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.themeHeading(16))
                    .lineLimit(2)
                subtitle
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .themeCardShadow()
    }
}

private struct FolderThumbnail: View {
    let imageURL: String?

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                RemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Theme.folderGradient
        .overlay(
            Image(systemName: "folder.fill")
                .foregroundStyle(.white)
                .font(.system(size: 20, weight: .semibold))
        )
    }
}

/// Shown when a podcast folder is tapped. Renders either a grid of
/// sub-folders (for a parent folder like "Pre-Study") or the folder's
/// episodes (for a leaf folder like "Morning Watch Guide").
struct PodcastSeriesEpisodesView: View {
    let seriesName: String
    let mediaType: MediaType
    @EnvironmentObject private var repository: ContentRepository
    @AppStorage(appLanguageStorageKey) private var appLanguage: String = "en"

    private var children: [PodcastSeriesInfo] {
        repository.subSeries(of: seriesName)
    }

    private var episodes: [MediaItem] {
        repository.items
            .filter { $0.type == mediaType && $0.series == seriesName }
            .matchingAppLanguage(appLanguage)
            .sorted { ($0.order ?? .max) < ($1.order ?? .max) }
    }

    var body: some View {
        ScrollView {
            if !children.isEmpty {
                LazyVStack(spacing: 10) {
                    ForEach(children) { child in
                        let childEpisodes = repository.items
                            .filter { $0.type == mediaType && $0.series == child.name }
                            .matchingAppLanguage(appLanguage)
                        NavigationLink(value: PodcastSeriesRoute(name: child.name, mediaType: mediaType)) {
                            PodcastFolderCard(
                                name: child.name,
                                imageURL: child.imageURL,
                                speaker: child.speaker,
                                episodes: childEpisodes
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            } else if episodes.isEmpty {
                Text("No episodes yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(episodes) { item in
                        NavigationLink(value: item) {
                            MediaRowView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .background(Theme.pageBackground)
        .navigationTitle(Text(seriesName))
        .navigationBarTitleDisplayMode(.inline)
    }
}
