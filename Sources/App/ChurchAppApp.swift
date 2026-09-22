import SwiftUI

@main
struct ChurchAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(appLanguageStorageKey) private var appLanguage: String = "en"

    init() {
        // A bigger shared cache means cover art (fetched via AsyncImage)
        // only needs to load once per image, not on every scroll/reappear --
        // without this, a cell recycled mid-scroll can show its placeholder
        // instead of retrying a slow or momentarily-failed load.
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: appLanguage))
        }
    }
}
