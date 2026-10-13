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

## Build release APKs / Play App Bundle

```bash
# Local APK
flutter build apk --flavor pos -t lib/main_pos.dart --release
flutter build apk --flavor rapport -t lib/main_rapport.dart --release

# Google Play (POS) — use App Bundle
flutter build appbundle --flavor pos -t lib/main_pos.dart --release
```

Store upload checklist (privacy + deletion URLs, signing, iOS): see [STORE-UPLOAD.md](./STORE-UPLOAD.md).

Outputs (typical):

- `build/app/outputs/flutter-apk/app-pos-release.apk`
- `build/app/outputs/flutter-apk/app-rapport-release.apk`

## Appflow

**POS:** device gate → activation (if needed) → login → connect preload → session floor.

**Rapport:** device gate → activation (if needed) → login → JTR Mobile dashboard (no session floor). Logout from the header. Defaults: **today’s date** for filters, **dark mode** on. Login supports **multi-restaurant**: saved QR bindings in a dropdown + « Ajouter un restaurant (QR) ».

The RAPPORT tab was removed from the POS bottom bar; managers use the **JTR Rapport** app.

## iOS

Android flavors are fully wired. iOS bundle ID for POS is `com.jtrsystem.pos`. Add matching Xcode schemes (`pos` / `rapport`) if needed, then:

```bash
flutter run --flavor pos -t lib/main_pos.dart
flutter run --flavor rapport -t lib/main_rapport.dart
```
