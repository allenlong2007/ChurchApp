import Foundation
import Combine

/// Loads media items for the app.
///
/// Content source order:
/// 1. The bundled `content.json` (ships in the app, always available offline).
/// 2. A cached copy of the last successfully fetched remote manifest, if any.
/// 3. On launch (and on manual refresh) it tries to fetch `remoteManifestURL`.
///    If that succeeds, the result replaces what's shown and is cached to disk,
///    so editing that one JSON file is enough to publish new podcasts/hymns to
///    every installed copy of the app -- no App Store update required.
///
/// To go from this to a real database later, replace the body of `refresh()`
/// with a call to your backend (Firebase/Supabase/custom API) that returns the
/// same `[MediaItem]` shape. Nothing else in the app needs to change.
@MainActor
final class ContentRepository: ObservableObject {
    static let shared = ContentRepository()

    /// Point this at a JSON file you control (GitHub raw URL, S3/Cloud Storage
    /// public object, a Google Sheet published as JSON, etc). Leave it nil to
    /// run entirely off the bundled file.
    static let remoteManifestURL: URL? = URL(string: "https://firebasestorage.googleapis.com/v0/b/church-app2-7779d.firebasestorage.app/o/content.json?alt=media")

    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var seriesInfo: [PodcastSeriesInfo] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    /// Top-level folders for the given media type and app language (podcasts
    /// and hymns can each have their own folders): the manifest's declared
    /// top-level series that hold an episode of that type in that language --
    /// directly, or (for a parent folder like "Pre-Study", which has no items
    /// of its own, only sub-folders) via a descendant that does -- plus any
    /// series found on an actual item that isn't declared (so a folder is
    /// never silently missing just because it wasn't added). A folder with
    /// nothing in the current language is hidden rather than shown empty.
    func topLevelSeries(for type: MediaType, appLanguage: String) -> [PodcastSeriesInfo] {
        let language = contentLanguageCode(forAppLanguage: appLanguage)
        let declared = seriesInfo.filter {
            $0.parent == nil && FolderVisibility.hasEpisodes(
                named: $0.name, type: type, language: language, items: items, seriesInfo: seriesInfo
            )
        }
        let declaredNames = Set(declared.map(\.name))
        let found = Set(items.compactMap { item -> String? in
            guard item.type == type, item.language == language, let name = item.series else { return nil }
            // Only surface as top-level if it isn't itself declared as a sub-folder.
            return seriesInfo.contains { $0.name == name && $0.parent != nil } ? nil : name
        })
        let extra = found.subtracting(declaredNames).sorted().map {
            PodcastSeriesInfo(name: $0, parent: nil, imageURL: nil, speaker: nil, nameZh: nil, speakerZh: nil)
        }
        return declared + extra
    }

    /// Sub-folders declared under the given parent folder name (e.g. the
    /// books under "Pre-Study") that have something in the app's current
    /// language. Empty for a leaf folder.
    func subSeries(of parentName: String, type: MediaType, appLanguage: String) -> [PodcastSeriesInfo] {
        let language = contentLanguageCode(forAppLanguage: appLanguage)
        return seriesInfo.filter {
            $0.parent == parentName && FolderVisibility.hasEpisodes(
                named: $0.name, type: type, language: language, items: items, seriesInfo: seriesInfo
            )
        }
    }

