import SwiftUI
import UIKit

/// A drop-in replacement for `AsyncImage` that retries a failed load a
/// couple of times before giving up. SwiftUI's stock `AsyncImage` never
/// retries once a load fails or its task is cancelled mid-scroll (a
/// LazyVStack row going off then back on screen can cancel the underlying
/// task) -- so a single row can get stuck showing its placeholder forever
/// even though the URL and image data are perfectly valid. That's what
/// caused isolated "missing picture" rows despite the manifest being
/// correct.
struct RemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var attempt = 0

    private let maxAttempts = 3

    /// Seeds `uiImage` synchronously from the in-memory cache when
    /// possible, so a cover that's already been shown once during this
    /// app run (e.g. the same series cover on a different episode) never
    /// flashes its placeholder again -- `.task` bodies always run
    /// asynchronously relative to a view's first render, so without this
    /// there'd be at least one blank frame even for already-cached images.
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        let cached = url.flatMap { ImageMemoryCache.shared.image(for: $0) }
        _uiImage = State(initialValue: cached)
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: TaskKey(url: url, attempt: attempt)) {
            await load()
        }
    }

    private struct TaskKey: Equatable {
        let url: URL?
        let attempt: Int
    }

    private func load() async {
        guard let url, uiImage == nil else { return }
        if let cached = ImageMemoryCache.shared.image(for: url) {
            uiImage = cached
            return
        }
        if let image = await fetch(url: url, cachePolicy: .useProtocolCachePolicy) {
            uiImage = image
            ImageMemoryCache.shared.store(image, for: url)
            return
        }
        // The normal request failed -- most likely there's no network
        // connection right now. Fall back to whatever was cached from a
        // previous successful load, ignoring staleness, so cover art keeps
        // showing while offline instead of falling back to the placeholder.
        if let image = await fetch(url: url, cachePolicy: .returnCacheDataDontLoad) {
            uiImage = image
            ImageMemoryCache.shared.store(image, for: url)
            return
        }
        guard attempt < maxAttempts - 1 else { return }
        try? await Task.sleep(nanoseconds: 500_000_000)
        attempt += 1
    }

    private func fetch(url: URL, cachePolicy: URLRequest.CachePolicy) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = cachePolicy
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        return image
    }
}

/// A small, always-available in-memory cache of already-decoded images,
/// layered above the disk-backed `URLCache` -- reading from `URLCache`
/// still requires an async round trip, so it can't fill a `@State`
/// property before a view's first render. This can, via `RemoteImage`'s
/// `init`. Not actor-isolated (just lock-protected) so it can be read
/// synchronously from any context, including a view's `init`.
private final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()

    private let lock = NSLock()
    private var storage: [URL: UIImage] = [:]

    func image(for url: URL) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return storage[url]
    }

    func store(_ image: UIImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        storage[url] = image
    }
}
