# Store upload — JTR System (POS)

Package IDs:
- Android: `com.jtrsystem.pos`
- iOS: `com.jtrsystem.pos`

## Public legal URLs (Firebase Hosting)

Project: `jtr-system-legal`

| Page | URL |
|------|-----|
| Privacy Policy | https://jtr-system-legal.web.app/privacy |
| Account deletion | https://jtr-system-legal.web.app/delete-account |

Also available:
- https://jtr-system-legal.firebaseapp.com/privacy
- https://jtr-system-legal.firebaseapp.com/delete-account

Redeploy after editing `hosting/`:

```bash
firebase deploy --only hosting --project jtr-system-legal
```

Use these URLs in Google Play Console and App Store Connect.

---

## Google Play (Android)

### 1. Create upload keystore (once)

```bash
mkdir -p android/keystore
keytool -genkey -v \
  -keystore android/keystore/jtr-pos-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias jtrsystem
```

Copy `android/key.properties.example` → `android/key.properties` and fill passwords.

### 2. Build App Bundle (required by Play)

```bash
flutter build appbundle --flavor pos -t lib/main_pos.dart --release
```

Output:
`build/app/outputs/bundle/posRelease/app-pos-release.aab`

### 3. Play Console checklist

1. Create app **JTR System** with package `com.jtrsystem.pos`
2. **App content → Privacy policy** → `https://jtr-system-legal.web.app/privacy`
3. **App content → Account deletion** → `https://jtr-system-legal.web.app/delete-account`
4. Complete **Data safety** form (account info, device IDs, photos/camera for QR, app activity / orders on restaurant server)
5. Complete **Ads** (likely “No”), **Target audience**, **Content ratings**
6. Upload the `.aab` to Internal testing → then Production
7. Store listing: screenshots, short/full description, feature graphic, icon

Permissions declared today: Internet, Network state, Camera (QR activation).

---

## Apple App Store (iOS)

### 1. Apple Developer

1. Create App ID: `com.jtrsystem.pos`
2. Create app in App Store Connect: **JTR System**
3. Privacy Policy URL: `https://jtr-system-legal.web.app/privacy`
4. App Privacy / Account deletion: link `https://jtr-system-legal.web.app/delete-account`

### 2. Xcode signing

Open `ios/Runner.xcworkspace`, select team, enable Automatically manage signing for bundle `com.jtrsystem.pos`.

### 3. Build IPA

```bash
flutter build ipa --flavor pos -t lib/main_pos.dart --release
```

Upload with Transporter or:

```bash
xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
  --apiKey YOUR_KEY --apiIssuer YOUR_ISSUER
```

(or use Xcode Organizer → Distribute App)

### 4. App Store Connect checklist

1. Privacy Policy URL set
2. Account deletion URL / instructions set
3. App Privacy nutrition labels
4. Screenshots for required device sizes
5. Review notes: explain LAN POS activation via QR, camera usage, local network access

Info.plist already includes camera, photo library, and local network usage strings.

---

## Notes

- POS flavor entrypoint: `lib/main_pos.dart`
- Do **not** upload the Rapport flavor (`com.jtrsystem.report`) unless you create a separate store listing
- Keep `android/key.properties` out of git (passwords). The upload keystore under `android/keystore/` can be committed if your team chooses to share it via the remote.
- Bypass activation (`JTR-BYPASS`) should be disabled before public store builds if still enabled in code
