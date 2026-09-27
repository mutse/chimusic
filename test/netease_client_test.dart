import 'dart:io';

import 'package:chimusic/services/netease_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EAPI matches independent OpenSSL AES-128-ECB vector', () {
    expect(
      NeteaseClient.encrypt('/api/login/qrcode/unikey', {'type': 3}),
      '1CA81A97B7BAEB099F29A9B99A25CD6E58E7BA5B35F25231033065C776830C0A38A128CF8B3EAF44635E50E0B9800A4A037CBDA1E04BD460C02768E3ECD5E66E905A5BCAE52009FB0933EFB373A62E834048DEBDABCCC627F25820A8D94E0A8C',
    );
  });

  test(
    'credentials are never sent to configurable hosts or redirects',
    () async {
      var sent = false;
      final client = NeteaseClient(
        send: (_, _, _) async {
          sent = true;
          return const NeteaseHttpResponse(302, '{}');
        },
      );
      for (final url in [
        'https://example.com/api/login',
        'http://interfacepc.music.163.com/api/login',
        'https://interfacepc.music.163.com.evil.com/api/login',
        'https://user:pass@interfacepc.music.163.com/api/login',
        'https://interfacepc.music.163.com/api/login?cookie=secret',
      ]) {
        await expectLater(
          client.call(Uri.parse(url), {'cookie': 'MUSIC_U=secret'}),
          throwsA(isA<NeteaseNetworkException>()),
        );
      }
      expect(sent, false);
      await expectLater(
        client.call(Uri.https(NeteaseClient.host, '/api/login'), {}),
        throwsA(isA<NeteaseNetworkException>()),
      );
      expect(sent, true);
    },
  );

  test(
    'uses encrypted form POST and captures only official response cookie values',
    () async {
      final client = NeteaseClient(
        send: (uri, headers, body) async {
          expect(
            uri.toString(),
            'https://interfacepc.music.163.com/eapi/login/qrcode/client/login',
          );
          expect(headers['Content-Type'], 'application/x-www-form-urlencoded');
          expect(headers['Cookie'], contains('__csrf=token'));
          expect(body, startsWith('params='));
          expect(body, isNot(contains('secret')));
          expect(body, isNot(contains('qr-key')));
          return NeteaseHttpResponse(
            200,
            '{"code":803}',
            cookies: [
              Cookie('MUSIC_U', 'authenticated')..domain = '.music.163.com',
              Cookie('__csrf', 'newtoken')..domain = '.music.163.com',
              Cookie('MUSIC_A', 'old')..maxAge = 0,
              Cookie('MUSIC_U', 'evil')..domain = 'evil.example',
            ],
          );
        },
      );
      final result = await client.call(
        Uri.https(NeteaseClient.host, '/api/login/qrcode/client/login'),
        {
          'key': 'qr-key',
          'cookie':
              'MUSIC_U=secret; __csrf=token; MUSIC_A=old; Path=/; HttpOnly',
        },
      );
      expect(result['code'], 803);
      expect(result['cookie'], contains('MUSIC_U=authenticated'));
      expect(result['cookie'], contains('__csrf=newtoken'));
      expect(result['cookie'], isNot(contains('evil')));
      expect(result['cookie'], isNot(contains('Path')));
      expect(result['cookie'], isNot(contains('MUSIC_A')));
    },
  );
}
