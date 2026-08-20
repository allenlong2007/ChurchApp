import Foundation
import Combine

/// Loads media items for the app.
///
/// Content source order:
/// 1. The bundled `content.json` (ships in the app, always available offline).
/// 2. A cached copy of the last successfully fetched remote manifest, if any.
/// 3. On launch (and on manual refresh) it tries to fetch `remoteManifestURL`.
///    If that succeeds, the result replaces what's shown and is cached to disk,
///    so editing that one JSON file is enough to publish new sermons/songs to
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
    static let remoteManifestURL: URL? = nil
    // Example once you have a host:
    // static let remoteManifestURL = URL(string: "https://yourchurch.org/app/content.json")

    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("content_cache.json")
    }()

    private init() {
        items = Self.loadBundled()
        if let cached = loadCache() {
            items = cached
        }
    }

    private static func loadBundled() -> [MediaItem] {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ContentManifest.self, from: data) else {
            return []
        }
        return manifest.items
    }

    private func loadCache() -> [MediaItem]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let manifest = try? JSONDecoder().decode(ContentManifest.self, from: data) else {
            return nil
        }
        return manifest.items
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
            items = manifest.items
            saveCache(manifest)
            lastUpdated = Date()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
