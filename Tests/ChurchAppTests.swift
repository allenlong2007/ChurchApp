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
