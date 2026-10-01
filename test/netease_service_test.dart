import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chimusic/models/music_models.dart';
import 'package:chimusic/state/chimusic_scope.dart';
import 'package:chimusic/widgets/netease_playlist_strip.dart';
import 'package:chimusic/screens/collection_detail_page.dart';

import 'package:chimusic/services/netease_service.dart';
import 'package:chimusic/state/chimusic_controller.dart';
import 'package:chimusic/widgets/netease_account_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' hide PlaybackEvent;
import 'package:shared_preferences/shared_preferences.dart';

class MemoryCredentials implements NeteaseCredentialStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}

class DelayedCredentials extends MemoryCredentials {
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  var writes = 0;
  @override
  Future<void> write(String value) async {
    if (++writes == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    await super.write(value);
  }
}

class Gateway {
  final calls = <({Uri uri, Map<String, dynamic> body})>[];
  int qrCode = 803;
  bool failDetails = false;
  bool trial = false;
  bool unavailable = false;
  Completer<Map<String, dynamic>>? pendingQr;
  Future<Map<String, dynamic>> call(Uri uri, Map<String, dynamic> body) async {
    calls.add((uri: uri, body: body));
    switch (uri.path) {
      case '/api/login/qrcode/unikey':
        return {'code': 200, 'unikey': 'key'};
      case '/api/login/qrcode/client/login':
        return pendingQr?.future ??
            Future.value({
              'code': qrCode,
              if (qrCode == 803) 'cookie': 'MUSIC_U=secret-cookie',
            });
      case '/api/w/nuser/account/get':
        return {
          'code': 200,
          'profile': {'userId': 42, 'nickname': '云音乐用户'},
        };
      case '/api/song/like/get':
        return {
          'code': 200,
          'ids': [1, 2],
        };
      case '/api/user/playlist':
        return {
          'code': 200,
          'more': body['offset'] == 0,
          'playlist': [
            {
              'id': body['offset'] == 0 ? 11 : 12,
              'name': '歌单',
              'coverImgUrl': 'http://p1.music.126.net/cover.jpg',
            },
          ],
        };
      case '/api/v6/playlist/detail':
        if (failDetails) throw const NeteaseException('测试网络错误');
        return {
          'code': 200,
          'playlist': {
            'trackIds': [
              {'id': 2},
              {'id': 3},
            ],
          },
        };
      case '/api/v3/song/detail':
        return {
          'code': 200,
          'songs': (jsonDecode(body['c'] as String) as List)
              .map((item) => song((item as Map)['id'] as int))
              .toList(),
        };
      case '/api/song/enhance/player/url/v1':
        return {
          'code': 200,
          'data': [
            {
              'id': (jsonDecode(body['ids'] as String) as List).first,
              'url': unavailable
                  ? null
                  : 'http://m1.music.126.net/${(jsonDecode(body['ids'] as String) as List).first}.mp3',
              if (trial) 'freeTrialInfo': {'start': 0, 'end': 30},
            },
          ],
        };
      default:
        throw StateError('Unexpected route ${uri.path}');
    }
  }
}

Map<String, dynamic> song(int id) => {
  'id': id,
  'name': '歌曲 $id',
  'ar': [
    {'name': '歌手'},
  ],
  'al': {'name': '专辑', 'picUrl': 'http://p1.music.126.net/cover.jpg'},
  'dt': 180000,
};

Future<NeteaseService> signedIn(
  Gateway gateway,
  MemoryCredentials credentials,
) async {
  final service = NeteaseService(
    transport: gateway.call,
    credentials: credentials,
  );
  await service.startQrLogin();
  await service.checkQrLogin();
  return service;
}

class FakePlayer implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  List<AudioSource> sources = [];
  @override
  LoopMode loopMode = LoopMode.off;
  @override
  bool playing = false;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    sources = audioSources;
    return const Duration(minutes: 3);
  }

  @override
  Future<void> play() async {
    playing = true;
    states.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    playing = false;
    states.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> stop() => pause();
  @override
  Future<void> setLoopMode(LoopMode mode) async {
    loopMode = mode;
  }

  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {}
  @override
  Future<void> seek(Duration? position, {int? index}) async {}
  @override
  Future<void> dispose() => states.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('QR login works without configuring an API', () async {
    final gateway = Gateway();
    final service = NeteaseService(
      transport: gateway.call,
      credentials: MemoryCredentials(),
    );
    addTearDown(service.dispose);
    await service.startQrLogin();
    expect(service.hasQr, true);
    expect(
      gateway.calls.every((c) => c.uri.host.endsWith('.music.163.com')),
      true,
    );
  });

  testWidgets('account panel offers scan login without server configuration', (
    tester,
  ) async {
    final service = NeteaseService(
      transport: Gateway().call,
      credentials: MemoryCredentials(),
    );
    final controller = MusicAppController(
      enableAudio: false,
      neteaseService: service,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NeteaseAccountPanel(controller: controller)),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '扫码登录'),
    );
    expect(button.onPressed, isNotNull);
  });

  test(
    'QR login stores credentials securely and restores a direct session',
    () async {
      final gateway = Gateway();
      final credentials = MemoryCredentials();
      final service = await signedIn(gateway, credentials);
      addTearDown(service.dispose);
      expect(service.isSignedIn, true);
      expect(service.nickname, '云音乐用户');
      expect(service.hasQr, false);
      expect(credentials.value, contains('MUSIC_U=secret-cookie'));
      expect(
        gateway.calls.every(
          (c) => !c.uri.toString().contains('MUSIC_U=secret-cookie'),
        ),
        true,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any(
          (k) => '${prefs.get(k)}'.contains('MUSIC_U=secret-cookie'),
        ),
        false,
      );
      final restored = NeteaseService(
        transport: gateway.call,
        credentials: credentials,
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.userId, '42');
      await restored.signOut();
      expect(restored.isSignedIn, false);
      expect(credentials.value, isNull);
    },
  );

  test('obsolete login cannot delete the newer saved session', () async {
    final credentials = DelayedCredentials();
    final service = NeteaseService(
      transport: Gateway().call,
      credentials: credentials,
    );
    addTearDown(service.dispose);
    await service.startQrLogin();
    final older = service.checkQrLogin();
    await credentials.firstWriteStarted.future;
    await service.startQrLogin();
    final newer = service.checkQrLogin();
    await Future<void>.delayed(Duration.zero);
    credentials.releaseFirstWrite.complete();
    await Future.wait([older, newer]);
    expect(service.isSignedIn, true);
    expect(credentials.value, isNotNull);
  });

  test('QR waiting, confirmation and expiry do not create a session', () async {
    final gateway = Gateway()..qrCode = 801;
    final service = NeteaseService(
      transport: gateway.call,
      credentials: MemoryCredentials(),
    );
    addTearDown(service.dispose);
    await service.startQrLogin();
    await service.checkQrLogin();
    expect(service.message, contains('等待'));
    gateway.qrCode = 802;
    await service.checkQrLogin();
    expect(service.message, contains('手机上确认'));
    gateway.qrCode = 800;
    await service.checkQrLogin();
    expect(service.hasQr, false);
    expect(service.isSignedIn, false);
    expect(service.message, contains('过期'));
  });

  test('cancelled QR request cannot sign user in', () async {
    final gateway = Gateway()..pendingQr = Completer();
    final credentials = MemoryCredentials();
    final service = NeteaseService(
      transport: gateway.call,
      credentials: credentials,
    );
    addTearDown(service.dispose);
    await service.startQrLogin();
    final checking = service.checkQrLogin();
    service.cancelQrLogin();
    gateway.pendingQr!.complete({
      'code': 803,
      'cookie': 'MUSIC_U=secret-cookie',
    });
    await checking;
    expect(service.isSignedIn, false);
    expect(credentials.value, isNull);
  });

  test(
    'sync paginates playlists, deduplicates songs, preserves cache on failure',
    () async {
      final gateway = Gateway();
      final credentials = MemoryCredentials();
      final service = await signedIn(gateway, credentials);
      addTearDown(service.dispose);
      expect(await service.syncLibrary(), true);
      expect(service.tracks.map((t) => t.id), [
        'netease:1',
        'netease:2',
        'netease:3',
      ]);
      expect(service.playlists.length, 2);
      expect(service.likedIds, {'netease:1', 'netease:2'});
      expect(service.tracks.first.filePath, 'netease://song/1');
      expect(service.tracks.first.artworkUri, startsWith('https://'));
      expect(
        gateway.calls
            .where((c) => c.uri.path == '/api/user/playlist')
            .map((c) => c.body['offset']),
        [0, 100],
      );
      gateway.failDetails = true;
      expect(await service.syncLibrary(), false);
      expect(service.tracks.length, 3);
      final restored = NeteaseService(
        transport: gateway.call,
        credentials: credentials,
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.playlists.length, 2);
      expect(restored.tracks.length, 3);
    },
  );

  test(
    'playback resolves fresh URLs and rejects trials and missing rights',
    () async {
      final gateway = Gateway();
      final service = await signedIn(gateway, MemoryCredentials());
      addTearDown(service.dispose);
      final track = NeteaseService.songToTrack(song(1), DateTime.now());
      expect((await service.resolveStream(track)).scheme, 'https');
      await service.resolveStream(track);
      expect(
        gateway.calls
            .where((c) => c.uri.path == '/api/song/enhance/player/url/v1')
            .length,
        2,
      );
      gateway.trial = true;
      await expectLater(
        service.resolveStream(track),
        throwsA(isA<NeteaseException>()),
      );
      gateway.trial = false;
      gateway.unavailable = true;
      await expectLater(
        service.resolveStream(track),
        throwsA(isA<NeteaseException>()),
      );
      await service.signOut();
      await expectLater(
        service.resolveStream(track),
        throwsA(isA<NeteaseException>()),
      );
    },
  );

  test(
    'controller sync is idempotent and logout preserves local music',
    () async {
      final service = await signedIn(Gateway(), MemoryCredentials());
      final local = NeteaseService.songToTrack(
        song(99),
        DateTime.now(),
      ).copyWith(id: 'local', filePath: '/tmp/local.mp3');
      final controller = MusicAppController(
        enableAudio: false,
        neteaseService: service,
        initialTracks: [local],
        initialLikedTrackIds: {'local'},
      );
      addTearDown(controller.dispose);
      await controller.syncNeteaseLibrary();
      await controller.syncNeteaseLibrary();
      expect(controller.importedTracks.length, 4);
      expect(controller.favoriteTracks.length, 3);
      expect(
        controller.playlistCollections
            .where((p) => p.id.startsWith('netease:playlist:'))
            .length,
        2,
      );
      await controller.signOutNetease();
      expect(controller.importedTracks.single.id, 'local');
      expect(controller.favoriteTracks.single.id, 'local');
    },
  );

  test(
    'online queue loads current URL only, advances, repeats and reports rights errors',
    () async {
      final gateway = Gateway();
      final service = await signedIn(gateway, MemoryCredentials());
      final player = FakePlayer();
      final controller = MusicAppController(
        player: player,
        neteaseService: service,
      );
      addTearDown(controller.dispose);
      await controller.syncNeteaseLibrary();
      await controller.playCollection(controller.allTracksCollection);
      expect(player.sources.length, 1);
      expect((player.sources.single as UriAudioSource).uri.scheme, 'https');
      expect(controller.currentTrack!.id, 'netease:1');
      expect(controller.isPlaying, true);
      await controller.skipNext();
      expect(controller.currentTrack!.id, 'netease:2');
      player.states.add(PlayerState(true, ProcessingState.completed));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.currentTrack!.id, 'netease:3');
      await controller.toggleRepeat();
      expect(player.loopMode, LoopMode.off);
      await controller.skipNext();
      expect(controller.currentTrack!.id, 'netease:1');
      gateway.unavailable = true;
      await controller.skipNext();
      expect(controller.isPlaying, false);
      expect(controller.statusMessage, contains('无法完整播放'));
      gateway.unavailable = false;
      await controller.togglePlayPause();
      expect(controller.isPlaying, true);
    },
  );

  test('completed online song can replay with a fresh URL', () async {
    final gateway = Gateway();
    final service = await signedIn(gateway, MemoryCredentials());
    final track = NeteaseService.songToTrack(song(1), DateTime.now());
    final player = FakePlayer();
    final controller = MusicAppController(
      player: player,
      neteaseService: service,
      initialTracks: [track],
    );
    addTearDown(controller.dispose);
    await controller.playTrack(track);
    player.states.add(PlayerState(true, ProcessingState.completed));
    expect(controller.isPlaying, false);
    await controller.togglePlayPause();
    expect(controller.isPlaying, true);
    expect(
      gateway.calls
          .where((c) => c.uri.path == '/api/song/enhance/player/url/v1')
          .length,
      2,
    );
  });

  test('closing account controls does not cancel an active sync', () async {
    final gateway = Gateway();
    final credentials = MemoryCredentials();
    final gate = Completer<Map<String, dynamic>>();
    final service = NeteaseService(
      credentials: credentials,
      transport: (uri, body) => uri.path == '/api/song/like/get'
          ? gate.future
          : gateway.call(uri, body),
    );
    addTearDown(service.dispose);
    await service.startQrLogin();
    await service.checkQrLogin();
    final syncing = service.syncLibrary();
    service.cancelQrLogin(notify: false);
    gate.complete({
      'code': 200,
      'ids': [1],
    });
    expect(await syncing, true);
    expect(service.tracks.length, 3);
  });

  test(
    'mixed queue keeps local file sources and resolves online songs lazily',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimusic-mixed-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('${directory.path}/local.mp3').writeAsBytes([0]);
      final gateway = Gateway();
      final service = await signedIn(gateway, MemoryCredentials());
      final online = NeteaseService.songToTrack(song(1), DateTime.now());
      final local = online.copyWith(
        id: 'local',
        filePath: file.path,
        title: 'Local',
      );
      final collection = MusicCollection(
        id: 'mixed',
        title: 'Mixed',
        subtitle: '',
        description: '',
        kind: MusicCollectionKind.playlist,
        palette: online.palette,
        tracks: [online, local],
      );
      final player = FakePlayer();
      final controller = MusicAppController(
        player: player,
        neteaseService: service,
        initialTracks: [online, local],
      );
      addTearDown(controller.dispose);
      await controller.playCollection(collection);
      expect((player.sources.single as UriAudioSource).uri.scheme, 'https');
      await controller.skipNext();
      expect(controller.currentTrack!.id, 'local');
      expect(
        (player.sources.single as UriAudioSource).uri,
        Uri.file(file.path),
      );
      await controller.skipPrevious();
      expect(controller.currentTrack!.id, online.id);
      expect(
        gateway.calls
            .where((c) => c.uri.path == '/api/song/enhance/player/url/v1')
            .length,
        2,
      );
    },
  );

  testWidgets('synced playlists can be opened from the library strip', (
    tester,
  ) async {
    final service = await signedIn(Gateway(), MemoryCredentials());
    final controller = MusicAppController(
      enableAudio: false,
      neteaseService: service,
    );
    addTearDown(controller.dispose);
    await controller.syncNeteaseLibrary();
    await tester.pumpWidget(
      ChiMusicScope(
        notifier: controller,
        child: MaterialApp(
          home: Scaffold(body: NeteasePlaylistStrip(controller: controller)),
        ),
      ),
    );
    expect(find.text('网易云歌单 · 2'), findsOneWidget);
    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();
    expect(find.byType(CollectionDetailPage), findsOneWidget);
    expect(find.text('歌曲 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account panel exposes setup and sync, closes without notification errors',
    (tester) async {
      final service = await signedIn(Gateway(), MemoryCredentials());
      final controller = MusicAppController(
        enableAudio: false,
        neteaseService: service,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NeteaseAccountPanel(controller: controller),
            ),
          ),
        ),
      );
      expect(find.text('网易云音乐'), findsOneWidget);
      expect(find.text('同步音乐'), findsOneWidget);
      await tester.tap(find.text('同步音乐'));
      await tester.pumpAndSettle();
      expect(controller.importedTracks.length, 3);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
