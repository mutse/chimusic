import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_models.dart';
import 'netease_client.dart';

typedef NeteaseTransport =
    Future<Map<String, dynamic>> Function(
      Uri endpoint,
      Map<String, dynamic> body,
    );

class NeteaseException implements Exception {
  const NeteaseException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class NeteaseCredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureNeteaseCredentialStore implements NeteaseCredentialStore {
  static const _key = 'chimusic.netease.session.v1';
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Session and library state for direct NetEase login, sync and playback.
class NeteaseService extends ChangeNotifier {
  NeteaseService({
    NeteaseTransport? transport,
    NeteaseCredentialStore? credentials,
  }) : _transport = transport ?? NeteaseClient().call,
       _credentials = credentials ?? SecureNeteaseCredentialStore();

  final NeteaseTransport _transport;
  final NeteaseCredentialStore _credentials;
  Future<void> _credentialOperations = Future<void>.value();

  Future<T> _mutateCredentials<T>(Future<T> Function() action) {
    final operation = _credentialOperations.then((_) => action());
    _credentialOperations = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  static const _provider = 'netease-direct';
  static const _cacheKey = 'chimusic.netease.library.v1';
  String? _cookie;
  String? userId;
  String? nickname;
  String? message;
  String? qrUrl;
  String? _qrKey;
  Timer? _pollTimer;
  int _generation = 0;
  bool _disposed = false;
  bool busy = false;
  bool syncing = false;
  DateTime? lastSyncedAt;
  List<Track> tracks = [];
  List<MusicCollection> playlists = [];
  Set<String> likedIds = {};
  bool get isSignedIn => userId != null && _cookie != null;
  bool get hasQr => _qrKey != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || generation != _generation) return;
      await prefs.remove('chimusic.netease.endpoint.v1');
      final stored = await _credentials.read();
      if (_disposed || generation != _generation) return;
      if (stored != null) {
        final data = jsonDecode(stored) as Map<String, dynamic>;
        if (data['provider'] == _provider) {
          _cookie = data['cookie'] as String?;
          userId = data['userId'] as String?;
          nickname = data['nickname'] as String?;
        } else {
          await _mutateCredentials(() async {
            if (generation == _generation) await _credentials.clear();
          });
          if (generation != _generation) return;
          await prefs.remove(_cacheKey);
        }
      }
      final cache = prefs.getString(_cacheKey);
      if (cache != null && isSignedIn) {
        final data = jsonDecode(cache) as Map<String, dynamic>;
        if (data['userId'] == userId && data['provider'] == _provider) {
          _applyLibrary(data);
        }
      }
    } catch (_) {
      message = '无法恢复网易云会话，请重新登录。';
    }
    _notify();
  }

  Future<Map<String, dynamic>> _call(
    String route, [
    Map<String, dynamic> values = const {},
  ]) async {
    if (_disposed) throw const NeteaseException('会话已关闭。');
    final uri = Uri.https(NeteaseClient.host, route);
    final result = await _transport(uri, {
      ...values,
      'cookie': ?_cookie,
    }).timeout(const Duration(seconds: 20));
    final code = result['code'];
    if (code == 301 || code == 401) {
      throw const NeteaseException('网易云登录已过期，请退出后重新扫码登录。');
    }
    if (code != null &&
        code != 200 &&
        !(route == '/api/login/qrcode/client/login' &&
            [800, 801, 802, 803].contains(code))) {
      throw const NeteaseException('网易云接口请求失败，请稍后重试。');
    }
    return result;
  }

