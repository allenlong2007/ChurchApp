import SwiftUI
import AVKit

/// A self-contained video player screen. Unlike audio (`AudioPlayerManager`),
/// video isn't meant to keep playing across screens or in the background --
/// it's a full-screen, foreground-only activity -- so each screen owns its
/// own `AVPlayer` instead of going through a shared singleton. Listening
/// history is still recorded directly against `PlaybackHistoryManager`,
/// the same store audio uses, so a video shows up in History too.
struct VideoPlayerView: View {
    let item: MediaItem
    var startAt: Double = 0
    @EnvironmentObject private var downloads: DownloadManager
    @State private var player: AVPlayer?
    @State private var isFullScreen = false
    @State private var endObserver: NSObjectProtocol?
    @State private var backgroundObserver: NSObjectProtocol?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let player {
                            VideoPlayer(player: player)
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                    .themeCardShadow()

                    if player != nil {
                        Button {
                            // Start rotating *before* presenting the cover,
                            // not after it appears -- kicking off the two
                            // animations together (instead of "present in
                            // portrait, then rotate a beat later") is what
                            // removes the visible lag going full-screen.
                            VideoOrientation.set(.landscape)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isFullScreen = true
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .padding(10)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.themeHeading(18))
                    if let speaker = item.speaker {
                        Text(speaker)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
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
            let url = downloads.localURL(for: item) ?? URL(string: item.audioURL)
            guard let url else { return }
            AudioPlayerManager.shared.activateAudioSessionIfNeeded()
            let newPlayer = AVPlayer(url: url)
            if startAt > 0 {
                newPlayer.seek(to: CMTime(seconds: startAt, preferredTimescale: 600))
            }
            player = newPlayer
            newPlayer.play()

            let itemID = item.id
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                let seconds = newPlayer.currentTime().seconds
                guard seconds.isFinite, seconds >= 0 else { return }
                Task { @MainActor in
                    PlaybackHistoryManager.shared.record(itemID: itemID, position: seconds)
                }
            }

            // Backgrounding the app (home button / app switcher) pauses
            // video the same way navigating back within the app already
            // does below in `onDisappear` -- video has no mini-player to
            // keep running, so without this it would otherwise keep
            // playing (audio and all) behind the home screen.
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    newPlayer.pause()
                }
            }
        }
        .onDisappear {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            endObserver = nil
            if let backgroundObserver {
                NotificationCenter.default.removeObserver(backgroundObserver)
            }
            backgroundObserver = nil
            if let player {
                let seconds = player.currentTime().seconds
                if seconds.isFinite, seconds >= 0 {
                    PlaybackHistoryManager.shared.record(itemID: item.id, position: seconds)
                }
            }
            player?.pause()
            player = nil
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            if let player {
                FullScreenVideoView(player: player, isPresented: $isFullScreen)
            }
        }
    }
}

/// Landscape, edge-to-edge video playback. The rest of the app is locked to
/// portrait (its layouts aren't designed for landscape), so this is the one
/// place that temporarily unlocks rotation -- see `AppDelegate`.
private struct FullScreenVideoView: View {
    let player: AVPlayer
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .padding()
        }
        .statusBarHidden()
        .onAppear {
            // Redundant with the pre-presentation request in
            // VideoPlayerView (belt and suspenders in case that one's
            // timing doesn't win the race on a slower device).
            VideoOrientation.set(.landscape)
        }
        .onDisappear {
            VideoOrientation.set(.portrait)
        }
    }
}

@MainActor
private enum VideoOrientation {
    static func set(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
