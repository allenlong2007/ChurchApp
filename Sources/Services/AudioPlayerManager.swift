import Foundation
import AVFoundation
import Combine
import UIKit
import MediaPlayer

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
    private var remoteCommandsConfigured = false
    private var nowPlayingArtworkTask: Task<Void, Never>?

    private init() {}

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
        configureRemoteCommandsIfNeeded()
    }

    /// Wires the Lock Screen / Control Center transport controls to this
    /// player. Required for background audio to be usable at all -- without
    /// this, a user who backgrounds the app has no way to pause or skip
    /// what's playing. Configured once, the handlers stay valid for the
    /// life of the app since they always act on whatever `player` currently
    /// holds rather than capturing a specific item.
    private func configureRemoteCommandsIfNeeded() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player, !self.isPlaying else { return .commandFailed }
            player.rate = self.rate
            player.play()
            self.isPlaying = true
            self.updateNowPlayingInfo()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .commandFailed }
            self.pause()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.skip(15)
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.skip(-15)
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }
    }

    /// Publishes what's currently playing to the Lock Screen / Control
    /// Center. Called on every state change that those surfaces show
    /// (play/pause/seek/track change) rather than on a timer -- iOS
    /// interpolates the elapsed-time display on its own between updates
    /// using `playbackRate`, so this doesn't need to run continuously.
    private func updateNowPlayingInfo() {
        guard let currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentItem.title,
            MPMediaItemPropertyArtist: currentItem.speaker ?? currentItem.series ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
            MPMediaItemPropertyPlaybackDuration: duration
        ]
        if let existingArtwork = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = existingArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        loadNowPlayingArtworkIfNeeded(for: currentItem)
    }

    private func loadNowPlayingArtworkIfNeeded(for item: MediaItem) {
        guard let imageURLString = item.imageURL, let imageURL = URL(string: imageURLString) else { return }
        nowPlayingArtworkTask?.cancel()
        nowPlayingArtworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: imageURL),
                  let image = UIImage(data: data), !Task.isCancelled else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            await MainActor.run {
                guard let self, self.currentItem?.id == item.id else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
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
                self?.updateNowPlayingInfo()
            }
        }

        if startAt > 0 {
            let tolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
            player?.seek(to: CMTime(seconds: startAt, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance)
        }
        player?.rate = rate
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
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
        updateNowPlayingInfo()
    }

    /// Pauses without clearing `currentItem` -- the mini-player keeps
    /// showing what was playing (paused), ready to resume from where it
    /// left off, rather than disappearing.
    func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        recordHistory()
        updateNowPlayingInfo()
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
        updateNowPlayingInfo()
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
            self?.updateNowPlayingInfo()
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
