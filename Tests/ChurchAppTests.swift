import Foundation
import Testing
@testable import SJCA

private func item(id: String, language: ContentLanguage, duration: Int? = nil) -> MediaItem {
    MediaItem(
        id: id, type: .podcast, title: id, speaker: nil, series: nil, category: nil,
        dateAdded: "2026-01-01T00:00:00Z", durationSeconds: duration,
        audioURL: "https://example.com/\(id).mp3", imageURL: nil, language: language, order: nil
    )
}

struct LanguageTests {
    // The stored setting is "zh-Hans", not "zh". An exact-match check here once
    // made Chinese mode silently fall back to English content.
    @Test(arguments: ["zh-Hans", "zh", "zh-Hant"])
    func chineseSettingsMapToChineseContent(setting: String) {
        #expect(contentLanguageCode(forAppLanguage: setting) == .zh)
    }

    @Test func englishSettingMapsToEnglishContent() {
        #expect(contentLanguageCode(forAppLanguage: "en") == .en)
    }

    @Test func filteringKeepsOnlyTheAppLanguage() {
        let items = [item(id: "a", language: .en), item(id: "b", language: .zh), item(id: "c", language: .zh)]
        #expect(items.matchingAppLanguage("zh-Hans").map(\.id) == ["b", "c"])
        #expect(items.matchingAppLanguage("en").map(\.id) == ["a"])
    }
}

struct SeriesDisplayNameTests {
    let series = PodcastSeriesInfo(
        name: "Morning Watch", parent: nil, imageURL: nil,
        speaker: "Pastor Lee", nameZh: "晨更", speakerZh: "李牧师"
    )

    @Test func chineseModeUsesChineseNames() {
        #expect(series.localizedName(for: "zh-Hans") == "晨更")
        #expect(series.localizedSpeaker(for: "zh-Hans") == "李牧师")
    }

    @Test func englishModeUsesTheOriginalNames() {
        #expect(series.localizedName(for: "en") == "Morning Watch")
        #expect(series.localizedSpeaker(for: "en") == "Pastor Lee")
    }

    @Test func blankChineseNameFallsBackToEnglish() {
        let untranslated = PodcastSeriesInfo(
            name: "Hymns", parent: nil, imageURL: nil, speaker: nil, nameZh: "", speakerZh: nil
        )
        #expect(untranslated.localizedName(for: "zh-Hans") == "Hymns")
    }

    @Test func subFolderIDIncludesItsParent() {
        let genesis = PodcastSeriesInfo(
            name: "Genesis", parent: "Pre-Study", imageURL: nil, speaker: nil, nameZh: nil, speakerZh: nil
        )
        #expect(genesis.id == "Pre-Study/Genesis")
    }
}

struct DurationFormattingTests {
    @Test func formatsMinutesAndPaddedSeconds() {
        #expect(item(id: "a", language: .en, duration: 3725).formattedDuration == "62:05")
        #expect(item(id: "b", language: .en, duration: 59).formattedDuration == "0:59")
    }

    @Test func missingDurationIsBlank() {
        #expect(item(id: "a", language: .en).formattedDuration == "")
    }
}

/// Checks the content.json that ships inside the app, since that's what users
/// see offline or before the first remote fetch succeeds.
struct BundledManifestTests {
    let manifest: ContentManifest

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "content", withExtension: "json"))
        manifest = try JSONDecoder().decode(ContentManifest.self, from: Data(contentsOf: url))
    }

    @Test func itemIDsAreUnique() {
        let ids = manifest.items.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyItemHasAValidDateAndHTTPSMediaURL() {
        for item in manifest.items {
            #expect(item.dateAddedValue != nil, "bad dateAdded on \(item.id)")
            #expect(URL(string: item.audioURL)?.scheme == "https", "bad audioURL on \(item.id)")
        }
    }

    @Test func everySeriesOnAnItemIsDeclared() {
        let declared = Set((manifest.series ?? []).map(\.name))
        for item in manifest.items {
            if let series = item.series {
                #expect(declared.contains(series), "\(item.id) uses undeclared series \(series)")
            }
        }
    }

    @Test func everySubFolderParentExists() {
        let all = manifest.series ?? []
        let names = Set(all.map(\.name))
        for folder in all {
            if let parent = folder.parent {
                #expect(names.contains(parent), "\(folder.name) has missing parent \(parent)")
            }
        }
    }

    @Test func bothLanguagesHaveContent() {
        #expect(!manifest.items.matchingAppLanguage("en").isEmpty)
        #expect(!manifest.items.matchingAppLanguage("zh-Hans").isEmpty)
    }
}

struct FolderVisibilityTests {
    private static func episode(_ id: String, series: String, language: ContentLanguage, type: MediaType = .podcast) -> MediaItem {
        MediaItem(
            id: id, type: type, title: id, speaker: nil, series: series, category: nil,
            dateAdded: "2026-01-01T00:00:00Z", durationSeconds: nil,
            audioURL: "https://example.com/\(id).mp3", imageURL: nil, language: language, order: nil
        )
    }

    private static func folder(_ name: String, parent: String? = nil) -> PodcastSeriesInfo {
        PodcastSeriesInfo(name: name, parent: parent, imageURL: nil, speaker: nil, nameZh: nil, speakerZh: nil)
    }

    private let folders = [Self.folder("Pre-Study"), Self.folder("Genesis", parent: "Pre-Study"), Self.folder("Exodus", parent: "Pre-Study"), Self.folder("Kids")]

    private var items: [MediaItem] {
        [
            Self.episode("g1", series: "Genesis", language: .zh),
            Self.episode("e1", series: "Exodus", language: .en),
            Self.episode("e2", series: "Exodus", language: .zh),
            Self.episode("k1", series: "Kids", language: .en),
        ]
    }

    @Test func folderWithOnlyChineseEpisodesIsHiddenInEnglish() {
        #expect(!FolderVisibility.hasEpisodes(named: "Genesis", type: .podcast, language: .en, items: items, seriesInfo: folders))
        #expect(FolderVisibility.hasEpisodes(named: "Genesis", type: .podcast, language: .zh, items: items, seriesInfo: folders))
    }

    @Test func folderWithOnlyEnglishEpisodesIsHiddenInChinese() {
        #expect(!FolderVisibility.hasEpisodes(named: "Kids", type: .podcast, language: .zh, items: items, seriesInfo: folders))
        #expect(FolderVisibility.hasEpisodes(named: "Kids", type: .podcast, language: .en, items: items, seriesInfo: folders))
    }

    @Test func parentFolderCountsEpisodesInItsSubFolders() {
        #expect(FolderVisibility.hasEpisodes(named: "Pre-Study", type: .podcast, language: .en, items: items, seriesInfo: folders))
        let onlyGenesis = [Self.episode("g1", series: "Genesis", language: .zh)]
        #expect(!FolderVisibility.hasEpisodes(named: "Pre-Study", type: .podcast, language: .en, items: onlyGenesis, seriesInfo: folders))
    }

    @Test func mediaTypeMustMatchToo() {
        #expect(!FolderVisibility.hasEpisodes(named: "Exodus", type: .hymn, language: .en, items: items, seriesInfo: folders))
    }
}
