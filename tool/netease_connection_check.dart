// Account-free smoke check: prints statuses only, never QR keys or cookies.
import 'dart:io';
import 'package:chimusic/services/netease_client.dart';

Future<void> main() async {
  final client = NeteaseClient();
  final key = await client.call(
    Uri.https(NeteaseClient.host, '/api/login/qrcode/unikey'),
    {'type': 3},
  );
  stdout.writeln(
    'QR key status: ${key['code']}; key present: ${key['unikey'] is String}',
  );
  if (key['unikey'] is! String) throw StateError('QR key was not returned');
  final check = await client.call(
    Uri.https(NeteaseClient.host, '/api/login/qrcode/client/login'),
    {'type': 3, 'key': key['unikey'], 'cookie': key['cookie']},
  );
  stdout.writeln(
    'QR polling status: ${check['code']} (801 = waiting for scan)',
  );
  if (check['code'] != 801) throw StateError('Expected waiting-for-scan state');
  final details = await client.call(
    Uri.https(NeteaseClient.host, '/api/v3/song/detail'),
    {'c': '[{"id":33894312}]'},
  );
  stdout.writeln(
    'Song details status: ${details['code']}; songs returned: ${(details['songs'] as List?)?.length ?? 0}',
  );
  if (details['code'] != 200) throw StateError('Song details unavailable');
  final stream = await client.call(
    Uri.https(NeteaseClient.host, '/api/song/enhance/player/url/v1'),
    {'ids': '[33894312]', 'level': 'standard', 'encodeType': 'flac'},
  );
  stdout.writeln(
    'Playback API status: ${stream['code']}; response items: ${(stream['data'] as List?)?.length ?? 0}',
  );
  if (stream['code'] != 200) throw StateError('Playback endpoint unavailable');
}
