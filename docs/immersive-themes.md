# ChiMusic 沉浸播放双主题

深色采用海洋封面、薄荷色进度条和歌词摘要；浅色采用米白唱片、宋体标题与聆听足迹。两者共用现有 Flutter 播放控制器与本地数据仓库。

## 使用

导入本地音频后，点击底部迷你播放器进入全屏播放。通过右上角「播放选项」切换主题，或在设置页切换。歌曲、队列、喜欢状态和播放进度在切换时保持不变。历史记录中的歌曲从其保存位置继续播放。

播放选项还包含队列、歌词、音量、随机播放和循环播放。没有歌词时显示空状态，不生成虚构歌词。真实歌曲封面优先于内置默认封面。

## 保存

沿用现有本地持久化机制，保存主题、播放记录、队列和进度。后台生命周期会刷新当前会话；历史页的歌曲操作已改为续播。数据保存在本机，不代表云同步。

## 预览

`tool/preview.dart` 是独立交互预览入口，使用演示歌曲且禁用实际音频；不会写入生产音乐库。正式应用入口仍为 `lib/main.dart`。

```sh
flutter build web -t tool/preview.dart --no-web-resources-cdn
python3 -m http.server 4173 --bind 127.0.0.1 --directory build/web
```

默认展示深色；使用 `?theme=light` 打开浅色示例。也可以直接通过播放选项切换。

## 验证记录

- 完整测试集：44 项通过。
- 最终窄屏间距修正后的专项测试：3 项通过，包含 320×568、1.6 倍字号、长歌曲名、主题切换、进度拖动、历史续播与重启恢复。
- iOS 模拟器构建已通过；未进行真实设备音频、签名或上架验证。
- Android 构建被本机 Gradle 8.14 下载不完整阻断：`ZipException: zip END header not found`。未生成 APK，需恢复完整 Gradle 分发包后重试。

## 素材

`assets/images/immersive_ocean.png`、`immersive_vinyl.png` 和 `immersive_wind.png` 使用内置 ImageGen 生成。分别为无字深海摄影封面、透明背景黑胶唱片与日落草穗摄影。未将整张设计稿作为应用界面。

浅色标题使用 Noto Serif SC 字体子集；许可证为 `assets/fonts/OFL-NotoSerifSC.txt`，子集外的字符使用系统字体回退。
