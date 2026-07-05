# Local NetEase-Style Music Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert ChiMusic's visible product into a local-first NetEase Cloud Music-style player with no registration, login, cloud sync, membership, Pro, AI quota, comments, follows, or social feed.

**Architecture:** Keep the existing Flutter app, controller, importer, repository, mobile shell, and desktop shell. First protect the local-only boundary with tests, then remove user/cloud/AI behavior from visible controller flow and UI surfaces while preserving local playback, search, library, queue, and playback history persistence.

**Tech Stack:** Flutter, Dart, ChangeNotifier controller state, just_audio, shared_preferences, sqflite, flutter_test.

---

## File Structure

- Modify `test/chimusic_controller_test.dart`: replace AI/Pro tests with local-only restore/search boundary tests.
- Modify `test/widget_test.dart`: update navigation/copy expectations and add forbidden-copy widget coverage across reachable mobile shell surfaces.
- Modify `lib/state/chimusic_controller.dart`: stop restoring users/remote snapshots; make search standard-only from visible flows; remove visible sync side effects from local mutations.
- Modify `lib/screens/search_screen.dart`: remove AI mode UI, AI result branching, Pro quota copy, and upgrade action.
- Modify `lib/screens/app_details_sheet.dart`: turn profile/settings into local library settings.
- Modify `lib/screens/home_screen.dart`: remove membership callouts and cloud sync insight; adjust local discovery copy and metrics.
- Modify `lib/screens/library_screen.dart`: remove membership/sync pills from library context.
- Modify `lib/screens/collection_detail_page.dart`: remove AI Search wording from smart playlist copy.
- Inspect and modify `lib/widgets/mobile_player_shell.dart` and `lib/widgets/macos_player_shell.dart` only where visible profile/account/cloud/social labels remain.
- Do not modify the existing `.gitignore` conflict in this plan; it is unrelated user/worktree state.
- Do not commit `.superpowers/` browser companion files.

## Forbidden Product Copy

After implementation, primary visible app surfaces must not contain any of these user-facing terms:

```text
Sign In
Sign Out
sign-in
Signed in
Signed out
cloud sync
Cloud sync
Sync Library
Syncing
Synced
Membership
Pro
Upgrade
AI search
AI Search
AI tries
AI quota
Unlock Pro
comments
follows
social feed
```

Storage compatibility code may still contain model names such as `UserProfile`, `SyncState`, or `hasUnlockedAiUpsell` during this first pass if removing them would require a database migration.

### Task 1: Protect The Local-Only Boundary In Tests

**Files:**
- Modify: `test/chimusic_controller_test.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Replace AI/Pro controller tests with local-only behavior tests**

In `test/chimusic_controller_test.dart`, remove the tests named:

```dart
test(
  'ai search uses free trials and surfaces intent-based matches',
  () async {
    ...
  },
);

test('upgradeToPro unlocks unlimited AI access', () async {
  ...
});
```

Add these tests in the same `MusicAppController` group:

```dart
test('submitSearch always stays on local search and records recent terms', () {
  final favoriteTrack = _track(
    folderPath: '/music/midnight',
    title: 'Night Drive',
    artist: 'Signal Bloom',
    album: 'After Hours',
    duration: const Duration(minutes: 4, seconds: 10),
    importedAt: DateTime(2026, 5, 6, 21),
  );
  final controller = MusicAppController(
    enableAudio: false,
    initialTracks: [favoriteTrack],
    initialSearchMode: SearchMode.ai,
    initialAiSearchTrialsRemaining: 0,
  );
  addTearDown(controller.dispose);

  controller.updateSearchQuery('night');
  controller.submitSearch();

  expect(controller.searchMode, SearchMode.standard);
  expect(controller.recentSearches.first, 'night');
  expect(controller.searchTrackResults.single.id, favoriteTrack.id);
  expect(controller.aiSearchResults, isEmpty);
  expect(controller.shouldShowAiUpsell, isFalse);
});

