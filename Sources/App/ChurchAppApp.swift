import SwiftUI

@main
struct ChurchAppApp: App {
    @AppStorage("appLanguage") private var appLanguage: String = "en"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: appLanguage))
        }
    }
}
