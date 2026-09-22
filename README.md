# 拾穗 SJCA — Church Media App

A native iOS app for San Jose Christian Assembly that streams and downloads sermons, hymns, and videos in English and Simplified Chinese — built solo end-to-end, from architecture through App Store submission.

<p align="center">
  <img src="docs/screenshots/01_home.png" width="230" alt="Home screen with content categories" />
  <img src="docs/screenshots/02_podcasts.png" width="230" alt="Podcast series list" />
  <img src="docs/screenshots/03_me.png" width="230" alt="Language toggle and settings" />
</p>

## Overview

A local church needed a way to get sermons, hymns, and video content in front of a bilingual congregation without relying on a third-party podcast app or a paywalled CMS. I designed and built a native SwiftUI app that ships with a bundled content library, supports offline downloads for spotty-connectivity listening, and can push new content to every installed copy **without an App Store resubmission** — a lightweight remote-manifest fetch replaces what would normally require a full backend.

The app is complete and was submitted to the App Store, including handling the full Apple Developer signing/provisioning pipeline for a first-time organization account.

## Features

- **Podcasts, hymns, and videos** organized into browsable categories, with a featured/latest content rail on Home
- **Fully bilingual UI** — English and Simplified Chinese, switchable in-app independent of the device's system language
- **Offline downloads** — save any item locally; playback and video work with no connection once downloaded
- **Background audio playback** with play/pause from the lock screen, resume-where-you-left-off listening history
- **Remote content updates** — editing one hosted JSON file updates every installed copy's library on next refresh, no app update required
- **Push-style content refresh** and a settings screen for manual refresh + last-updated status

## Tech Stack

Swift, SwiftUI, Combine, AVFoundation (audio/video playback), XcodeGen (project generation from a declarative `project.yml`), Firebase Storage (content/media hosting), `NSLocalizedString` / `.xcstrings` catalogs for localization.

## How It Works

`ContentRepository` is the single seam between "where content comes from" and everything else in the app (views, player, downloads):

1. On first launch, the app reads a **bundled `content.json`** — so it always works offline out of the box.
2. On every launch (and pull-to-refresh), it fetches a **remote manifest URL** pointing at a hosted copy of the same JSON shape. A successful fetch replaces what's shown and is cached to disk.
3. Nothing else in the app — `AudioPlayerManager`, `DownloadManager`, every View — needs to know which source served the data; they all just read `ContentRepository.items`.

This means publishing new sermons is a one-file edit on the hosting side, with zero app-side deploy. See [`docs/CUSTOMIZING.md`](docs/CUSTOMIZING.md) for the full architecture writeup and a guide to forking this for another organization.

## Setup

```bash
git clone https://github.com/allenlong2007/ChurchApp.git
cd ChurchApp
xcodegen generate   # regenerates ChurchApp.xcodeproj from project.yml
open ChurchApp.xcodeproj
```

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and Xcode 16+. Select the `ChurchApp` scheme and an iPhone Simulator, then ⌘R.

## Status

Submitted to the App Store — awaiting Apple review.
