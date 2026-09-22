import SwiftUI
import Foundation

struct HomeView: View {
    @EnvironmentObject private var repository: ContentRepository
    @EnvironmentObject private var downloads: DownloadManager
    @AppStorage(appLanguageStorageKey) private var appLanguage: String = "en"
    @State private var section: HomeSection = .featured
    @State private var searchText = ""
    @State private var path = NavigationPath()
    @State private var showingNotificationSettings = false

    /// The flat, language-filtered list for the current section. For
    /// Featured this is every item newest-first; for Podcasts this is only
    /// used while searching -- browsing normally goes through the series
    /// folders instead.
    private var filteredItems: [MediaItem] {
        var items: [MediaItem]
        switch section {
        case .featured:
            items = repository.items
        case .podcasts:
            items = repository.items.filter { $0.type == .podcast }
        case .hymns:
            items = repository.items.filter { $0.type == .hymn }
        case .videos:
            items = repository.items.filter { $0.type == .video }
        case .downloads:
            items = repository.items.filter { downloads.isDownloaded($0) }
        }
        items = items.matchingAppLanguage(appLanguage)
        if section == .featured {
            items = items.sorted { ($0.dateAddedValue ?? .distantPast) > ($1.dateAddedValue ?? .distantPast) }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.speaker ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    searchBar
                    categoryGrid
                    itemsSection
                }
                .padding(.vertical, 16)
            }
            .background(Theme.pageBackground)
            .refreshable {
                await repository.refresh()
            }
            .navigationDestination(for: MediaItem.self) { item in
                if item.type == .video {
                    VideoPlayerView(item: item)
                } else {
                    PlayerView(item: item)
                }
            }
            .navigationDestination(for: PodcastSeriesRoute.self) { route in
                PodcastSeriesEpisodesView(seriesName: route.name, mediaType: route.mediaType)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsSheet()
            }
        }
        .onDisappear {
            // Reset to a clean Home tab whenever the user switches to
            // Downloads or Me, so coming back to Home always starts at
            // Featured instead of wherever they left off (e.g. mid-episode
            // player, or a folder drilled into).
            path = NavigationPath()
            section = .featured
            searchText = ""
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.white)
                .frame(width: 52, height: 52)
                .overlay(
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                )
                .overlay(Circle().strokeBorder(Theme.flareGradient.opacity(0.35), lineWidth: 1.25))

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.mint.opacity(0.75))
                TextField("Search", text: $searchText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .themeCardShadow()

            Button {
                showingNotificationSettings = true
            } label: {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(Theme.mint.opacity(0.75))
            }
        }
        .padding(.horizontal)
    }

    private var categoryGrid: some View {
        HStack(spacing: 12) {
            ForEach(HomeSection.allCases) { option in
                Button {
                    section = option
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(option.gradient)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: option.iconName)
                                    .foregroundStyle(.white)
                                    .font(.system(size: 21, weight: .medium))
                            )
                            .overlay(
                                Circle()
                                    .stroke(option.tintColor.opacity(0.5), lineWidth: section == option ? 2.5 : 0)
                                    .padding(-4)
                            )
                            .shadow(color: option.tintColor.opacity(section == option ? 0.35 : 0), radius: 8, y: 3)
                        Text(option.titleKey)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(section == option ? option.tintColor : .secondary)
                            .fontWeight(section == option ? .semibold : .regular)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var itemsSection: some View {
        if searchText.isEmpty && section == .featured {
            featuredTabSection
        } else if searchText.isEmpty && section == .podcasts {
            foldersSection(mediaType: .podcast, title: "Podcasts")
        } else if searchText.isEmpty && section == .hymns {
            foldersSection(mediaType: .hymn, title: "Hymns")
        } else if searchText.isEmpty && section == .videos {
            foldersSection(mediaType: .video, title: "Videos")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(section.titleKey)
                    .font(.themeHeading(17))
                    .padding(.horizontal)

                if filteredItems.isEmpty {
                    Text("No items yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                MediaRowView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    /// Newest item first as a large hero card, everything else below it as a
    /// normal list -- always reflects whatever was most recently added,
    /// since filteredItems for .featured is sorted by dateAdded descending.
    @ViewBuilder
    private var featuredTabSection: some View {
        let items = filteredItems
        if items.isEmpty {
            Text("No items yet")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                NavigationLink(value: items[0]) {
                    FeaturedHeroCard(item: items[0])
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                if items.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("More")
                            .font(.themeHeading(17))
                            .padding(.horizontal)

                        LazyVStack(spacing: 10) {
                            ForEach(items.dropFirst()) { item in
                                NavigationLink(value: item) {
                                    MediaRowView(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    /// Folders for the given media type, followed by any items of that
    /// type that aren't in a folder at all -- so an item is never hidden
    /// just because it wasn't assigned a series.
    private func foldersSection(mediaType: MediaType, title: LocalizedStringKey) -> some View {
        let ungrouped = repository.items
            .filter { $0.type == mediaType && $0.series == nil }
            .matchingAppLanguage(appLanguage)

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.themeHeading(17))
                .padding(.horizontal)

            LazyVStack(spacing: 10) {
                ForEach(repository.topLevelSeries(for: mediaType)) { series in
                    let children = repository.subSeries(of: series.name)
                    let episodes = repository.items
                        .filter { $0.type == mediaType && $0.series == series.name }
                        .matchingAppLanguage(appLanguage)
                    NavigationLink(value: PodcastSeriesRoute(name: series.name, mediaType: mediaType)) {
                        PodcastFolderCard(
                            name: series.name,
                            imageURL: series.imageURL,
                            speaker: series.speaker,
                            episodes: episodes,
                            childCount: children.isEmpty ? nil : children.count
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(ungrouped) { item in
                    NavigationLink(value: item) {
                        MediaRowView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ContentRepository.shared)
        .environmentObject(DownloadManager.shared)
}
