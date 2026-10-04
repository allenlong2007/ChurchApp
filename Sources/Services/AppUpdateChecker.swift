import Foundation

/// Checks the App Store for a newer approved version than the one currently
/// running, so the app can block itself until the user updates instead of
/// running mismatched against server-side content or assets that assume a
/// newer build. Uses Apple's public iTunes lookup API (no API key, no
/// entitlement needed) -- its `trackViewUrl` doubles as the exact link to
/// open to this app's App Store page, so no app-specific numeric ID has to
/// be hardcoded here.
@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published private(set) var updateIsRequired = false
    @Published private(set) var appStoreURL: URL?

    private static let bundleID = "org.sjca.app"
    private static let recheckInterval: TimeInterval = 3600

    // Apple's CDN caches the plain lookup URL for ~24h after a release, so a throwaway
    // query value is needed to get the live version instead of a stale one.
    private static func lookupRequest() -> URLRequest {
        let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&t=\(Int(Date().timeIntervalSince1970))")!
        return URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    }

    private var lastCheckedAt: Date?
    private var timer: Timer?

    private init() {
        let timer = Timer(timeInterval: Self.recheckInterval, repeats: true) { [weak self] _ in
            Task { await self?.check() }
        }
        // `.common` keeps this firing while the user is actively scrolling,
        // not just when the run loop is otherwise idle.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Call when the app returns to the foreground -- re-checks only if an
    /// hour has passed since the last check, so quickly switching back and
    /// forth doesn't spam Apple's endpoint.
    func checkIfStale() async {
        if let lastCheckedAt, Date().timeIntervalSince(lastCheckedAt) < Self.recheckInterval {
            return
        }
        await check()
    }

    func check() async {
        lastCheckedAt = Date()
        // Once required, there's nothing to re-check until the process is
        // relaunched (after the user actually updates).
        guard !updateIsRequired,
              let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: Self.lookupRequest())
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let result = response.results.first else { return }
            if Self.isVersion(result.version, newerThan: currentVersion) {
                appStoreURL = URL(string: result.trackViewUrl)
                updateIsRequired = true
            }
        } catch {
            // No connectivity or a transient hiccup on Apple's side -- never
            // block the app over a check that simply couldn't complete.
        }
    }

    private struct LookupResponse: Decodable {
        let results: [Result]
        struct Result: Decodable {
            let version: String
            let trackViewUrl: String
        }
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aParts.count, bParts.count) {
            let x = i < aParts.count ? aParts[i] : 0
            let y = i < bParts.count ? bParts[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
