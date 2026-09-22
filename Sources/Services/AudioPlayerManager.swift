import Foundation
import AVFoundation
import Combine
import UIKit

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
    private var endObserver: NSObjectProtocol?
    private var lastManualSeekAt: Date?

    private var audioSessionActivated = false

    private init() {
        // Backgrounding the app (home button / app switcher) pauses
        // playback the same way navigating back to a menu inside the app
        // already does (see `PlayerView.onDisappear`) -- this is the one
        // spot that isn't already covered by a SwiftUI `onDisappear`, since
        // the player keeps running in the mini-player across in-app screens.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
        }
    }

    /// `setActive(true)` negotiates the real audio route (Bluetooth/AirPlay/
    /// etc.) and can block the calling thread for a noticeable moment --
    /// this used to run unconditionally in `init()`, which meant it fired
    /// the instant `AudioPlayerManager.shared` was first touched (at app
    /// launch, via RootView's `@StateObject`), before the user had asked to
    /// play anything. That stalled the main thread right as the app opened,
    /// which is what made the very first tap on the UI (e.g. the search
    /// field) feel dropped/laggy. Deferring the whole session setup to here
    /// -- called once, right before playback actually starts -- means launch
    /// no longer pays that cost at all. Not private: `VideoPlayerView` uses
    /// its own separate `AVPlayer` (see its header comment) rather than
    /// going through this class, but still needs the shared session active
    /// and in `.playback` category before it starts, so it calls this too.
    func activateAudioSessionIfNeeded() {
        guard !audioSessionActivated else { return }
        audioSessionActivated = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Starts the given item fresh from 0:00 (or from `startAt`, used when
    /// resuming from History), even if it was already the current item (e.g.
    /// re-entering the player screen for a track that kept playing in the
    /// mini-player).
    func play(_ item: MediaItem, from localURL: URL? = nil, startAt: Double = 0) {
        let url = localURL ?? URL(string: item.audioURL)
        guard let url else { return }

        activateAudioSessionIfNeeded()
        removeObservers()
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        currentItem = item
        currentTime = startAt
        duration = 0
        addTimeObserver()
        loadDuration(for: playerItem)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
                self?.recordHistory()
            }
        }

        if startAt > 0 {
            let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
            player?.seek(to: CMTime(seconds: startAt, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
        }
        player?.rate = rate
        player?.play()
        isPlaying = true
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            recordHistory()
        } else {
            player.rate = rate
            player.play()
        }
        isPlaying.toggle()
    }

    /// Pauses without clearing `currentItem` -- the mini-player keeps
    /// showing what was playing (paused), ready to resume from where it
    /// left off, rather than disappearing.
    func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        recordHistory()
    }

    private func recordHistory() {
        guard let currentItem else { return }
        PlaybackHistoryManager.shared.record(itemID: currentItem.id, position: currentTime)
    }

    /// Uses a small tolerance instead of frame-accurate (zero-tolerance)
    /// seeking. Precise seeking forces AVPlayer to decode right up to the
    /// exact target sample, which for streamed/compressed audio can stall
    /// playback for a moment with no visual indication -- most noticeable
    /// when seeking again shortly after a previous seek (e.g. tapping +10
    /// right after releasing the scrubber), which is what looked like the
    /// skip buttons "not working". A half-second tolerance lets it jump to
    /// the nearest already-available point instead, which is imperceptible
    /// for scrubbing/skipping but avoids the stall entirely.
    ///
    /// `currentTime` is also updated optimistically here, immediately,
    /// rather than waiting for the next periodic time-observer tick --
    /// `skip(_:)` reads `currentTime` as its base, so without this a skip
    /// fired shortly after a seek could still compute from the pre-seek
    /// position. `lastManualSeekAt` is recorded so the time observer (see
    /// `addTimeObserver`) briefly ignores its own updates right after --
    /// because of the tolerance above, the player can land up to half a
    /// second away from the exact requested target, and immediately trusting
    /// that value produced a small but visible "correction" jump right after
    /// almost every skip or scrub release.
    func seek(to seconds: Double) {
        let upperBound = duration > 0 ? duration : .greatestFiniteMagnitude
        let clamped = min(max(0, seconds), upperBound)
        currentTime = clamped
        lastManualSeekAt = Date()
        let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    func skip(_ seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying {
            player?.rate = newRate
        }
    }

    /// The real duration must come from the asset itself, not from
    /// (possibly inaccurate) catalog metadata -- otherwise the seek slider's
    /// range doesn't match what's actually playable and forward seeking past
    /// the real end silently fails.
    private func loadDuration(for playerItem: AVPlayerItem) {
        Task { @MainActor [weak self] in
            guard let loaded = try? await playerItem.asset.load(.duration),
                  loaded.isValid, loaded.seconds.isFinite else { return }
            guard self?.player?.currentItem === playerItem else { return }
            self?.duration = loaded.seconds
        }
    }

    private func addTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Give a manual seek a moment to actually land before
                // trusting the observer's own position again -- see the
                // note on `lastManualSeekAt` in `seek(to:)`.
                if let lastManualSeekAt = self.lastManualSeekAt, Date().timeIntervalSince(lastManualSeekAt) < 0.4 {
                    return
                }
                self.currentTime = time.seconds
            }
        }
    }

    private func removeObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }
}
