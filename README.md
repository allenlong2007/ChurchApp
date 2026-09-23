# 拾穗 SJCA — Church App

An iPhone app for my church, San Jose Christian Assembly, where people can listen to sermons and hymns and watch videos in English or Chinese. I built the whole thing myself and submitted it to the App Store.

<p align="center">
  <img src="docs/screenshots/01_home.png" width="230" alt="Home screen with content categories" />
  <img src="docs/screenshots/02_podcasts.png" width="230" alt="Podcast series list" />
  <img src="docs/screenshots/03_me.png" width="230" alt="Language toggle and settings" />
</p>

## What it does

The church wanted an easy way to share sermons and music with the congregation in both English and Chinese, without paying for some third-party app. So I built one from scratch.

You can browse sermons, hymns, and videos, switch the whole app between English and Chinese, and download anything to listen to offline. New content can be added anytime just by updating a file online — nobody has to update the app itself.

## Features

- Browse sermons, hymns, and videos by category
- Switch between English and Chinese anytime, right in the app
- Download episodes to listen without an internet connection
- Audio keeps playing in the background — lock screen, other apps, screen off
- Remembers where you left off in whatever you were listening to
- New content shows up automatically, no app update needed

## Built with

Swift and SwiftUI (Apple's tools for building iOS apps), AVFoundation for playing audio and video, XcodeGen to keep the Xcode project file in sync with the code, and Firebase to host the media files.

## How it's put together

The app comes with a small starter set of content built right in, so it always works even with no internet. Every time you open it, it also checks online for an updated version of that same content list — if there's something new, it swaps it in automatically. That's how new sermons get added without ever having to update the app itself.

More details on how it's set up, and how to adapt this for another church, are in [docs/CUSTOMIZING.md](docs/CUSTOMIZING.md).

## Running it yourself

```bash
git clone https://github.com/allenlong2007/ChurchApp.git
cd ChurchApp
xcodegen generate
open ChurchApp.xcodeproj
```

You'll need [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and Xcode. Pick the ChurchApp scheme, choose a simulator, and hit Run.

## Status

Submitted to the App Store, waiting on Apple's review.
