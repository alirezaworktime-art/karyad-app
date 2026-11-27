# karyad-app

اپ **کاریاد** — یادآور سرویس خودرو و دفتر حساب رانندگان.

Flutter client for Karyad. Android first, then web and desktop from the same
codebase. Local-first: every user record stays on the device and the app
works fully offline.

| Repo | Role |
| --- | --- |
| `karyad-app` | This app (Flutter / Dart) |
| `karyad-backend` | API: catalog updates, app version (NestJS) |
| `karyad-web` | Public website and download page |

## Requirements

- Flutter stable (CI uses the latest stable; see `FLUTTER_VERSION.txt` for
  the version the project was created with). Flutter 3.50+ ships Material
  as `package:material_ui` — import that, not `package:flutter/material.dart`.
- Java 17 for Android builds.

## Run

```bash
flutter pub get
flutter run            # Android device or emulator
flutter test           # unit + widget tests
flutter analyze
```

## Get the Android APK without a computer

Every push to `main` builds a release APK in GitHub Actions:
**Actions → CI → latest run on main → Artifacts → karyad-android-apk**.
A tag such as `v0.1.0` also attaches the APK to a GitHub Release.

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Contributing](CONTRIBUTING.md)
