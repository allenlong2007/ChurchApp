import SwiftUI

struct MediaRowView: View {
    let item: MediaItem
    @EnvironmentObject private var downloads: DownloadManager

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.themeHeading(15.5))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let speaker = item.speaker {
                        Text(speaker)
                    }
                    if !item.formattedDuration.isEmpty {
                        Text("·")
                        Text(item.formattedDuration)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            downloadIndicator
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .themeCardShadow()
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                RemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    thumbnailPlaceholder
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(Circle())
    }

    private var thumbnailPlaceholder: some View {
        item.type.gradient
        .overlay(
            Image(systemName: item.type.iconName)
                .foregroundStyle(.white)
                .font(.system(size: 20, weight: .semibold))
        )
    }

    @ViewBuilder
    private var downloadIndicator: some View {
        if downloads.isDownloaded(item) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if let progress = downloads.progress[item.id] {
            ProgressView(value: progress)
                .frame(width: 24)
        } else {
            Button {
                downloads.startDownload(item)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
