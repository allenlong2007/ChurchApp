import SwiftUI

struct MediaRowView: View {
    let item: MediaItem
    @EnvironmentObject private var downloads: DownloadManager

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(item.type == .sermon ? Color.orange.opacity(0.25) : Color.green.opacity(0.25))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: item.type == .sermon ? "book.fill" : "music.note")
                        .foregroundStyle(item.type == .sermon ? .orange : .green)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
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
        .padding(.vertical, 6)
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
