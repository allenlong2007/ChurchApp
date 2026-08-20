import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject private var player: AudioPlayerManager

    var body: some View {
        if let item = player.currentItem {
            HStack(spacing: 12) {
                Image(systemName: item.type == .sermon ? "book.fill" : "music.note")
                    .foregroundStyle(item.type == .sermon ? .orange : .green)

                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}
