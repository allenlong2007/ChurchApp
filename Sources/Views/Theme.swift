import SwiftUI
import UIKit

/// One fixed, cohesive palette -- the app always renders this look
/// regardless of the device's light/dark setting (see `.preferredColorScheme`
/// on `RootView`), so there's a single set of RGB values here rather than
/// light/dark pairs. A calm neutral base (soft off-white backgrounds, gentle
/// shadows) carries a genuinely varied, gradient-driven color layer on top --
/// each category gets its own two-hue gradient (teal-into-indigo,
/// sage-into-gold, amber-into-coral, slate-into-plum) instead of one flat
/// mint tint repeated everywhere.
enum Theme {
    /// Primary brand color -- deep teal. Used for the Featured tab, the
    /// logo backdrop's ring, and anywhere a single flat accent is needed.
    static let mint = Color(red: 0.20, green: 0.52, blue: 0.46)

    static let pageBackground = Color(red: 0.960, green: 0.968, blue: 0.972)

    static let cardBackground = Color.white

    /// A soft, low shadow -- calmer than a stock black shadow, used to lift
    /// cards gently instead of relying on flat grey fills.
    static let cardShadow = Color(red: 0.16, green: 0.24, blue: 0.30).opacity(0.10)

    /// The three-hue "signature" gradient -- teal into gold into coral --
    /// reserved for the handful of standout moments (the Featured hero
    /// card's border glow and badge, the main play button) rather than
    /// spread across every element, so it reads as a deliberate flourish.
    private static let flareStart = Color(red: 0.18, green: 0.48, blue: 0.52)
    private static let flareMid = Color(red: 0.80, green: 0.66, blue: 0.30)
    private static let flareEnd = Color(red: 0.82, green: 0.42, blue: 0.44)
    static var flareGradient: LinearGradient {
        LinearGradient(colors: [flareStart, flareMid, flareEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Folder-cover placeholder gradient (shown before a real cover photo
    /// is set) -- moss into muted gold.
    private static let folderStart = Color(red: 0.40, green: 0.56, blue: 0.46)
    private static let folderEnd = Color(red: 0.66, green: 0.60, blue: 0.34)
    static var folderGradient: LinearGradient {
        LinearGradient(colors: [folderStart, folderEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var folderColor: Color { folderStart }

    static let cardRadius: CGFloat = 18
    static let heroRadius: CGFloat = 24
}

extension View {
    /// The standard soft card elevation used throughout -- a gentle lift
    /// rather than a hard drop shadow.
    func themeCardShadow() -> some View {
        shadow(color: Theme.cardShadow, radius: 14, x: 0, y: 5)
    }
}

extension Font {
    /// Rounded system font for headings/titles -- a friendlier, softer
    /// silhouette than the default grotesk, without needing a bundled font.
    static func themeHeading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension MediaType {
    var iconName: String {
        switch self {
        case .podcast: return "mic.fill"
        case .hymn: return "music.note"
        case .video: return "play.rectangle.fill"
        }
    }

    /// Each type's flat accent (text, small icons, selection rings) --
    /// the first stop of its `gradient` below, so a single-color use and
    /// the gradient use always stay in the same family.
    var tintColor: Color { gradientColors[0] }

    /// A two-hue gradient per type -- teal-into-indigo, sage-into-gold,
    /// amber-into-coral -- rather than one flat fill or a stock
    /// red/blue/green/orange grid. Gives icons, cards and buttons real
    /// color depth while the three families stay clearly related.
    var gradientColors: [Color] {
        switch self {
        case .podcast:
            return [Color(red: 0.22, green: 0.50, blue: 0.60), Color(red: 0.36, green: 0.40, blue: 0.74)]
        case .hymn:
            return [Color(red: 0.42, green: 0.62, blue: 0.42), Color(red: 0.78, green: 0.68, blue: 0.32)]
        case .video:
            return [Color(red: 0.86, green: 0.58, blue: 0.32), Color(red: 0.80, green: 0.38, blue: 0.42)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum HomeSection: String, CaseIterable, Identifiable {
    case featured
    case podcasts
    case hymns
    case videos
    case downloads

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .featured: return "Featured"
        case .podcasts: return "Podcasts"
        case .hymns: return "Hymns"
        case .videos: return "Videos"
        case .downloads: return "Downloads"
        }
    }

    var iconName: String {
        switch self {
        case .featured: return "sparkles"
        case .podcasts: return MediaType.podcast.iconName
        case .hymns: return MediaType.hymn.iconName
        case .videos: return MediaType.video.iconName
        case .downloads: return "arrow.down.circle.fill"
        }
    }

    var tintColor: Color { gradientColors[0] }

    var gradientColors: [Color] {
        switch self {
        case .featured:
            return [Theme.mint, Color(red: 0.30, green: 0.62, blue: 0.72)]
        case .podcasts: return MediaType.podcast.gradientColors
        case .hymns: return MediaType.hymn.gradientColors
        case .videos: return MediaType.video.gradientColors
        case .downloads:
            // A properly saturated violet-into-plum, not the earlier
            // slate-grey start -- that near-grey tone made this circle's
            // selection ring read as a flat grey halo instead of a color
            // "lighting up" like the other four, which is what made
            // selecting it look inconsistent even though the ring/glow
            // code itself is identical for all five.
            return [Color(red: 0.44, green: 0.38, blue: 0.76), Color(red: 0.68, green: 0.40, blue: 0.66)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
