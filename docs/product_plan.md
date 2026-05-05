# ChiMusic Product Plan

## Goal

Build a Flutter app for Android, iOS, and macOS that captures the core product flow of a modern music streaming app:

- discover music from a rich home feed
- search tracks, artists, and collections quickly
- browse and manage a personal library
- open playlist and album detail views
- control playback from a floating mini player and a full player view

This version uses local mock data so the experience is complete without a backend.

## MVP Scope

### Core screens

1. Home
   - greeting header
   - featured mix hero
   - recently played
   - editorial rows
2. Search
   - prominent search field
   - category grid
   - live results for tracks and collections
3. Library
   - filters for playlists, albums, and downloads
   - saved collections
   - liked songs summary
4. Collection detail
   - playlist or album hero
   - actions and metadata
   - track list
5. Now playing
   - large artwork treatment
   - transport controls
   - queue preview
   - like and save affordances

### Platform adaptation

- Android and iOS use a bottom navigation shell with a floating mini player.
- macOS uses a side navigation rail and keeps more secondary content visible.
- Layout spacing, panel widths, and interaction states adapt based on screen size.

## Information Architecture

- `AppShell`
  - `HomeScreen`
  - `SearchScreen`
  - `LibraryScreen`
- `CollectionDetailPage`
- `NowPlayingSheet`

## State Model

A single application controller owns:

- current navigation tab
- selected collection
- search query
- saved collections
- liked tracks
- playback queue and current track
- simulated playback progress

## Delivery Strategy

1. Build the visual system first so all screens share one language.
2. Implement responsive navigation and the persistent mini player.
3. Add the three primary tabs with mock content.
4. Connect detail and playback flows.
5. Run format and widget tests to confirm the app boots cleanly.
