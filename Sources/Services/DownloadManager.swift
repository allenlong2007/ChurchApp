import Foundation
import Combine

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedIDs: Set<String> = []
    @Published private(set) var progress: [String: Double] = [:]

    private let idsDefaultsKey = "downloadedItemIDs"
    private let urlsDefaultsKey = "downloadedItemSourceURLs"
    private var session: URLSession!
    private var tasks: [String: URLSessionDownloadTask] = [:]

    /// The audioURL each id was actually downloaded from. If the manifest's
    /// audioURL for that id ever changes (content replaced, or an id reused
    /// for different content), the on-disk file no longer matches and must
    /// not be treated as downloaded -- otherwise the app would silently keep
    /// playing whatever old audio happens to be cached under that id.
    private var downloadedSourceURLs: [String: String] = [:]

    private nonisolated static var downloadsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override private init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        if let saved = UserDefaults.standard.array(forKey: idsDefaultsKey) as? [String] {
            downloadedIDs = Set(saved)
        }
        if let savedURLs = UserDefaults.standard.dictionary(forKey: urlsDefaultsKey) as? [String: String] {
            downloadedSourceURLs = savedURLs
        }
    }

    /// `.mp3` for audio (podcasts/hymns), `.mp4` for video -- AVFoundation
    /// uses a local file's extension as a hint for which container/codec to
    /// expect, so a video saved under the audio extension can fail to load
    /// correctly even though the downloaded bytes themselves are fine.
    private func fileExtension(for type: MediaType) -> String {
        type == .video ? "mp4" : "mp3"
    }

    func localURL(for item: MediaItem) -> URL? {
        guard isDownloaded(item) else { return nil }
        return Self.downloadsDirectory.appendingPathComponent(item.id + "." + fileExtension(for: item.type))
    }

    func isDownloaded(_ item: MediaItem) -> Bool {
        downloadedIDs.contains(item.id) && downloadedSourceURLs[item.id] == item.audioURL
    }

    /// Call whenever the content list loads or changes. A downloaded file
    /// whose source URL no longer matches the current manifest entry for
    /// that id (content replaced, or an id reused for different content) is
    /// stale and must not keep being treated as downloaded -- otherwise the
    /// app would silently keep playing whatever old audio is cached under
    /// that id instead of the current content.
    func reconcileStaleDownloads(currentItems: [MediaItem]) {
        let currentURLs = Dictionary(uniqueKeysWithValues: currentItems.map { ($0.id, $0.audioURL) })
        let staleIDs = downloadedIDs.filter { currentURLs[$0] != downloadedSourceURLs[$0] }
        guard !staleIDs.isEmpty else { return }
        for id in staleIDs {
            // The stale item may no longer be in currentItems at all, so its
            // type (and thus its file extension) isn't known here -- just
            // try removing both; a missing file is a harmless no-op.
            for ext in ["mp3", "mp4"] {
                try? FileManager.default.removeItem(at: Self.downloadsDirectory.appendingPathComponent(id + "." + ext))
            }
            downloadedIDs.remove(id)
            downloadedSourceURLs[id] = nil
        }
        persist()
    }

    func startDownload(_ item: MediaItem) {
        guard !isDownloaded(item), tasks[item.id] == nil, let url = URL(string: item.audioURL) else { return }
        let task = session.downloadTask(with: url)
        task.taskDescription = item.id + "|" + fileExtension(for: item.type)
        tasks[item.id] = task
        progress[item.id] = 0
        downloadedSourceURLs[item.id] = item.audioURL
        task.resume()
    }

    func cancelDownload(for item: MediaItem) {
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        progress[item.id] = nil
        downloadedSourceURLs[item.id] = nil
    }

    func delete(_ item: MediaItem) {
        let url = Self.downloadsDirectory.appendingPathComponent(item.id + "." + fileExtension(for: item.type))
        try? FileManager.default.removeItem(at: url)
        downloadedIDs.remove(item.id)
        downloadedSourceURLs[item.id] = nil
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(downloadedIDs), forKey: idsDefaultsKey)
        UserDefaults.standard.set(downloadedSourceURLs, forKey: urlsDefaultsKey)
    }

    fileprivate func markFinished(id: String) {
        downloadedIDs.insert(id)
        persist()
        tasks[id] = nil
        progress[id] = nil
    }

    fileprivate func updateProgress(id: String, fraction: Double) {
        progress[id] = fraction
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    /// `taskDescription` is encoded as `"<id>|<ext>"` (see `startDownload`)
    /// since these delegate methods are `nonisolated` and can't safely read
    /// back the item's type from MainActor state. Both callbacks below must
    /// split it back apart -- using the raw string as the id (as this used
    /// to) means every progress/completion update is keyed by "id|ext"
    /// instead of the plain id the UI actually reads (`progress[item.id]`,
    /// `downloadedIDs.contains(item.id)`), so the progress bar set to 0 in
    /// `startDownload` never advances (a permanently empty grey track) and
    /// the download never registers as finished.
    private nonisolated static func parseTaskDescription(_ description: String?) -> (id: String, ext: String)? {
        guard let description else { return nil }
        let parts = description.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    // Called on a background delegate thread. `location` is a temp file that
    // gets deleted as soon as this method returns, so the copy must happen
    // synchronously here -- it cannot be deferred into an async Task.
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let (id, ext) = Self.parseTaskDescription(downloadTask.taskDescription) else { return }
        let destination = Self.downloadsDirectory.appendingPathComponent(id + "." + ext)
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: location, to: destination)
        Task { @MainActor in
            DownloadManager.shared.markFinished(id: id)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0, let (id, _) = Self.parseTaskDescription(downloadTask.taskDescription) else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            DownloadManager.shared.updateProgress(id: id, fraction: fraction)
        }
    }
}
