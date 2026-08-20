import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var repository: ContentRepository
    @EnvironmentObject private var downloads: DownloadManager

    private var downloadedItems: [MediaItem] {
        repository.items.filter { downloads.isDownloaded($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if downloadedItems.isEmpty {
                    Text("No downloads yet")
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }
                ForEach(downloadedItems) { item in
                    NavigationLink(value: item) {
                        MediaRowView(item: item)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        downloads.delete(downloadedItems[index])
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(Text("My Downloads"))
            .navigationDestination(for: MediaItem.self) { item in
                PlayerView(item: item)
            }
        }
    }
}

#Preview {
    DownloadsView()
        .environmentObject(ContentRepository.shared)
        .environmentObject(DownloadManager.shared)
}