test('restoreSession ignores persisted user and cloud state', () async {
  final track = _track(
    folderPath: '/music/local',
    title: 'Offline Song',
    artist: 'Local Artist',
    album: 'Local Album',
    duration: const Duration(minutes: 3),
    importedAt: DateTime(2026, 5, 6, 12),
  );
  final store = _FakeRepository(
    snapshot: MusicRepositorySnapshot(
      tracks: [track],
      playbackSession: PlaybackSessionState(
        queueTrackIds: [track.id],
        currentTrackId: track.id,
        currentCollectionId: 'all_tracks',
        position: const Duration(seconds: 42),
      ),
      userProfile: UserProfile(
        id: 'legacy-user',
        name: 'Legacy User',
        email: 'legacy@example.com',
        membershipTier: MembershipTier.pro,
        signedInAt: DateTime(2026, 5, 1, 8),
      ),
      aiSearchTrialsRemaining: 0,
      hasUnlockedAiUpsell: true,
    ),
  );
  final controller = MusicAppController(
    enableAudio: false,
    repository: store,
  );
  addTearDown(controller.dispose);

  await controller.restoreSession();
  await pumpEventQueue();

  expect(controller.importedTrackCount, 1);
  expect(controller.currentTrack?.id, track.id);
  expect(controller.position, const Duration(seconds: 42));
  expect(controller.isSignedIn, isFalse);
  expect(controller.hasPro, isFalse);
  expect(controller.shouldShowAiUpsell, isFalse);
  expect(controller.syncState.phase, SyncPhase.offline);
});
```

If `test/chimusic_controller_test.dart` does not already have `_FakeRepository`, add it near the existing fake store helpers:

```dart
class _FakeRepository implements MusicRepository {
  _FakeRepository({required this.snapshot});

  MusicRepositorySnapshot snapshot;
  MusicRepositorySnapshot? lastSaved;

  @override
  Future<MusicRepositorySnapshot> load() async => snapshot;

  @override
  Future<void> save(MusicRepositorySnapshot snapshot) async {
    lastSaved = snapshot;
  }

  @override
  Future<void> close() async {}
}
```

- [ ] **Step 2: Add widget forbidden-copy test**

In `test/widget_test.dart`, add this helper near the bottom:

```dart
void expectNoLocalOnlyForbiddenCopy() {
  const forbiddenTerms = <String>[
    'Sign In',
    'Sign Out',
    'sign-in',
    'cloud sync',
    'Cloud sync',
    'Sync Library',
    'Membership',
    'Pro',
    'Upgrade',
    'AI search',
    'AI Search',
    'AI tries',
    'Unlock Pro',
    'comments',
    'follows',
    'social feed',
  ];

  for (final term in forbiddenTerms) {
    expect(find.textContaining(term, findRichText: true), findsNothing);
  }
}
```

Add this widget test before the helper classes:

```dart
testWidgets('primary shells do not expose account cloud pro or ai copy', (
  tester,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final track = Track(
    id: '/music/local/North Coast - Local Light.mp3',
    filePath: '/music/local/North Coast - Local Light.mp3',
    fileName: 'North Coast - Local Light.mp3',
    folderPath: '/music/local',
    title: 'Local Light',
    artist: 'North Coast',
    album: 'Local Sessions',
    palette: const [Color(0xFFE53935), Color(0xFF3A1D1B), Color(0xFF111318)],
    importedAt: DateTime(2026, 5, 6, 15),
    duration: const Duration(minutes: 4),
    fileExtension: 'mp3',
  );
  final controller = MusicAppController(
    enableAudio: false,
    initialTracks: [track],
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(ChiMusicRoot(controller: controller));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));

  expectNoLocalOnlyForbiddenCopy();

  await tester.tap(find.text('音乐库'));
  await tester.pumpAndSettle();
  expectNoLocalOnlyForbiddenCopy();

  await tester.tap(find.text('记录'));
  await tester.pumpAndSettle();
  expectNoLocalOnlyForbiddenCopy();

  await tester.tap(find.text('设置'));
  await tester.pumpAndSettle();
  expectNoLocalOnlyForbiddenCopy();
});
```

- [ ] **Step 3: Run focused tests and confirm failures**

Run:

```bash
flutter test test/chimusic_controller_test.dart test/widget_test.dart
```

Expected before implementation: tests fail because `restoreSession` restores user state and visible widgets still contain AI/Pro/cloud/sign-in copy.

- [ ] **Step 4: Commit failing tests only**

Run:

```bash
git add test/chimusic_controller_test.dart test/widget_test.dart
git commit -m "test: capture local-only music app boundary"
```

Expected: commit succeeds with only test changes staged.

### Task 2: Make Controller Runtime Local-Only

**Files:**
- Modify: `lib/state/chimusic_controller.dart`
- Test: `test/chimusic_controller_test.dart`

- [ ] **Step 1: Stop restoring user and remote snapshots**

In `restoreSession`, replace the user/cloud restoration block:

```dart
final restoredUser =
    snapshot.userProfile ?? await _authService.restoreUser();
