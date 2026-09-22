import UIKit

/// Lets `VideoPlayerView`'s full-screen mode temporarily allow landscape
/// rotation while keeping the rest of the app locked to portrait -- its
/// normal layouts (lists, the audio player) aren't designed for landscape.
/// `application(_:supportedInterfaceOrientationsFor:)` is the standard
/// SwiftUI-app-lifecycle hook for this: the Info.plist declares the full
/// set of orientations the app could ever use (see project.yml), and this
/// mask narrows it down at runtime, moment to moment.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}
