import SwiftUI

struct PlayerView: View {
    let item: MediaItem
    var startAt: Double = 0
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var downloads: DownloadManager

    /// While dragging, the slider shows and edits this local value instead
    /// of `player.currentTime` directly -- otherwise every drag tick calls
    /// `seek(to:)` immediately, and the periodic time observer's own
    /// (slightly lagging) updates fight the drag, producing a laggy,
    /// stuck-feeling thumb.
    ///
    /// The actual seek is debounced off the value-change callback itself
    /// (`scrubCommitTask`) rather than `Slider`'s `onEditingChanged` --
    /// `onEditingChanged` isn't reliably paired with every interaction (a
    /// very fast drag or flick can generate value changes without a clean
    /// matching start/end pair), which is what caused the thumb to
    /// occasionally "lag back" to the live playback position mid-gesture
    /// during fast scrubbing. Driving everything off `set` instead means
    /// every value change is handled the same way regardless of gesture
    /// speed: reschedule a commit a beat in the future, canceling whichever
    /// one was pending, so it only actually fires once movement settles.
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var scrubCommitTask: Task<Void, Never>?

    private var displayedCurrentTime: Double {
        player.currentItem?.id == item.id ? player.currentTime : startAt
    }

    /// The episode's real duration takes a brief moment to load after
    /// `play()` is called, during which `player.duration` is still 0. Using
    /// `0...max(player.duration, 1)` as the slider's range in that window
    /// clamped the thumb to the far-right edge (since the current position
    /// was already past the tiny range) -- this generous placeholder ceiling
    /// avoids that: it's comfortably larger than any real episode here, so
    /// the thumb sits at a plausible, non-pinned spot until the real
    /// duration arrives and the range corrects itself with only a small
    /// adjustment instead of a jump from the far end.
    private var sliderUpperBound: Double {
        player.duration > 0 ? player.duration : 3600
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            artwork
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: Theme.heroRadius))
                .themeCardShadow()

            VStack(spacing: 6) {
                Text(item.title)
                    .font(.themeHeading(20))
                    .multilineTextAlignment(.center)
                if let speaker = item.speaker {
                    Text(speaker)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { isScrubbing ? scrubTime : displayedCurrentTime },
                        set: { newValue in
                            scrubTime = newValue
                            isScrubbing = true
                            scrubCommitTask?.cancel()
                            scrubCommitTask = Task {
                                try? await Task.sleep(nanoseconds: 150_000_000)
                                guard !Task.isCancelled else { return }
                                player.seek(to: scrubTime)
                                isScrubbing = false
                            }
                        }
                    ),
                    in: 0...sliderUpperBound
                )
                HStack {
                    Text(timeString(isScrubbing ? scrubTime : displayedCurrentTime))
                    Spacer()
                    Text(timeString(player.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            HStack(spacing: 40) {
                Button {
                    player.skip(-10)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title)
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.flareGradient)
                }

                Button {
                    player.skip(10)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.title)
                }
            }
            .foregroundStyle(.primary)

            Spacer()
        }
        .background(Theme.pageBackground)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if downloads.isDownloaded(item) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        downloads.startDownload(item)
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                }
            }
        }
        .onAppear {
            let local = downloads.localURL(for: item)
            player.play(item, from: local, startAt: startAt)
        }
        .onDisappear {
            scrubCommitTask?.cancel()
            player.pause()
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let imageURL = item.imageURL, let url = URL(string: imageURL) {
            RemoteImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                artworkPlaceholder
            }
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(item.type.gradient.opacity(0.35))
            .overlay(
                Image(systemName: item.type.iconName)
                    .font(.system(size: 64))
                    .foregroundStyle(item.type.gradient)
            )
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