if (restoredUser != null) {
  _userProfile = restoredUser;
}
_syncState = _buildDefaultSyncState();
await _refreshOnlineState(notifyAfterCompletion: false);
if (_userProfile != null) {
  await _restoreCloudSnapshotIfAvailable(
    applyRemoteWhenLibraryEmpty: true,
  );
}
```

with:

```dart
_userProfile = null;
_hasUnlockedAiUpsell = false;
_aiSearchTrialsRemaining = 0;
_aiSearchResults = <Track>[];
_aiSearchSummary = null;
_isRunningAiSearch = false;
_syncState = _buildDefaultSyncState();
```

- [ ] **Step 2: Force standard search behavior**

Update `setSearchMode` so it ignores AI mode:

```dart
void setSearchMode(SearchMode mode) {
  final nextMode = SearchMode.standard;
  if (_searchMode == nextMode &&
      _aiSearchResults.isEmpty &&
      _aiSearchSummary == null &&
      !_isRunningAiSearch) {
    return;
  }

  _searchMode = nextMode;
  _aiSearchSummary = null;
  _aiSearchResults = <Track>[];
  _isRunningAiSearch = false;
  _hasUnlockedAiUpsell = false;
  notifyListeners();
  _persistSession();
}
```

Update `submitSearch` by removing the AI branch:

```dart
void submitSearch([String? value]) {
  final candidate = (value ?? _searchQuery).trim();
  if (candidate.isEmpty) {
    return;
  }

  _searchMode = SearchMode.standard;
  _aiSearchResults = <Track>[];
  _aiSearchSummary = null;
  _isRunningAiSearch = false;
  _hasUnlockedAiUpsell = false;
  _rememberSearch(candidate);
  notifyListeners();
  _persistSession();
}
```

Update `applySearchSuggestion` by removing the AI branch:

```dart
void applySearchSuggestion(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return;
  }

  _searchMode = SearchMode.standard;
  _searchQuery = normalized;
  _aiSearchResults = <Track>[];
  _aiSearchSummary = null;
  _isRunningAiSearch = false;
  _hasUnlockedAiUpsell = false;
  _rememberSearch(normalized);
  notifyListeners();
  _persistSession();
}
```

- [ ] **Step 3: Remove sync side effects from local mutations**

Remove these calls from local-only methods:

```dart
_queueSyncIfSignedIn();
```

Specifically remove them from:

- `clearPlaybackHistory`
- `toggleSavedCollection`
- `toggleLikedTrack`
- `clearLibrarySession`

Do not delete `_queueSyncIfSignedIn` or cloud methods in this task unless the analyzer reports they are unused and removal is straightforward. Storage compatibility cleanup is deliberately deferred.

- [ ] **Step 4: Ensure persisted snapshots no longer save active user state**

In `_buildRepositorySnapshot` or the method that constructs `MusicRepositorySnapshot`, set the user and AI upsell fields to local-only values:

```dart
userProfile: null,
aiSearchTrialsRemaining: 0,
hasUnlockedAiUpsell: false,
```

Keep queue, history, likes, saved collections, recent searches, theme, shuffle, and repeat unchanged.

- [ ] **Step 5: Run controller tests**

Run:

```bash
flutter test test/chimusic_controller_test.dart
```

Expected: controller tests pass. If any old AI/Pro test remains, delete or rewrite it to assert local-only behavior.

- [ ] **Step 6: Commit controller changes**

Run:

```bash
git add lib/state/chimusic_controller.dart test/chimusic_controller_test.dart
git commit -m "refactor: keep music controller local only"
```

Expected: commit succeeds with controller and controller test updates.

### Task 3: Remove AI And Pro Search UI

**Files:**
- Modify: `lib/screens/search_screen.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Simplify the search header**

