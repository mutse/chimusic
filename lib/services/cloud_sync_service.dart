import '../data/music_session_store.dart';
import '../models/music_models.dart';

abstract class CloudSyncService {
  Future<MusicCloudSnapshot?> restoreSnapshot(UserProfile user);

  Future<SyncState> syncSnapshot(UserProfile user, MusicCloudSnapshot snapshot);
}

class MockCloudSyncService implements CloudSyncService {
  MockCloudSyncService({MusicCloudSnapshotStore? store})
    : _store = store ?? SharedPreferencesCloudSnapshotStore();

  final MusicCloudSnapshotStore _store;

  @override
  Future<MusicCloudSnapshot?> restoreSnapshot(UserProfile user) {
    return _store.load(user.id);
  }

  @override
  Future<SyncState> syncSnapshot(
    UserProfile user,
    MusicCloudSnapshot snapshot,
  ) async {
    final syncedSnapshot = MusicCloudSnapshot(
      userId: snapshot.userId,
      tracks: snapshot.tracks,
      playbackHistory: snapshot.playbackHistory,
      likedTrackIds: snapshot.likedTrackIds,
      savedCollectionIds: snapshot.savedCollectionIds,
      recentTrackIds: snapshot.recentTrackIds,
      recentSearches: snapshot.recentSearches,
      queueTrackIds: snapshot.queueTrackIds,
      currentTrackId: snapshot.currentTrackId,
      currentCollectionId: snapshot.currentCollectionId,
      positionMs: snapshot.positionMs,
      syncedAt: DateTime.now(),
    );
    await _store.save(syncedSnapshot);
    return SyncState(
      phase: SyncPhase.synced,
      message: 'Library synced to your ChiMusic cloud snapshot.',
      lastSyncedAt: syncedSnapshot.syncedAt,
    );
  }
}
