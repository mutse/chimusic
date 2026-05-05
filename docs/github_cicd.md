# GitHub CI/CD

## What Was Added

### CI workflow

File: `.github/workflows/ci.yml`

- runs on pull requests, pushes to `main` or `master`, and manual dispatch
- pins Flutter to `3.41.4`
- runs `flutter analyze` and `flutter test`
- builds Android release `apk` and `aab`
- builds unsigned iOS release `Runner.app`
- builds macOS release `chimusic.app`
- packages Apple outputs into distributable archives and uploads all artifacts

### CD workflow

File: `.github/workflows/release.yml`

- runs on git tags matching `v*`
- builds Android release `apk` and `aab`
- builds unsigned iOS `Runner.app` archive
- builds macOS `.app` archive and `.dmg`
- creates or updates the matching GitHub Release
- uploads packaged assets to that release

## Android Signing

The Android Gradle config now supports two release modes:

1. production signing from `android/key.properties`
2. production signing from CI environment variables

If neither is present, release builds fall back to the debug keystore so CI can still produce installable artifacts.

### GitHub secrets for signed Android releases

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Example to create the Base64 value:

```bash
base64 < upload-keystore.jks | tr -d '\n'
```

## Apple Packaging

The workflows intentionally build Apple artifacts without signing:

- iOS: zipped `Runner.app`
- macOS: zipped `.app` and `.dmg`

This is enough for CI artifact output and internal verification, but not enough for App Store, TestFlight, or notarized macOS release distribution.

## Release Flow

1. Push your code to the default branch and let CI pass.
2. Create and push a version tag such as `v1.0.0`.
3. GitHub Actions runs the release workflow.
4. Built assets are attached to the GitHub Release for that tag.

Example:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Before Store Submission

- replace `com.example.chimusic` with your real Android application id
- replace `com.example.chimusic` with your real Apple bundle identifiers
- add Apple signing certificates, provisioning profiles, and notarization flow if you want true store-ready Apple binaries