In `SearchScreen.build`, replace the right-side `GlassPill` that switches between `AI Search` and `On Device` with:

```dart
const GlassPill(label: '本地搜索'),
```

Replace the fourth stats pill:

```dart
GlassPill(
  label: controller.hasPro
      ? 'Pro AI'
      : '${controller.aiSearchTrialsRemaining} AI tries left',
),
```

with:

```dart
GlassPill(label: '离线可用'),
```

- [ ] **Step 2: Remove AI branches from the search body**

Delete this block:

```dart
if (controller.searchMode == SearchMode.ai) ...[
  _AiSearchStateCard(controller: controller),
  const SizedBox(height: 24),
],
```

Replace `Top Result`, `Tracks`, and `Collections` ternaries so they always use standard local data:

```dart
SectionCard(
  title: 'Top Result',
  child: _TopResultCard(track: topTrack),
)
```

```dart
SectionCard(
  title: hasQuery ? 'Tracks' : 'Recent Tracks',
  child: activeTracks.isEmpty
      ? const _SearchPlaceholder(message: 'No matching tracks were found.')
      : ...
)
```

```dart
final collections = controller.searchCollectionResults;
```

Then render `collections` in the existing collection wrap.

- [ ] **Step 3: Simplify `_SearchHero`**

Replace the title expression with:

```dart
Text(
  hasQuery ? '本地结果' : '搜索本地音乐',
  style: Theme.of(context).textTheme.titleLarge,
),
```

Delete the `Wrap` that iterates through `SearchMode.values`.

Replace the hint text with:

```dart
hintText: '搜索歌曲、歌手、专辑、文件夹或格式',
```

Replace the wide/mobile hint section with one or two local-only hints:

```dart
_SearchHeroHint(
  icon: Icons.library_music_rounded,
  label: '搜索只读取本机音乐资料库，离线也能立即使用。',
),
```

and, where a second hint is needed:

```dart
_SearchHeroHint(
  icon: Icons.history_rounded,
  label: '最近搜索会保存在本机，方便继续找歌。',
),
```

- [ ] **Step 4: Delete `_AiSearchStateCard`**

Remove the entire `_AiSearchStateCard` widget class from `lib/screens/search_screen.dart`.

- [ ] **Step 5: Run search-related widget tests**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: widget tests pass or fail only on labels that need updating from old English/Chinese strings to the new local-only strings.

- [ ] **Step 6: Commit search UI cleanup**

Run:

```bash
git add lib/screens/search_screen.dart test/widget_test.dart
git commit -m "refactor: make search on-device only"
```

Expected: commit succeeds with search UI and widget test updates.

### Task 4: Convert Profile Settings To Local Library Settings

