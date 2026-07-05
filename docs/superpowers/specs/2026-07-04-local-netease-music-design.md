# Local NetEase-Style Music App Design

## Goal

Rework ChiMusic into a local-first Flutter music app that captures the core feel of NetEase Cloud Music without registration, login, cloud sync, cloud restore, user social features, membership, or remote catalog features. Playback history, favorites, saved collections, queue state, search history, and resume positions remain stored locally.

## Confirmed Decisions

- Product direction: local NetEase-style player.
- Platform priority: mobile and desktop both matter, with shared product logic and platform-specific shells.
- Account and community scope: remove visible registration, login, profile identity, cloud sync, membership, Pro, AI quota, comments, follows, activity feeds, and social/community surfaces.
- Implementation approach: keep the current Flutter playback, controller, importer, repository, and shell foundation; clean the product surface first, then safely reduce legacy internal account/cloud concepts where the first implementation plan can do so without migration churn.

## Current Project Context

The app already has a Flutter structure with:

- `MusicAppController` for app state, queue, playback, local collections, search, likes, saves, and local playback history.
- `SqliteMusicRepository` plus JSON snapshot fallback for local persistence.
- `LocalAudioImporter` and platform file access helpers for importing audio files and folders.
- Mobile and desktop shells: `MobilePlayerShell` and `MacosPlayerShell`.
- Screens for home, search, library, collection details, and now playing.
- Tests for controller behavior, repository persistence, importer behavior, and widget boot flows.

The same project also contains prototype surfaces that conflict with this goal: auth, cloud sync, subscription/Pro, AI quota language, profile/settings copy, and cloud/AI-oriented cards. These must stop being visible in the first version.

## Product Boundaries

Every visible first-version feature must work without:

- an account,
- network access,
- cloud state,
- cross-device sync,
- server recommendations,
- social graph data.

If a feature cannot satisfy that rule, it is removed from navigation, settings, cards, banners, buttons, and empty states for this release.

## In Scope

- Import local audio files and folders.
- Browse all local tracks.
- Browse local albums, artists, folders, liked songs, saved local collections, and generated local playlists.
- Search tracks, albums, artists, folders, and saved collections on device.
- Maintain local recent searches.
- Play tracks, collections, and generated local mixes.
- Maintain queue, current track, current collection, position, shuffle, repeat, and volume state.
- Like tracks and save local collections.
- Persist playback history locally with play count, last played time, last position, completed-at time, and playback events where already supported.
- Show continue-listening and recently played modules.
- Show NetEase-inspired local discovery modules: daily local mix, recent imports, most played, favorites, albums, artists, and folder playlists.
- Show missing/unavailable local files with recovery actions.
- Keep waveform/progress and lyrics states where available from local metadata or existing local features.

## Out of Scope

- Registration, login, sign out, user profile identity.
- Cloud sync, cloud restore, cloud match, cloud storage, and cross-device continuity.
- Membership, Pro, subscription, upgrade prompts, paid feature gates.
- AI search quotas, AI upsell, and AI-branded results in the first product surface.
- Remote streaming catalog.
- Comments, follows, messages, friends, social feed, community tab, or user-generated network content.
- Fake disabled buttons that imply unavailable network/community features.

## Information Architecture

### Mobile

Mobile keeps a bottom-navigation shell with three primary tabs:

- Discover
- Search
- Library

The mobile shell keeps a persistent mini player when a track is active. The top area exposes search and import/settings actions without any profile or account affordance.

### Desktop

Desktop keeps a sidebar shell with the same product areas and wider layouts:

- Discover
- Search
- Library
- History or local playback activity where it fits the existing shell
- Import and local settings actions

Desktop can keep a right-side now-playing and queue area because the current wide shell already supports richer playback context.

## Screen Design

### Discover

Discover replaces account/cloud/AI-oriented home content with local music modules:

- import-first onboarding for an empty library,
- daily local recommendations,
- continue listening,
- recently played,
- recently imported,
- most played,
- liked songs,
- albums,
- artists,
- local folders as playlists,
- saved local collections.

The page should feel close to NetEase Cloud Music through music density, album-art hierarchy, and red accents, while preserving enough of the existing ChiMusic visual system to avoid a full rewrite.

### Search

Search is fully on-device:

- Search field.
- Recent local searches.
- Suggestions derived from local library metadata and recent behavior.
- Grouped results for tracks, albums, artists, folders, and saved collections.
- No AI mode, AI badge, AI quota, Pro prompt, or upgrade action.

