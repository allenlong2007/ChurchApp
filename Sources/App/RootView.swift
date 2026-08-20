import SwiftUI

struct RootView: View {
    @StateObject private var repository = ContentRepository.shared
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var downloads = DownloadManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                DownloadsView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Me", systemImage: "person.crop.circle.fill")
                    }
            }
            .padding(.bottom, player.currentItem != nil ? 56 : 0)

            if player.currentItem != nil {
                MiniPlayerBar()
                    .padding(.bottom, 49)
            }
        }
        .environmentObject(repository)
        .environmentObject(player)
        .environmentObject(downloads)
        .task {
            await repository.refresh()
        }
    }
}

#Preview {
    RootView()
}
