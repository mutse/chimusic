# ChiMusic

ChiMusic is a Flutter music app prototype for Android, iOS, and macOS with a Spotify-inspired product flow and an Apple liquid glass visual language.

## Local Development

```bash
$ flutter pub get
$ flutter analyze
$ flutter test
```

## Product And Design Notes

- Product scope: [docs/product_plan.md](docs/product_plan.md)
- UI system: [docs/liquid_glass_ui.md](docs/liquid_glass_ui.md)
- GitHub CI/CD: [docs/github_cicd.md](docs/github_cicd.md)
- Store release notes: [docs/app_store_readiness.md](docs/app_store_readiness.md)

## GitHub Actions

- `.github/workflows/ci.yml` runs Flutter analyze and tests, then produces Android, iOS, and macOS build artifacts for pull requests and main branch pushes.
- `.github/workflows/release.yml` runs on `v*` tags, packages Android release outputs plus unsigned Apple desktop/mobile artifacts, and uploads them to the matching GitHub Release.

## Release Status

- Android package id: `app.chimusic.player`
- iOS bundle id: `app.chimusic.player`
- macOS bundle id: `app.chimusic.player.macos`
- Apple release artifacts are still packaged unsigned by default. For TestFlight, App Store, or notarized macOS distribution, add your production signing assets first.
