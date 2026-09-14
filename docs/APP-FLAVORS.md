# App flavors — two APKs from one project

Same codebase ships **two installable apps** (side-by-side on one device).

| Flavor | App name | Android `applicationId` | Entry | What it is |
|--------|----------|-------------------------|-------|------------|
| **pos** | JTR System | `com.jtrsystem.pos` | `lib/main_pos.dart` | Existing waiter/cashier POS |
| **rapport** | JTR Rapport | `com.jtrsystem.report` | `lib/main_rapport.dart` | Manager dashboard (login → Rapport) |

Update these IDs in `android/app/build.gradle.kts` if branding needs change before store release.

## Run (debug)

```bash
# POS
flutter run --flavor pos -t lib/main_pos.dart

# Rapport (manager)
flutter run --flavor rapport -t lib/main_rapport.dart
```

## Build release APKs

```bash
flutter build apk --flavor pos -t lib/main_pos.dart --release
flutter build apk --flavor rapport -t lib/main_rapport.dart --release
```

Outputs (typical):

- `build/app/outputs/flutter-apk/app-pos-release.apk`
- `build/app/outputs/flutter-apk/app-rapport-release.apk`

## Appflow

**POS:** device gate → activation (if needed) → login → connect preload → session floor.

**Rapport:** device gate → activation (if needed) → login → JTR Mobile dashboard (no session floor). Logout from the header.

The RAPPORT tab was removed from the POS bottom bar; managers use the **JTR Rapport** app.

## iOS

Android flavors are fully wired. For iOS, add matching Xcode schemes (`pos` / `rapport`) and bundle IDs (`com.example.jtrSystem` / `com.example.jtrRapport`), then:

```bash
flutter run --flavor pos -t lib/main_pos.dart
flutter run --flavor rapport -t lib/main_rapport.dart
```
