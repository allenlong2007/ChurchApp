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

    /// Top-level folders for the given media type (podcasts and hymns can
    /// each have their own folders): the manifest's declared top-level
    /// series that actually hold an item of that type -- directly, or (for
    /// a parent folder like "Pre-Study", which has no items of its own,
    /// only sub-folders) via a descendant that does -- plus any series
    /// found on an actual item that isn't declared (so a folder is never
    /// silently missing just because it wasn't added).
    func topLevelSeries(for type: MediaType) -> [PodcastSeriesInfo] {
        let declared = seriesInfo.filter { $0.parent == nil && seriesHasItems(named: $0.name, of: type) }
        let declaredNames = Set(declared.map(\.name))
        let found = Set(items.compactMap { item -> String? in
            guard item.type == type, let name = item.series else { return nil }
            // Only surface as top-level if it isn't itself declared as a sub-folder.
            return seriesInfo.contains { $0.name == name && $0.parent != nil } ? nil : name
        })
        let extra = found.subtracting(declaredNames).sorted().map {
            PodcastSeriesInfo(name: $0, parent: nil, imageURL: nil, speaker: nil)
        }
        return declared + extra
    }

    /// True if the named series has an item of the given type directly, or
    /// (recursively) any sub-folder that does.
    private func seriesHasItems(named seriesName: String, of type: MediaType) -> Bool {
        if items.contains(where: { $0.series == seriesName && $0.type == type }) {
            return true
        }
        return subSeries(of: seriesName).contains { seriesHasItems(named: $0.name, of: type) }
    }

    /// Sub-folders declared under the given parent folder name (e.g. the 5
    /// books under "Pre-Study"). Empty for a leaf folder.
    func subSeries(of parentName: String) -> [PodcastSeriesInfo] {
        seriesInfo.filter { $0.parent == parentName }
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

    private init() {
        apply(Self.loadBundled())
        if let cached = loadCache() {
            apply(cached)
        }
        if !UserDefaults.standard.bool(forKey: hasSeededKnownIDsKey) {
            UserDefaults.standard.set(items.map(\.id), forKey: knownIDsKey)
            UserDefaults.standard.set(true, forKey: hasSeededKnownIDsKey)
        }
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
