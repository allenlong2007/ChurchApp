import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject private var player: AudioPlayerManager

    /// No background here -- on iOS 26 this content sits inside the system's
    /// own `tabViewBottomAccessory` glass chrome, which already renders a
    /// full, evenly-toned background behind it. Adding another
    /// `.ultraThinMaterial` on top only covered this view's own (smaller,
    /// padding-bound) rectangle, layering a second translucent tone over
    /// the system one -- the mismatch showed as a grey center with lighter
    /// white edges where the two materials didn't quite overlap. The
    /// pre-iOS 26 `safeAreaInset` fallback (RootView) supplies its own
    /// background instead, since there's no system chrome there.
    var body: some View {
        if let item = player.currentItem {
            HStack(spacing: 12) {
                Image(systemName: item.type.iconName)
                    .foregroundStyle(item.type.gradient)

                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(item.type.gradient)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}
