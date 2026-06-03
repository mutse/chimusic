# App Store Readiness

This repository now ships with the core mobile behaviors and native metadata
needed for a local-first music player release:

- Android package id: `app.chimusic.player`
- iOS bundle id: `app.chimusic.player`
- macOS bundle id: `app.chimusic.player.macos`
- Android foreground audio service + media button receiver
- iOS background audio mode
- iOS open-in-place file access for user-selected tracks
- Background playback metadata via `just_audio_background`

## What Still Requires Your Store Account

These items cannot be completed purely from source code in the repo:

1. Configure your final signing assets.
   iOS/TestFlight/App Store requires Apple certificates and provisioning.
   macOS distribution requires signing and notarization.
   Google Play requires your upload keystore to stay stable across releases.

2. Replace bundle ids if you need account-specific namespaces.
   `app.chimusic.player` is a clean non-template id, but you may still want to
   align it with your company or domain before first release.

3. Fill in store metadata.
   Add screenshots, promotional copy, age rating answers, support URL, and
   privacy policy URL in App Store Connect / Play Console.

4. Complete privacy and data-safety disclosures.
   This build is local-first, but both stores still require accurate answers
   about diagnostics, crash reporting, account systems, and any future remote
   services you enable.

5. Validate background audio on real devices.
   Confirm lock-screen controls, headset buttons, interruption handling, and
   long-session playback on at least one Android device and one iPhone.

6. Test file import on release builds.
   Verify importing from Files / document providers, re-opening the app, and
   replaying previously imported tracks after a cold launch.

## Recommended Release Checklist

1. Run `flutter analyze` and `flutter test`.
2. Build `flutter build appbundle --release`.
3. Build `flutter build ios --release --no-codesign`.
4. Build `flutter build macos --release`.
5. Install each artifact on device hardware and verify:
   import files, playback, background playback, history export, theme toggle.
