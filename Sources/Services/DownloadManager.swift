import Foundation
import Combine

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloadedIDs: Set<String> = []
    @Published private(set) var progress: [String: Double] = [:]

    private let defaultsKey = "downloadedItemIDs"
    private var session: URLSession!
    private var tasks: [String: URLSessionDownloadTask] = [:]

    private nonisolated static var downloadsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override private init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        if let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [String] {
            downloadedIDs = Set(saved)
        }
    }

    func localURL(for item: MediaItem) -> URL? {
        let url = Self.downloadsDirectory.appendingPathComponent(item.id + ".mp3")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isDownloaded(_ item: MediaItem) -> Bool {
        downloadedIDs.contains(item.id)
    }

    func startDownload(_ item: MediaItem) {
        guard !isDownloaded(item), tasks[item.id] == nil, let url = URL(string: item.audioURL) else { return }
        let task = session.downloadTask(with: url)
        task.taskDescription = item.id
        tasks[item.id] = task
        progress[item.id] = 0
        task.resume()
    }

    func cancelDownload(for item: MediaItem) {
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        progress[item.id] = nil
    }

    func delete(_ item: MediaItem) {
        if let url = localURL(for: item) {
            try? FileManager.default.removeItem(at: url)
        }
        downloadedIDs.remove(item.id)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(downloadedIDs), forKey: defaultsKey)
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
    // Called on a background delegate thread. `location` is a temp file that
    // gets deleted as soon as this method returns, so the copy must happen
    // synchronously here -- it cannot be deferred into an async Task.
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        let destination = Self.downloadsDirectory.appendingPathComponent(id + ".mp3")
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: location, to: destination)
        Task { @MainActor in
            DownloadManager.shared.markFinished(id: id)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0, let id = downloadTask.taskDescription else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            DownloadManager.shared.updateProgress(id: id, fraction: fraction)
        }
    }
}
