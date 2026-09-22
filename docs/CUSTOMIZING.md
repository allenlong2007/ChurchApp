# Customizing & Forking This App

This is the detailed setup guide for turning this codebase into your own
church's app — renaming it, swapping content, and publishing it. For the
project overview, screenshots, and architecture summary, see the
[main README](../README.md).

---

A native iOS app (SwiftUI) for browsing and playing your church's sermons and
songs, with English and Mandarin (Simplified Chinese) UI, offline downloads,
and a content model that lets you publish new sermons/songs without
resubmitting to the App Store.

There is **no backend/database yet** — content ships as a bundled JSON file,
with an optional "remote manifest" mechanism you can turn on later (see
[Publishing new content without an app update](#publishing-new-content-without-an-app-update)).
A path to a real database is at the bottom.

---

## 1. Prerequisites

1. **Install Xcode** from the Mac App Store (free, ~15GB). This machine
   currently only has the Command Line Tools, which can't build or run iOS
   apps — you need full Xcode for that.
2. Open Xcode once after installing so it finishes installing components,
   and agree to the license.
3. You said you already have an **Apple Developer Program** account
   ($99/year) — you'll use that in step 5 (Publishing).

## 2. Opening the project

The project was generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(already installed via Homebrew) from `project.yml`. That means the
`.xcodeproj` file is disposable/regenerable — **don't hand-edit it**. Instead:

- To add/remove/rename Swift files, just add/remove/rename them on disk under
  `Sources/`, then run:
  ```bash
  cd "ChurchApp"
  xcodegen generate
  ```
- Then open `ChurchApp.xcodeproj` in Xcode (double-click it, or `open ChurchApp.xcodeproj`).

First run:
1. Select the `ChurchApp` scheme and an iPhone Simulator (e.g. iPhone 16) at
   the top of the Xcode window.
2. Press ⌘R to build and run.
3. You should see the Home tab with the sample sermons/songs, a Downloads
   tab, and a Me tab with the language switch.

## 3. Project structure

```
ChurchApp/
  project.yml              # XcodeGen spec — the source of truth for the Xcode project
  Sources/
    App/                    # App entry point, root TabView
    Models/                 # MediaItem (a sermon or song)
    Data/                   # ContentRepository — where content comes from
    Services/               # AudioPlayerManager, DownloadManager
    Views/                  # Home, Player, Downloads, Settings screens
  Resources/
    content.json            # Bundled sample content — replace/extend this
    Localizable.xcstrings    # English + Simplified Chinese UI strings
    Assets.xcassets          # App icon + accent color
```

## 4. Making it your church's app

- **Name**: change `CFBundleDisplayName` in `project.yml` (`"Church App"`)
  to your church's name, then `xcodegen generate` again.
- **Bundle ID**: change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` from
  `com.yourchurch.churchapp` to something under a domain you control
  (e.g. `org.gracechurch.app`), then `xcodegen generate`.
- **Signing team**: in Xcode, select the ChurchApp target → *Signing & Capabilities*
  → pick your Apple Developer team. (XcodeGen doesn't set this — it's tied to
  your local Xcode account, so it's a one-time manual step per machine.)
- **App icon**: in Xcode, open `Resources/Assets.xcassets/AppIcon`, and drag
  in a 1024×1024 PNG (no transparency). Xcode/App Store Connect require this
  before you can submit.
- **Accent color**: `Resources/Assets.xcassets/AccentColor` currently holds a
  placeholder purple — change it in Xcode's asset editor to your church's
  brand color.

## 5. Adding sermons/songs today (no database)

Open `Resources/content.json` and add an entry to the `items` array:

```json
{
  "id": "s005",
  "type": "sermon",
  "title": "Walking in the Spirit",
  "speaker": "Pastor Grace Yu",
  "series": "Sunday Message",
  "category": "Sunday Message",
  "dateAdded": "2026-08-25T00:00:00Z",
  "durationSeconds": 2500,
  "audioURL": "https://yourhost.com/sermons/2026-08-25.mp3",
  "imageURL": null,
  "language": "en",
  "isRecommended": false
}
```

Notes:
- `id` must be unique — anything works, e.g. `s005`, `n010`.
- `type` is `"sermon"` or `"song"`.
- `language` is `"en"` or `"zh"` — this tags the *content's* spoken/sung
  language, independent of the app's UI language.
- `audioURL` must be a direct, playable audio file URL (mp3/m4a), reachable
  over HTTPS. You need to host the actual audio files somewhere — options:
  - A cheap/free static host: GitHub (raw file URLs), Cloudflare R2, AWS S3
    (public bucket), Firebase Storage, Backblaze B2.
  - Whatever your church already uses (e.g. if sermons are already on
    SoundCloud/Podbean/Anchor, use their direct MP3 links if available).

After editing `content.json`, rebuild the app (⌘R) and it shows up. This
requires a new build — for the same edit to reach everyone's phone *without*
rebuilding, see the next section.

## 6. Publishing new content without an app update

`Sources/Data/ContentRepository.swift` already supports this. The idea:
host `content.json` (the same file, same shape) at a public URL, and set
`ContentRepository.remoteManifestURL` to that URL. On every launch (and on
pull-to-refresh, and on tapping "Refresh Content" in Settings), the app
fetches that URL and replaces what it shows — no App Store review needed.

Simplest way to host it (free):
1. Create a public GitHub repo (or use one you have).
2. Put `content.json` in it.
3. Use the **raw** URL, e.g.
   `https://raw.githubusercontent.com/yourchurch/app-content/main/content.json`.
4. In `ContentRepository.swift`, set:
   ```swift
   static let remoteManifestURL: URL? = URL(string: "https://raw.githubusercontent.com/yourchurch/app-content/main/content.json")
   ```
5. `xcodegen generate`, rebuild, ship that one version to the App Store.
   From then on, editing the JSON file on GitHub (or wherever you host it)
   updates the app for everyone within one refresh — no resubmission.

This is intentionally still "just a file," not a database — good enough for
a church media library that one or two admins update. See the last section
for when/how to graduate to a real backend.

## 7. Localization (English / Mandarin)

- UI text lives in `Resources/Localizable.xcstrings`. Open it in Xcode
  (double-click) for a spreadsheet-style editor, or hand-edit the JSON.
- The app defaults to English (`appLanguage` = `"en"` in `ChurchAppApp.swift`)
  regardless of the phone's system language, and users can switch to 中文
  from the **Me** tab — this is a full in-app override (via
  `.environment(\.locale, ...)`), not just following system settings.
- To add a third language later (e.g. Spanish): add an `es` localization to
  every key in `Localizable.xcstrings`, add an `es` option to the picker in
  `SettingsView.swift`.
- Sermon/song titles themselves are **not** translated (they're real-world
  content in whatever language they were delivered in) — only app chrome
  (tab names, buttons, labels) is localized.

## 8. Testing before you submit

- Run on a couple of Simulator devices (iPhone SE for small screens, iPhone
  16 Pro Max for large) and both light/dark mode.
- Test the language switch, playback, background audio (start playback,
  press the Simulator's Home button, confirm audio keeps playing), and
  downloading/deleting an item while offline (Simulator: Settings → toggle
  Wi-Fi off, or use Xcode's Network Link Conditioner).
- If you have a physical iPhone, run on-device via Xcode (free, no
  Developer Program needed just to test on your own device).

## 9. Publishing to the App Store

1. In Xcode: **Product → Archive** (must select "Any iOS Device" or a real
   device as the run destination first, not a Simulator).
2. When the Organizer window opens, click **Distribute App → App Store
   Connect → Upload**.
3. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com),
   create a new app record (My Apps → +), matching the bundle ID you set in
   step 4.
4. Fill in: app name, description, screenshots (Simulator screenshots are
   fine — ⌘S in Simulator saves one), category, support URL, privacy policy
   URL (required — even a simple one-pager saying what data you collect;
   this app collects none by default), and the **App Privacy** questionnaire
   (answer "No" to data collection unless you add analytics/accounts later).
5. Attach the build you uploaded in step 2, submit for review.
6. Optional but recommended: use **TestFlight** first (same Organizer →
   Distribute → App Store Connect, then in App Store Connect enable
   TestFlight and invite a few people, e.g. church leadership) before the
   public submission.

Apple review for a straightforward content app like this is typically a
few days. Common rejection reasons to avoid: broken links/placeholder text
left in (make sure `content.json` has real content before submitting),
missing privacy policy URL, and a missing/placeholder app icon.

## 10. Roadmap: adding a real database later

Right now `ContentRepository` is the single seam between "how the app gets
its content" and "everything else" (views, player, downloads). Nothing else
in the app needs to know where content comes from. To upgrade:

1. Pick a backend: **Firebase Firestore** or **Firebase Realtime Database**
   are the easiest to wire into a Swift app (official SDK, generous free
   tier); **Supabase** is a good Postgres-based alternative if you'd rather
   have SQL. Either works well for a media library.
2. Add the SDK via Swift Package Manager (Xcode → File → Add Package
   Dependencies).
3. Replace the body of `ContentRepository.refresh()` with a query against
   that backend, decoding results into the same `[MediaItem]` array.
4. (Optional, once you have a real backend) build a tiny admin screen or
   use the backend's own web console to add/edit sermons — no more manual
   JSON editing.
5. Natural next features that a real backend unlocks: user accounts,
   per-user favorites/bookmarks that sync across devices, push notifications
   for new sermons, view/listen analytics, admin roles for who can publish
   content.

None of steps 1–3 require changing `MediaItem`, `AudioPlayerManager`,
`DownloadManager`, or any View — they all just read `ContentRepository.items`.
