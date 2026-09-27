import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/chimusic_controller.dart';
import '../services/netease_service.dart';

/// Shared account controls in both desktop and mobile settings.
class NeteaseAccountPanel extends StatefulWidget {
  const NeteaseAccountPanel({super.key, required this.controller});
  final MusicAppController controller;

  @override
  State<NeteaseAccountPanel> createState() => _NeteaseAccountPanelState();
}

class _NeteaseAccountPanelState extends State<NeteaseAccountPanel> {
  String? _error;
  NeteaseService get service => widget.controller.netease;

  @override
  void dispose() {
    service.cancelQrLogin(notify: false);
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await widget.controller.signOutNetease();
    } catch (_) {
      if (mounted) setState(() => _error = '退出时无法清理登录凭证，请重试。');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final disabled = service.busy || service.syncing;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_queue_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '网易云音乐',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (service.isSignedIn)
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  service.isSignedIn
                      ? '已登录 · ${service.nickname}'
                      : '登录后可同步喜欢的歌曲、创建和收藏的歌单，并在线播放。',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!service.isSignedIn)
                      FilledButton.icon(
                        onPressed: disabled ? null : service.startQrLogin,
                        icon: const Icon(Icons.qr_code),
                        label: Text(service.hasQr ? '刷新二维码' : '扫码登录'),
                      ),
                    if (service.hasQr)
                      TextButton(
                        onPressed: service.cancelQrLogin,
                        child: const Text('取消登录'),
                      ),
                    if (service.isSignedIn) ...[
                      FilledButton.icon(
                        onPressed: disabled
                            ? null
                            : widget.controller.syncNeteaseLibrary,
                        icon: const Icon(Icons.sync),
                        label: Text(service.syncing ? '同步中…' : '同步音乐'),
                      ),
                      TextButton(
                        onPressed: disabled ? null : _signOut,
                        child: const Text('退出登录'),
                      ),
                    ],
                  ],
                ),
                if (service.qrUrl case final qrUrl?) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Semantics(
                      label: '网易云登录二维码，请用网易云音乐 App 扫码',
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: qrUrl,
                          size: 190,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
                if (disabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_error ?? service.message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(message),
                  ),
                if (service.lastSyncedAt case final date?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '上次同步：${date.toLocal().toString().split('.').first}',
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '同步为网易云 → 本机；本机收藏修改不会上传。播放取决于账号权限和歌曲版权。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
