import SwiftUI

struct SettingsView: View {
    @AppStorage(appLanguageStorageKey) private var appLanguage: String = "en"
    @EnvironmentObject private var repository: ContentRepository
    @State private var path = NavigationPath()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Picker(selection: $appLanguage) {
                        Text("English").tag("en")
                        Text("中文").tag("zh-Hans")
                    } label: {
                        Text("Language")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Language")
                }

                Section {
                    NavigationLink(value: SettingsRoute.history) {
                        Text("History")
                    }
                } header: {
                    Text("Listening")
                } footer: {
                    Text("Everything you've played, with where you left off.")
                }

                Section {
                    Button {
                        Task { await repository.refresh() }
                    } label: {
                        HStack {
                            Text("Refresh Content")
                            Spacer()
                            if repository.isRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    if let lastUpdated = repository.lastUpdated {
                        Text("Last updated: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Content")
                } footer: {
                    Text("New podcasts and hymns added by the church appear here automatically the next time content is refreshed.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle(Text("Me"))
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .history:
                    HistoryView()
                }
            }
            .navigationDestination(for: HistoryPlaybackRoute.self) { route in
                if route.item.type == .video {
                    VideoPlayerView(item: route.item, startAt: route.startAt)
                } else {
                    PlayerView(item: route.item, startAt: route.startAt)
                }
            }
        }
        .onDisappear {
            path = NavigationPath()
        }
    }
}

private enum SettingsRoute: Hashable {
    case history
}

#Preview {
    SettingsView()
        .environmentObject(ContentRepository.shared)
}
