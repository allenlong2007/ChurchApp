import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var repository: ContentRepository
    @EnvironmentObject private var downloads: DownloadManager
    @AppStorage(appLanguageStorageKey) private var appLanguage: String = "en"
    @State private var path = NavigationPath()

    private var downloadedItems: [MediaItem] {
        repository.items
            .filter { downloads.isDownloaded($0) }
            .matchingAppLanguage(appLanguage)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if downloadedItems.isEmpty {
                    Text("No downloads yet")
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                ForEach(downloadedItems) { item in
                    NavigationLink(value: item) {
                        MediaRowView(item: item)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
                .onDelete { offsets in
                    for index in offsets {
                        downloads.delete(downloadedItems[index])
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.pageBackground)
            .navigationTitle(Text("My Downloads"))
            .navigationDestination(for: MediaItem.self) { item in
                if item.type == .video {
                    VideoPlayerView(item: item)
                } else {
                    PlayerView(item: item)
                }
            }
        }
        .onDisappear {
            path = NavigationPath()
        }
    }
}

#Preview {
    DownloadsView()
        .environmentObject(ContentRepository.shared)
        .environmentObject(DownloadManager.shared)
}
