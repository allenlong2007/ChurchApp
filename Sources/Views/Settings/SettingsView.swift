import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @EnvironmentObject private var repository: ContentRepository

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
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
                    Text("New sermons and songs added by the church appear here automatically the next time content is refreshed.")
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
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ContentRepository.shared)
}