**Files:**
- Modify: `lib/screens/app_details_sheet.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Remove user and sync state reads**

At the top of `build`, remove:

```dart
final user = controller.userProfile;
final syncState = controller.syncState;
```

The sheet should only use local controller data such as imported count, album count, artist count, playback history, recent searches, and import support.

- [ ] **Step 2: Rename the sheet**

Replace:

```dart
'Profile & Settings'
```

with:

```dart
'本地音乐设置'
```

Replace the subtitle with:

```dart
'管理本机导入、播放记录、最近搜索和本地资料库。'
```

- [ ] **Step 3: Replace the profile card with local library summary**

Replace the profile card body with local-only content:

```dart
child: Row(
  children: [
    Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            LiquidPalette.aqua.withValues(alpha: 0.92),
            LiquidPalette.mint.withValues(alpha: 0.70),
          ],
        ),
      ),
      child: const Icon(
        Icons.library_music_rounded,
        color: LiquidPalette.ink,
      ),
    ),
    const SizedBox(width: 14),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本地资料库', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '所有歌曲、收藏和播放记录都保存在这台设备上。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GlassPill(label: '${controller.importedTrackCount} 首歌曲'),
              GlassPill(label: '${controller.albumCount} 张专辑'),
              GlassPill(label: '${controller.playbackHistoryCount} 条记录'),
            ],
          ),
        ],
      ),
    ),
  ],
),
```

- [ ] **Step 4: Replace membership and sync actions**

Replace the `Membership & Sync` section title with:

```dart
'导入'
```

Replace the sign-in, Pro, and sync `_ActionTile`s with:

```dart
_ActionTile(
  icon: Icons.audio_file_rounded,
  label: '导入音频文件',
  onTap: controller.importLocalFiles,
),
if (controller.supportsDirectoryImport)
  _ActionTile(
    icon: Icons.folder_rounded,
    label: '导入文件夹',
    onTap: controller.importLocalFolder,
  ),