  Future<void> startQrLogin() async {
    if (busy || syncing) return;
    _generation++;
    cancelQrLogin();
    final generation = _generation;
    busy = true;
    message = '正在生成二维码…';
    _notify();
    try {
      final keyResponse = await _call('/api/login/qrcode/unikey', {'type': 3});
      if (generation != _generation) return;
      final key = keyResponse['unikey'] as String;
      _cookie = keyResponse['cookie'] as String?;
      qrUrl = Uri.https('music.163.com', '/login', {'codekey': key}).toString();
      _qrKey = key;
      message = '请用网易云音乐 App 扫码，并在手机上确认登录。';
      _schedulePoll(generation);
    } catch (error) {
      if (generation == _generation) message = _errorMessage(error);
    } finally {
      if (generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  void _schedulePoll(int generation) {
    _pollTimer = Timer(const Duration(seconds: 3), () async {
      if (generation != _generation || _disposed) return;
      await checkQrLogin();
      if (generation == _generation && hasQr && !_disposed) {
        _schedulePoll(generation);
      }
    });
  }

  Future<void> checkQrLogin() async {
    final key = _qrKey;
    if (key == null) return;
    final generation = _generation;
    try {
      final result = await _call('/api/login/qrcode/client/login', {
        'key': key,
        'type': 3,
      });
      if (generation != _generation) return;
      switch (result['code']) {
        case 800:
          cancelQrLogin();
          message = '二维码已过期，请刷新二维码。';
        case 801:
          message = '等待网易云音乐 App 扫码…';
        case 802:
          message = '已扫码，请在手机上确认。';
        case 803:
          final cookie = result['cookie'] as String?;
          if (cookie == null ||
              !NeteaseClient.parseCookies(cookie).containsKey('MUSIC_U')) {
            throw const NeteaseException('未取得登录凭证，请重试。');
          }
          // Resolve the profile using the new credential without exposing it.
          _cookie = cookie;
          final status = await _call('/api/w/nuser/account/get');
          if (generation != _generation) return;
          final profile = status['profile'] as Map?;
          if (profile?['userId'] == null) {
            throw const NeteaseException('未取得用户信息，请重新扫码。');
          }
          final id = '${profile!['userId']}';
          final name = profile['nickname'] as String? ?? '网易云用户';
          await _mutateCredentials(() async {
            if (generation != _generation) return;
            await _credentials.write(
              jsonEncode({
                'provider': _provider,
                'cookie': cookie,
                'userId': id,
                'nickname': name,
              }),
            );
            if (generation != _generation) {
              // Cleanup is in the same serialized operation, before any newer write.
              await _credentials.clear();
              return;
            }
            userId = id;
            nickname = name;
            cancelQrLogin();
            message = '登录成功，点击“同步音乐”导入歌单和喜欢的歌曲。';
          });
      }
    } catch (error) {
      if (generation == _generation) {
        if (userId == null) _cookie = null;
        cancelQrLogin();
        message = _errorMessage(error);
      }
    }
    _notify();
  }

  void cancelQrLogin({bool notify = true}) {
    if (!hasQr && !busy) return;
    _generation++;
    _pollTimer?.cancel();
    _qrKey = null;
    qrUrl = null;
    busy = false;
    if (!isSignedIn) _cookie = null;
    if (notify) _notify();
  }

  Future<void> signOut() async {
    _generation++;
    cancelQrLogin();
    await _mutateCredentials(_credentials.clear);
    _cookie = null;
    userId = null;
    nickname = null;
    tracks = [];
    playlists = [];
    likedIds = {};
    lastSyncedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    message = '已退出网易云音乐。';
    _notify();
  }

  /// Build a complete snapshot first: failed pages never replace a good cache.
  Future<bool> syncLibrary() async {
    if (syncing || !isSignedIn) return false;
    syncing = true;
    final generation = _generation;
    message = '正在同步喜欢的歌曲和歌单…';
    _notify();
    try {
      final liked = await _call('/api/song/like/get', {'uid': userId});
      final ids = (liked['ids'] as List).map((id) => '$id').toSet();
      final playlistData = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 100) {
        final page = await _call('/api/user/playlist', {
          'uid': userId,
          'limit': 100,
          'offset': offset,
          'includeVideo': true,
        });
        final list = (page['playlist'] as List).cast<Map<String, dynamic>>();
        for (final item in list) {
          final detail = await _call('/api/v6/playlist/detail', {
            'id': item['id'],
            'n': 100000,
            's': 8,
          });
          final data = detail['playlist'] as Map<String, dynamic>;
          final trackIds = (data['trackIds'] as List)
              .map((t) => '${(t as Map)['id']}')
              .toList();
          ids.addAll(trackIds);
          playlistData.add({
            'id': '${item['id']}',
            'name': item['name'],
            'coverImgUrl': item['coverImgUrl'],
            'trackIds': trackIds,
          });
        }
        if (page['more'] != true) break;
        if (list.isEmpty) throw const NeteaseException('歌单分页不完整，请重新同步。');
      }
      final songs = <Map<String, dynamic>>[];
      final allIds = ids.toList();
      for (var start = 0; start < allIds.length; start += 300) {
        final batch = allIds
            .skip(start)
            .take(300)
            .map((id) => {'id': int.parse(id)})
            .toList();
        final detail = await _call('/api/v3/song/detail', {
          'c': jsonEncode(batch),
        });
        songs.addAll((detail['songs'] as List).cast<Map<String, dynamic>>());
      }
      if (generation != _generation) return false;
      final snapshot = <String, dynamic>{
        'userId': userId,
        'provider': _provider,
        'syncedAt': DateTime.now().toIso8601String(),
        'songs': songs,
        'playlists': playlistData,
        'likedIds': liked['ids'],
      };
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return false;
      await prefs.setString(_cacheKey, jsonEncode(snapshot));
      if (generation != _generation) return false;
      _applyLibrary(snapshot);
      message = '已同步 ${playlists.length} 个歌单、${tracks.length} 首歌曲。';
      return true;
    } catch (error) {
      if (generation == _generation) message = _errorMessage(error);
      return false;
    } finally {
      syncing = false;
      _notify();
    }
  }

  void _applyLibrary(Map<String, dynamic> snapshot) {
    lastSyncedAt = DateTime.parse(snapshot['syncedAt'] as String);
    tracks = (snapshot['songs'] as List)
        .map((s) => songToTrack(s as Map<String, dynamic>, lastSyncedAt!))
        .toList();
    final byId = {for (final t in tracks) t.id: t};
    likedIds = (snapshot['likedIds'] as List)
        .map((id) => 'netease:$id')
        .toSet();
    playlists = (snapshot['playlists'] as List).map((value) {
      final p = value as Map;
      final members = (p['trackIds'] as List)
          .map((id) => byId['netease:$id'])
          .whereType<Track>()
          .toList();
      return MusicCollection(
        id: 'netease:playlist:${p['id']}',
        title: p['name'] as String? ?? '网易云歌单',
        subtitle: '网易云音乐 · ${members.length} 首',
        description: '从网易云音乐同步',
        kind: MusicCollectionKind.playlist,
        palette: _palette,
        tracks: members,
        artworkUri: _https(p['coverImgUrl'] as String?),
      );
    }).toList();
  }

  Future<Uri> resolveStream(Track track) async {
    if (!isSignedIn) throw const NeteaseException('请先登录网易云音乐。');
    final result = await _call('/api/song/enhance/player/url/v1', {
      'ids': jsonEncode([int.parse(track.id.substring('netease:'.length))]),
      'encodeType': 'flac',
      'level': 'standard',
    });
    final data = (result['data'] as List?)?.whereType<Map>().firstOrNull;
    final url = data?['url'] as String?;
    if (url == null || url.isEmpty || data?['freeTrialInfo'] != null) {
      throw const NeteaseException('当前账号无法完整播放这首歌，可能需要会员或暂无版权。');
    }
    final uri = Uri.tryParse(_https(url)!);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const NeteaseException('播放地址无效，请重试。');
    }
    return uri;
  }

  static const _palette = <Color>[
    Color(0xFFE85D67),
    Color(0xFF71354B),
    Color(0xFF171D28),
  ];
  static Track songToTrack(Map<String, dynamic> song, DateTime syncedAt) {
    final album = song['al'] as Map? ?? {};
    final id = '${song['id']}';
    return Track(
      id: 'netease:$id',
      filePath: 'netease://song/$id',
      fileName: song['name'] as String? ?? id,
      folderPath: 'netease://library',
      title: song['name'] as String? ?? '未知歌曲',
      artist: (song['ar'] as List? ?? [])
          .map((a) => (a as Map)['name'])
          .whereType<String>()
          .join(' / '),
      album: album['name'] as String? ?? '未知专辑',
      palette: _palette,
      importedAt: syncedAt,
      duration: Duration(milliseconds: (song['dt'] as num?)?.toInt() ?? 0),
      artworkUri: _https(album['picUrl'] as String?),
      lastSyncedAt: syncedAt,
    );
  }

  static String? _https(String? url) =>
      url?.replaceFirst(RegExp(r'^http://'), 'https://');
  static String _errorMessage(Object error) => error is NeteaseException
      ? error.message
      : error is NeteaseNetworkException
      ? error.message
      : '连接网易云音乐失败，请检查网络后重试。';

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pollTimer?.cancel();
    super.dispose();
  }
}
