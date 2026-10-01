import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class NeteaseNetworkException implements Exception {
  const NeteaseNetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NeteaseHttpResponse {
  const NeteaseHttpResponse(this.status, this.body, {this.cookies = const []});
  final int status;
  final String body;
  final List<Cookie> cookies;
}

typedef NeteaseHttpSender =
    Future<NeteaseHttpResponse> Function(
      Uri uri,
      Map<String, String> headers,
      String body,
    );

/// Native HTTPS protocol adapter. No proxy, remote QR renderer or API gateway.
class NeteaseClient {
  NeteaseClient({NeteaseHttpSender? send}) : _send = send ?? _post;
  final NeteaseHttpSender _send;
  static const host = 'interfacepc.music.163.com';
  static final _key = Uint8List.fromList(utf8.encode('e82ckenh8dichen8'));
  final String _deviceId = List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String encrypt(String apiPath, Map<String, dynamic> payload) {
    final json = jsonEncode(payload);
    final digest = md5.convert(
      utf8.encode('nobody${apiPath}use${json}md5forencrypt'),
    );
    final data = utf8.encode('$apiPath-36cd479b6b5-$json-36cd479b6b5-$digest');
    final padding = 16 - data.length % 16;
    final bytes = Uint8List.fromList([
      ...data,
      ...List.filled(padding, padding),
    ]);
    final cipher = ECBBlockCipher(AESEngine())..init(true, KeyParameter(_key));
    final output = Uint8List(bytes.length);
    for (var offset = 0; offset < bytes.length; offset += 16) {
      cipher.processBlock(bytes, offset, output, offset);
    }
    return output
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  static Map<String, String> parseCookies(String value) {
    final result = <String, String>{};
    for (final part in value.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final name = part.substring(0, index).trim();
      if ([
        'MUSIC_U',
        'MUSIC_A',
        '__csrf',
        'NMTID',
        '__remember_me',
      ].contains(name)) {
        final cookie = part.substring(index + 1).trim();
        if (!cookie.contains(RegExp(r'[\r\n]'))) result[name] = cookie;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> call(
    Uri uri,
    Map<String, dynamic> values,
  ) async {
    if (uri.scheme != 'https' ||
        uri.host != host ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('/api/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const NeteaseNetworkException('网易云请求地址无效。');
    }
    final cookies = parseCookies(values['cookie'] as String? ?? '');
    final header = <String, String>{
      'os': 'pc',
      'appver': '3.1.17.204416',
      'osver': 'Microsoft-Windows-10-Professional-build-19045-64bit',
      'deviceId': _deviceId,
      'channel': 'netease',
      'versioncode': '140',
      'resolution': '1920x1080',
      '__csrf': cookies['__csrf'] ?? '',
      'requestId':
          '${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(1000)}',
      ...cookies,
    };
    final payload = {...values}..remove('cookie');
    payload.addAll({'e_r': false, 'header': header});
    final response = await _send(
      uri.replace(path: uri.path.replaceFirst('/api/', '/eapi/')),
      {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': 'https://music.163.com/',
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36',
        'Cookie': header.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('; '),
      },
      'params=${encrypt(uri.path, payload)}',
    ).timeout(const Duration(seconds: 20));
    if (response.status != 200) {
      throw const NeteaseNetworkException('暂时无法连接网易云音乐，请稍后重试。');
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    for (final cookie in response.cookies) {
      final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');
      if (domain != null &&
          domain != 'music.163.com' &&
          domain != host &&
          domain != '163.com') {
        continue;
      }
      if (cookie.maxAge == 0 ||
          (cookie.expires?.isBefore(DateTime.now()) ?? false)) {
        cookies.remove(cookie.name);
      } else {
        cookies.addAll(parseCookies('${cookie.name}=${cookie.value}'));
      }
    }
    // Preserve only name/value pairs, never Set-Cookie attributes.
    return {
      ...result,
      'cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
    };
  }

  static Future<NeteaseHttpResponse> _post(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      return await (() async {
        final request = await client.postUrl(uri);
        request.followRedirects = false;
        headers.forEach(request.headers.set);
        request.write(body);
        final response = await request.close();
        final text = await response.transform(utf8.decoder).join();
        return NeteaseHttpResponse(
          response.statusCode,
          text,
          cookies: response.cookies,
        );
      })().timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }
}