### Library

Library is the local collection manager:

- tracks,
- albums,
- artists,
- folders,
- liked songs,
- saved collections,
- playback history,
- recently imported,
- unavailable files,
- import files and import folder actions.

Library copy must say that audio and playback records are stored locally. It must not mention sync, membership, cloud, profile, sign-in, or AI continuity.

### Player

The mini player and full player keep:

- current artwork,
- title and artist,
- play/pause,
- next/previous,
- seek/progress,
- shuffle/repeat,
- queue,
- like and save actions,
- waveform/progress where available,
- lyrics state where available,
- local history updates.

The full player must not include comment, share-to-feed, profile, cloud, or social actions. A local share/export action can be considered later, but it is not required for this first spec.

## Visual Direction

Use a NetEase-inspired music product language:

- red as the primary accent,
- dense content rows and grids,
- clear album art hierarchy,
- prominent circular playback controls,
- compact chips for filters and collection types,
- warm local-library copy.

Do not make the app a one-to-one branded clone. Keep the ChiMusic name and original assets. The goal is product-behavior and interaction resemblance, not infringing brand replication.

## Data Flow

1. The user imports files or folders.
2. The importer reads metadata, artwork, duration, and source records.
3. The controller updates tracks, local collections, search indexes, and queue-ready data.
4. The repository persists local state using SQLite and the JSON snapshot fallback.
5. The user browses Discover, Search, Library, collection details, and the player.
6. Playback updates queue state, current track, current collection, progress, play counts, playback events, and resume positions.
7. Local discovery modules refresh from local tracks, likes, imports, and playback history.

## Persistence Requirements

Continue persisting these locally:

- imported tracks,
- source records,
- likes,
- saved local collections,
- recent track IDs,
- recent searches,
- playback history,
- playback events,
- queue track IDs,
- current track ID,
- current collection ID,
- playback position,
- library filter and sort,
- selected tab,
- theme,
- shuffle and repeat.

Existing stored user/cloud/AI fields can remain in storage formats during the first implementation if removing them would create risky migrations. They must not be restored into visible product state or shown in the UI.

## Error Handling

- Import failure: show a local status message and keep existing library state intact.
- File missing or unavailable: mark the track unavailable and offer relink or remove actions where the current UI supports it.
- Playback setup failure: show a recovery message and let the user continue browsing.
- Metadata read failure: import the file with safe fallback title, artist, album, and artwork values.
- Persistence failure: remain best-effort and do not block playback controls.
- Repository restore failure: show local recovery copy that asks the user to import music again, without referring to cloud restore or account state.

## Testing Strategy

Controller tests should cover:

- local search ranking and recent searches,
- library filters and sorts,
- playing all tracks and saved collections,
- liked songs queue,
- playback history play counts and resume positions,
- restore behavior without user or remote snapshot state,
- no account/cloud side effects during restore,
- shuffle/repeat and skip behavior.

Repository tests should cover:

- local snapshot save/load,
- playback history and queue persistence,
- backward-compatible loading when legacy user/cloud fields exist.

Widget tests should cover:

- app boots into mobile and desktop shells,
- empty library shows import-first onboarding,
- imported library shows Discover/Search/Library content,
- primary surfaces do not display sign-in, sync, cloud, membership, Pro, upgrade, AI quota, comments, follows, or social feed copy.

Manual verification should cover:

- import local files,
- play a track,
- seek and pause,
- restart the app,
- confirm current queue and playback history restore locally,
- confirm no visible account or cloud entry remains.

## Implementation Notes

- Prefer cleaning visible product behavior before deep storage migrations.
- Keep edits scoped to existing controller, models, screens, widgets, and tests.
- Avoid adding network APIs or remote service dependencies.
- If a mock service is no longer used by visible product behavior, remove the UI that calls it first; remove service classes only when tests confirm no app code depends on them.
- Keep original audio files untouched when clearing the in-app library.

## Acceptance Criteria

- A fresh install shows a local music onboarding surface with import actions.
- Imported music populates Discover, Search, Library, collection details, mini player, and full player.
- Playback history and resume state survive app restart through local persistence.
- The app is usable offline and never asks for account setup.
- No visible first-version surface mentions sign-in, cloud sync, cloud restore, membership, Pro, upgrade, AI quota, comments, follows, activity feed, or social/community features.
- Existing Flutter tests pass after updates, and new/updated tests protect the local-only product boundary.
