import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()

    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var rate: Float = 1.0

    private var player: AVPlayer?
    private var timeObserver: Any?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play(_ item: MediaItem, from localURL: URL? = nil) {
        let url = localURL ?? URL(string: item.audioURL)
        guard let url else { return }

        if currentItem?.id != item.id {
            removeTimeObserver()
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            currentItem = item
            currentTime = 0
            duration = Double(item.durationSeconds ?? 0)
            addTimeObserver()

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.isPlaying = false }
            }
        }

        player?.rate = rate
        player?.play()
        isPlaying = true
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.rate = rate
            player.play()
        }
        isPlaying.toggle()
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func skip(_ seconds: Double) {
        seek(to: max(0, currentTime + seconds))
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying {
            player?.rate = newRate
        }
    }

    private func addTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if let total = player.currentItem?.duration.seconds, total.isFinite {
                self.duration = total
            }
        }
    }

    private func removeTimeObserver() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
    }
}
