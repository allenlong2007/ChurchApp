import SwiftUI

/// The large hero card shown at the top of the Featured tab -- always the
/// most recently added item, since HomeView sorts by dateAdded descending
/// before picking items[0].
struct FeaturedHeroCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The square cover is scaled to fill a wide, short window, so it
            // overflows above and below. Hit testing doesn't respect that clip,
            // and the overflow would swallow taps meant for the section buttons
            // above the card -- the image is purely decorative, so it opts out.
            Color.clear
                .frame(height: 170)
                .overlay { artwork.allowsHitTesting(false) }
                .clipShape(RoundedRectangle(cornerRadius: Theme.heroRadius))
                .overlay(alignment: .topLeading) {
                    Text("Latest")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.flareGradient, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(14)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.themeHeading(19))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let speaker = item.speaker {
                    Text(speaker)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.heroRadius))
        .contentShape(RoundedRectangle(cornerRadius: Theme.heroRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.heroRadius)
                .strokeBorder(Theme.flareGradient.opacity(0.45), lineWidth: 1.25)
        )
        .themeCardShadow()
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
        item.type.gradient
        .overlay(
            Image(systemName: item.type.iconName)
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
        )
    }
}
