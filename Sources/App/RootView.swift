import SwiftUI
import UIKit

struct RootView: View {
    @StateObject private var repository = ContentRepository.shared
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var downloads = DownloadManager.shared
    @StateObject private var notifications = NotificationManager.shared
    @StateObject private var history = PlaybackHistoryManager.shared
    @State private var showDisplayZoomAlert = false

    var body: some View {
        Group {
            // iOS 26's tab bar floats above the bottom edge instead of
            // sitting flush against it, so a plain `.safeAreaInset` no
            // longer docks the mini-player above the bar -- it renders at
            // the true screen edge and ends up underneath the floating bar
            // instead. `tabViewBottomAccessory` is the dedicated API Apple
            // added in iOS 26 for exactly this "mini-player above the tab
            // bar" pattern, so it's used when available; older iOS versions
            // (down to this app's iOS 16 minimum) keep the previous
            // `safeAreaInset` approach, which is correct for their
            // flush-bottom tab bar.
            //
            // Critically, `tabs` and its modifier are attached *once* here,
            // never conditionally swapped in/out based on playback state --
            // doing that previously caused SwiftUI to treat it as a
            // structural change and tear down/rebuild the whole tab
            // hierarchy (including Home's navigation stack) the instant
            // playback started, which kicked the user back to the Featured
            // tab right as their episode began playing. `isEnabled:` (iOS
            // 26.1+) is Apple's dedicated way to toggle the accessory's
            // visibility without that teardown. iOS 26.0 (before 26.1) has
            // no `isEnabled` parameter, so it falls back to always-attached
            // with conditionally-empty content -- this can show a brief
            // blank bar on first launch on that narrow OS slice, which is a
            // much smaller issue than the navigation bug it avoids.
            if #available(iOS 26.1, *) {
                tabs.tabViewBottomAccessory(isEnabled: player.currentItem != nil) {
                    MiniPlayerBar()
                }
            } else if #available(iOS 26.0, *) {
                tabs.tabViewBottomAccessory {
                    MiniPlayerBar()
                }
            } else {
                tabs.safeAreaInset(edge: .bottom, spacing: 0) {
                    if player.currentItem != nil {
                        MiniPlayerBar()
                            .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .environmentObject(repository)
        .environmentObject(player)
        .environmentObject(downloads)
        .environmentObject(notifications)
        .environmentObject(history)
        // One fixed palette regardless of the device's system appearance --
        // Theme's colors are plain (non-adaptive) values tuned for light
        // mode, so system chrome (nav bars, sheets, materials) needs to be
        // pinned to light too or it would mismatch in system dark mode.
        .preferredColorScheme(.light)
        .task {
            downloads.reconcileStaleDownloads(currentItems: repository.items)
            await repository.refresh()
        }
        .onChangeCompat(of: repository.items) { newItems in
            downloads.reconcileStaleDownloads(currentItems: newItems)
        }
        .onAppear {
            showDisplayZoomAlert = Self.isDisplayZoomOn
        }
        .alert("Display Zoom Is On", isPresented: $showDisplayZoomAlert) {
            Button("OK") {}
        } message: {
            Text("Your phone's Display Zoom setting makes everything on screen larger, including in this app, which can crop content at the edges. To see the app as designed, go to Settings > Display & Brightness > View and choose Standard.")
        }
    }

    /// Display Zoom (Settings > Display & Brightness > View > Zoomed)
    /// simulates a smaller screen and scales the whole UI up to fill the
    /// real one -- it affects every app uniformly, ours included, so there's
    /// nothing to fix in this app's layout. `scale` is the point-to-pixel
    /// factor actually in effect right now (which Zoomed mode changes);
    /// `nativeScale` is the physical screen's fixed factor, so the two
    /// diverge only when Zoomed is on. The one known false positive is the
    /// iPhone 6/7/8 Plus generation, whose panel legitimately renders at a
    /// different scale than its native pixel density even in Standard mode
    /// -- an acceptable, narrow edge case for an informational alert like
    /// this one (worst case, an occasional user sees a suggestion to check
    /// a setting that's already fine).
    private static var isDisplayZoomOn: Bool {
        UIScreen.main.scale != UIScreen.main.nativeScale
    }

    private var tabs: some View {
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
    }
}

#Preview {
    RootView()
}
