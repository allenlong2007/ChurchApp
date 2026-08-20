import SwiftUI

struct PlayerView: View {
    let item: MediaItem
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var downloads: DownloadManager

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            RoundedRectangle(cornerRadius: 20)
                .fill(item.type == .sermon ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                .frame(width: 220, height: 220)
                .overlay(
                    Image(systemName: item.type == .sermon ? "book.fill" : "music.note")
                        .font(.system(size: 64))
                        .foregroundStyle(item.type == .sermon ? .orange : .green)
                )

            VStack(spacing: 6) {
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.semibold)
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
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
                HStack {
                    Text(timeString(player.currentTime))
                    Spacer()
                    Text(timeString(player.duration))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            HStack(spacing: 40) {
                Button {
                    player.skip(-15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }

                Button {
                    player.skip(30)
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title)
                }
            }
            .foregroundStyle(.primary)

            Spacer()
        }
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
            player.play(item, from: local)
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