    /// Looks up a series' catalog entry by its (language-independent) name,
    /// e.g. to get its localized display name/speaker for a nav title.
    func seriesInfo(named name: String) -> PodcastSeriesInfo? {
        seriesInfo.first { $0.name == name }
    }

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("content_cache.json")
    }()

    /// The item ids known as of the last successful check, used to detect
    /// which ids in a freshly-fetched manifest are actually new (rather than
    /// just present -- every item would look "new" without this baseline).
    /// Persisted in UserDefaults, not the disk cache, since it needs to
    /// survive independently of what's currently displayed.
    private let knownIDsKey = "contentRepository.knownItemIDs"
    private let hasSeededKnownIDsKey = "contentRepository.hasSeededKnownItemIDs"

    /// How often content refreshes on its own -- so new podcasts/hymns
    /// uploaded through the content-uploader reach people who already have
    /// the app open without them force-quitting it or hitting Refresh.
    private static let autoRefreshInterval: TimeInterval = 3600
    private var autoRefreshTimer: Timer?

    private init() {
        apply(Self.loadBundled())
        if let cached = loadCache() {
            apply(cached)
        }
        if !UserDefaults.standard.bool(forKey: hasSeededKnownIDsKey) {
            UserDefaults.standard.set(items.map(\.id), forKey: knownIDsKey)
            UserDefaults.standard.set(true, forKey: hasSeededKnownIDsKey)
        }
        startAutoRefreshTimer()
    }

    private func startAutoRefreshTimer() {
        let timer = Timer(timeInterval: Self.autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        // `.common` keeps this firing while the user is actively scrolling,
        // not just when the run loop is otherwise idle.
        RunLoop.main.add(timer, forMode: .common)
        autoRefreshTimer = timer
    }

    /// Call when the app returns to the foreground -- catches up on content
    /// that arrived while backgrounded (when the timer above wasn't
    /// running), but only if it's actually been a while, so quickly
    /// switching back and forth doesn't trigger a fetch every time.
    func refreshIfStale() async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < Self.autoRefreshInterval {
            return
        }
        await refresh()
    }

    private func apply(_ manifest: ContentManifest) {
        items = manifest.items
        seriesInfo = manifest.series ?? []
        prefetchImages(for: manifest)
    }

    /// Warms the shared URL cache with every cover image the manifest
    /// references (folder covers and episode art), regardless of whether
    /// the user has actually opened that folder yet -- so pictures still
    /// show up when the app is later opened with no connection, not just
    /// for folders already browsed while online. There are only a
    /// handful of distinct images (covers are shared across a series'
    /// episodes), so this is cheap.
    private func prefetchImages(for manifest: ContentManifest) {
        var urlStrings = Set<String>()
        for series in manifest.series ?? [] {
            if let imageURL = series.imageURL { urlStrings.insert(imageURL) }
        }
        for item in manifest.items {
            if let imageURL = item.imageURL { urlStrings.insert(imageURL) }
        }
        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            Task {
                _ = try? await URLSession.shared.data(from: url)
            }
        }
    }

    private static func loadBundled() -> ContentManifest {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ContentManifest.self, from: data) else {
            return ContentManifest(updatedAt: nil, series: nil, items: [])
        }
        return manifest
    }

    private func loadCache() -> ContentManifest? {
        guard let data = try? Data(contentsOf: cacheURL),
              let manifest = try? JSONDecoder().decode(ContentManifest.self, from: data) else {
            return nil
        }
        return manifest
    }

    private func saveCache(_ manifest: ContentManifest) {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: cacheURL)
    }

    func refresh() async {
        guard let url = Self.remoteManifestURL else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let manifest = try JSONDecoder().decode(ContentManifest.self, from: data)
            let previousKnownIDs = Set((UserDefaults.standard.array(forKey: knownIDsKey) as? [String]) ?? [])
            let newItems = manifest.items.filter { !previousKnownIDs.contains($0.id) }
            apply(manifest)
            saveCache(manifest)
            UserDefaults.standard.set(manifest.items.map(\.id), forKey: knownIDsKey)
            lastUpdated = Date()
            if !newItems.isEmpty {
                NotificationManager.shared.notifyNewContent(newItems)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}

/// Whether a folder has anything to show for one media type in one language.
/// Folders are shared by both languages' episodes, so a folder that only has
/// Chinese episodes (or only English ones) is hidden in the other language.
enum FolderVisibility {
    static func hasEpisodes(
        named seriesName: String, type: MediaType, language: ContentLanguage,
        items: [MediaItem], seriesInfo: [PodcastSeriesInfo]
    ) -> Bool {
        if items.contains(where: { $0.series == seriesName && $0.type == type && $0.language == language }) {
            return true
        }
        return seriesInfo.filter { $0.parent == seriesName }.contains {
            hasEpisodes(named: $0.name, type: type, language: language, items: items, seriesInfo: seriesInfo)
        }
    }
}