```

- [ ] **Step 5: Replace AI/cloud details**

Replace `_DetailsSection(title: 'AI & Cloud Boundaries', ...)` with:

```dart
const _DetailsSection(
  title: '本地优先',
  body:
      'ChiMusic 不需要账号。导入的音乐、喜欢、收藏、最近搜索和播放记录都保存在本机。',
),
```

Replace session controls helper copy:

```dart
'These actions manage only the app session and synced metadata. They never delete the original files on disk.'
```

with:

```dart
'这些操作只清理 ChiMusic 内的本地记录，不会删除设备上的原始音频文件。'
```

Replace reset dialog content:

```dart
'This removes imported tracks, likes, saved collections, AI suggestions, and recent searches from ChiMusic. Original audio files on your device will not be deleted.'
```

with:

```dart
'这会清除 ChiMusic 内的导入歌曲、喜欢、收藏、播放记录和最近搜索。设备上的原始音频文件不会被删除。'
```

- [ ] **Step 6: Run widget tests**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: widget tests pass, including forbidden-copy checks.

- [ ] **Step 7: Commit settings cleanup**

Run:

```bash
git add lib/screens/app_details_sheet.dart test/widget_test.dart
git commit -m "refactor: replace profile sheet with local settings"
```

Expected: commit succeeds with settings and widget test updates.

### Task 5: Clean Home And Library Local Discovery Surfaces

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/library_screen.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Replace the home membership metric**

In `_HomeHeader`, replace the fourth `MetricGlassCard` that uses `controller.membershipTier`, `controller.syncState`, and `controller.hasPro` with a local metric:

```dart
MetricGlassCard(
  value: '${controller.albumCount}',
  label: 'Albums',
  icon: Icons.album_rounded,
  onTap: () => controller.openLibraryFilter(LibraryFilter.albums),
  accent: const [Color(0xFF4B1212), Color(0xFFE53935)],
),
```

- [ ] **Step 2: Remove membership status rail from home content**

In `_HomeContent`, remove:

```dart
if (!controller.isSignedIn || controller.shouldShowAiUpsell) ...[
  _MembershipStatusRail(controller: controller),
  const SizedBox(height: 30),
],
```

Then delete `_MembershipStatusRail` and `_StatusCallout` classes from `home_screen.dart`.

- [ ] **Step 3: Replace cloud sync insight**

In `_SessionInsightCard`, replace:

```dart
_InsightRow(
  label: 'Cloud sync',
  value: controller.syncState.message,
  icon: Icons.sync_rounded,
),
```

with:

```dart
_InsightRow(
  label: 'Local storage',
  value: 'History, likes, saved collections, and queue state stay on this device.',
  icon: Icons.storage_rounded,
),
```

- [ ] **Step 4: Remove library membership/sync pills**

In `_LibraryContextCard`, replace this `Wrap`:

```dart
Wrap(
  spacing: 10,
  runSpacing: 10,
  children: [
    GlassPill(label: controller.membershipTier.label),
    GlassPill(label: controller.syncState.phase.name),
    if (controller.syncState.lastSyncedAt != null)
      GlassPill(
        label:
            'Updated ${formatRelativePlayTime(controller.syncState.lastSyncedAt!)}',
      ),
  ],
),
```

with:

```dart
Wrap(
  spacing: 10,
  runSpacing: 10,
  children: [
    GlassPill(label: '${controller.favoriteTracks.length} liked'),
    GlassPill(label: '${controller.savedCollectionCount} saved'),
    GlassPill(label: '${controller.recentSearches.length} searches'),
  ],
),
```

- [ ] **Step 5: Run widget tests**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: widget tests pass. Update old text expectations such as `最近添加`, `音乐库`, or empty-state labels only if the implementation changed them intentionally.

- [ ] **Step 6: Commit home/library cleanup**

Run:

```bash
git add lib/screens/home_screen.dart lib/screens/library_screen.dart test/widget_test.dart
git commit -m "refactor: focus home and library on local music"
```

Expected: commit succeeds with home/library and test updates.

### Task 6: Sweep Remaining Visible AI Cloud Account Copy

**Files:**
- Modify as needed: `lib/screens/collection_detail_page.dart`
- Modify as needed: `lib/widgets/mobile_player_shell.dart`
- Modify as needed: `lib/widgets/macos_player_shell.dart`
- Modify as needed: `lib/services/recommendation_service.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Search for remaining visible forbidden terms**

Run:

```bash
rg "Sign In|Sign Out|sign-in|cloud sync|Cloud sync|Sync Library|Syncing|Synced|Membership|Pro|Upgrade|AI search|AI Search|AI tries|Unlock Pro|comments|follows|social feed" lib test
```

Expected: hits may remain in test forbidden lists and storage/service internals, but no visible UI copy should remain in `lib/screens` or `lib/widgets`.

- [ ] **Step 2: Fix collection detail smart playlist copy**

In `lib/screens/collection_detail_page.dart`, replace:

```dart
'This smart playlist is generated from your local library signals. Save it, play it as one queue, or jump into AI Search with the title prefilled.'
```

with:

```dart
'This smart playlist is generated from local library signals. Save it or play it as one queue.'
```

- [ ] **Step 3: Fix shell profile/account labels if present**

If `lib/widgets/mobile_player_shell.dart` contains a visible `Profile` label, replace it with:

```dart
'设置'
```

or:

```dart
'本地设置'
```

depending on the surrounding navigation density.

If `lib/widgets/macos_player_shell.dart` contains visible account/cloud labels, replace them with local actions:

```dart
'本地设置'
'导入音乐'
'播放记录'
```

Keep icons as local library/settings/import icons, not person/cloud icons.

- [ ] **Step 4: Adjust recommendation service visible text**

If `RecommendationCard` values from `lib/services/recommendation_service.dart` appear in the UI, replace:

