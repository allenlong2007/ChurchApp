import Foundation

/// The @AppStorage key for the user's chosen display language ("en" or
/// "zh-Hans"), shared between the app entry point, Settings, and anywhere
/// content needs to be filtered to match it.
let appLanguageStorageKey = "appLanguage"

/// Maps the stored display-language value to the two-letter content
/// language code used on `MediaItem.language`.
func contentLanguageCode(forAppLanguage appLanguage: String) -> ContentLanguage {
    appLanguage.hasPrefix("zh") ? .zh : .en
}

extension Sequence where Element == MediaItem {
    /// Only the items whose spoken/sung language matches the app's current
    /// display language -- an English-language item never shows while the
    /// app is in 中文 mode, and vice versa.
    func matchingAppLanguage(_ appLanguage: String) -> [MediaItem] {
        let code = contentLanguageCode(forAppLanguage: appLanguage)
        return filter { $0.language == code }
    }
}
