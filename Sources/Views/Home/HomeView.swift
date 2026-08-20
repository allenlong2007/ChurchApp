import SwiftUI
import Foundation

private enum HomeFilter: String, CaseIterable, Identifiable {
    case sermons
    case songs
    case recommended
    case recent
    case downloads

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .sermons: return "Sermons"
        case .songs: return "Songs"
        case .recommended: return "Recommended"
        case .recent: return "Recent Updates"
        case .downloads: return "My Downloads"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var repository: ContentRepository
    @EnvironmentObject private var downloads: DownloadManager
    @State private var filter: HomeFilter = .recommended
    @State private var searchText = ""

    private var filteredItems: [MediaItem] {
        var items = repository.items
        switch filter {
        case .sermons:
            items = items.filter { $0.type == .sermon }
        case .songs:
            items = items.filter { $0.type == .song }
        case .recommended:
            items = items.filter { $0.isRecommended }
        case .recent:
            items.sort { ($0.dateAddedValue ?? .distantPast) > ($1.dateAddedValue ?? .distantPast) }
        case .downloads:
            items = items.filter { downloads.isDownloaded($0) }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.speaker ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(HomeFilter.allCases) { option in
                            Button {
                                filter = option
                            } label: {
                                Text(option.titleKey)
                                    .font(.subheadline)
                                    .fontWeight(filter == option ? .semibold : .regular)
                                    .foregroundStyle(filter == option ? Color.accentColor : .secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                Divider()

                List {
                    if filteredItems.isEmpty {
                        Text("No items yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item) {
                            MediaRowView(item: item)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await repository.refresh()
                }
            }
            .searchable(text: $searchText, prompt: Text("Search", comment: "Search field placeholder"))
            .navigationTitle(Text("Church App"))
            .navigationDestination(for: MediaItem.self) { item in
                PlayerView(item: item)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ContentRepository.shared)
        .environmentObject(DownloadManager.shared)
}