```dart
callToActionLabel: 'Open AI Search',
subtitle: 'AI stitched from one strong cluster',
```

with:

```dart
callToActionLabel: 'Open Local Mix',
subtitle: 'Built from one strong local cluster',
```

- [ ] **Step 5: Run the forbidden-copy scan again**

Run:

```bash
rg "Sign In|Sign Out|sign-in|cloud sync|Cloud sync|Sync Library|Syncing|Synced|Membership|Pro|Upgrade|AI search|AI Search|AI tries|Unlock Pro|comments|follows|social feed" lib/screens lib/widgets lib/services
```

Expected: no visible UI copy remains. Service/model internals that are not shown to users may be deferred only if widget tests still prove the terms are absent from primary shells.

- [ ] **Step 6: Run widget tests**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: widget tests pass.

- [ ] **Step 7: Commit copy sweep**

Run:

```bash
git add lib/screens/collection_detail_page.dart lib/widgets/mobile_player_shell.dart lib/widgets/macos_player_shell.dart lib/services/recommendation_service.dart test/widget_test.dart
git commit -m "refactor: remove remote feature copy from visible surfaces"
```

Expected: commit succeeds. If one of those files was not changed, omit it from `git add`.

### Task 7: Full Verification And Plan Closeout

**Files:**
- Modify if needed: any file touched by analyzer/test fixes
- Inspect: `docs/superpowers/specs/2026-07-04-local-netease-music-design.md`

- [ ] **Step 1: Format changed Dart files**

Run:

```bash
dart format lib test
```

Expected: formatter completes successfully.

- [ ] **Step 2: Analyze**

Run:

```bash
flutter analyze
```

Expected: no analyzer errors. If analyzer reports unused private classes or imports created by the cleanup, remove them and rerun `dart format lib test`.

- [ ] **Step 3: Run all tests**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Run final visible-copy scans**

Run:

```bash
rg "Sign In|Sign Out|sign-in|cloud sync|Cloud sync|Sync Library|Syncing|Synced|Membership|Pro|Upgrade|AI search|AI Search|AI tries|Unlock Pro|comments|follows|social feed" lib/screens lib/widgets
```

Expected: no matches.

Run:

```bash
rg "authService|cloudSyncService|subscriptionService|signIn\\(|syncLibraryNow\\(|upgradeToPro\\(" lib/screens lib/widgets
```

Expected: no matches in visible UI files.

- [ ] **Step 5: Review git diff**

Run:

```bash
git diff --stat
git diff -- lib/state/chimusic_controller.dart lib/screens/search_screen.dart lib/screens/app_details_sheet.dart lib/screens/home_screen.dart lib/screens/library_screen.dart test/chimusic_controller_test.dart test/widget_test.dart
```

Expected: diff shows local-only cleanup and tests. It must not include `.superpowers/` companion files or unrelated `.gitignore` conflict edits.

- [ ] **Step 6: Commit final verification fixes if needed**

If formatting/analyzer/test fixes changed files after the previous task commits, run:

```bash
git add lib test
git commit -m "test: verify local-only music experience"
```

Expected: commit succeeds if there were final fix changes. If there were no final fix changes, do not create an empty commit.

## Self-Review

- Spec coverage: the plan covers local-only boundaries, dual shell UI cleanup, search/library/player persistence, visible copy removal, error-safe local settings, and tests for forbidden account/cloud/AI surfaces.
- Gap scan: no unresolved implementation gaps are intentionally left in this plan.
- Type consistency: the plan uses existing types from the repo: `MusicAppController`, `MusicRepositorySnapshot`, `PlaybackSessionState`, `UserProfile`, `MembershipTier`, `SyncPhase`, `SearchMode`, `Track`, and current screen/widget file names.
- Scope control: deep database schema removal of user/cloud/AI fields is deferred because the approved design allows storage compatibility during the first implementation.
