# ARVision Gold — Flutter Mobile App

A **Flutter** app with a futuristic AR HUD that points at a gold chart, captures a frame, and gets a BUY / SELL / HOLD signal from the Flask AI backend.

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│  Flutter App (this folder)                       │
│                                                  │
│  • Full-screen camera preview (camera pkg)       │
│  • Animated HUD overlay (ScanReticle, HudPanel)  │
│  • POST /predict  → multipart image upload       │
│  • GET  /live_price → 30 s price ticker          │
└────────────────────────┬─────────────────────────┘
                         │  LAN Wi-Fi
                         ▼
┌──────────────────────────────────────────────────┐
│  Flask Backend  (../app.py)                      │
│  • POST /predict   — CV + AI model inference     │
│  • GET  /live_price — yfinance XAU/USD price     │
└──────────────────────────────────────────────────┘
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.0.0 |
| Dart SDK | ≥ 3.0.0 (bundled with Flutter) |
| Android Studio / Xcode | Latest stable |
| Physical Android/iOS device | Recommended (camera) |

Install Flutter: https://docs.flutter.dev/get-started/install

---

## Step 1 — Scaffold the Flutter project

Open a terminal and run:

```bash
# Go to the repo root (one level above this folder)
cd <path-to-repo>

# Scaffold a blank Flutter project
flutter create mobile --org com.arsam990 --project-name arvision_gold

# Enter the project folder (it already exists; just cd into it)
cd mobile

# Fetch all dependencies
flutter pub get
```

> The `flutter create` command generates the Android/iOS platform folders.
> The `lib/`, `pubspec.yaml` files in this repo **replace** the scaffold's defaults,
> so you don't need to touch anything else.

---

## Step 2 — Set your Flask server IP

Edit `lib/config/constants.dart`:

```dart
static const String flaskBaseUrl = 'http://192.168.1.100:5000';
//                                        ^^^^^^^^^^^
//                    Replace with YOUR laptop's LAN IP address.
//   Windows:  run  ipconfig  → look for "IPv4 Address"
//   macOS:    run  ifconfig  → look for "inet" under en0
//   Linux:    run  ip addr   → look for "inet"
```

Make sure your phone and laptop are on the **same Wi-Fi network**.

---

## Step 3 — Add platform permissions

### Android

Open `android/app/src/main/AndroidManifest.xml` and add inside `<manifest>` (before `<application>`):

```xml
<!-- Camera -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Network (Flask API) -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Camera feature declaration -->
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

Also set `android:usesCleartextTraffic="true"` on the `<application>` tag if your Flask
server is plain `http://` (not https):

```xml
<application
    android:label="ARVision Gold"
    android:usesCleartextTraffic="true"
    ...>
```

### iOS

Open `ios/Runner/Info.plist` and add inside the root `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>ARVision Gold needs camera access to scan gold charts.</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## Step 4 — Run the app

```bash
# List connected devices
flutter devices

# Run on a connected device (use its device ID from above)
flutter run -d <device-id>

# Or simply (picks the first available device)
flutter run
```

---

## Project Structure

```
mobile/
├── pubspec.yaml                    # Dependencies
└── lib/
    ├── main.dart                   # Entry point + dark theme
    ├── config/
    │   └── constants.dart          # 🔧 Flask IP lives here
    ├── models/
    │   └── prediction_model.dart   # Typed API response models
    ├── services/
    │   └── api_service.dart        # HTTP client (predict + live_price)
    ├── screens/
    │   └── ar_screen.dart          # Main screen: camera + HUD layers
    └── widgets/
        ├── scan_reticle.dart       # Animated targeting reticle (CustomPainter)
        ├── hud_panel.dart          # Glassmorphic result panel
        └── capture_button.dart     # Pulsing gold capture button
```

---

## HUD Design

```
┌──────────────────────────────────────┐
│ ◈ ARVISION GOLD        $ 2345.60 ▲  │  ← top bar (live price, 30 s poll)
│                                      │
│         /‾‾‾‾‾‾‾‾‾‾‾‾‾‾\           │
│        |   [◉ reticle]  |           │  ← animated scan frame (CustomPainter)
│         \______________/            │     spinning arc while scanning
│                                      │
│  ┌──────────────────────────────┐   │
│  │ PRICE    VISION   AI TREND   │   │  ← glassmorphic HUD panel
│  │ $2345    GREEN    UP         │   │     (BackdropFilter blur)
│  │   ┌──────────────────────┐  │   │
│  │   │   STRONG BUY  ◉      │  │   │  ← signal badge (green glow)
│  │   └──────────────────────┘  │   │
│  │  STRONG BUY: AI forecasts…  │   │
│  └──────────────────────────────┘   │
│              [  ◉  ]                │  ← capture button (pulsing)
└──────────────────────────────────────┘
```

| Signal   | Colour       | Panel border / glow |
|----------|--------------|---------------------|
| BUY      | `#00E676` 🟢 | Green glow          |
| SELL     | `#FF1744` 🔴 | Red glow            |
| HOLD     | `#90A4AE` ⚪  | Neutral grey        |
| Idle     | `#F0B90B` 🟡 | Gold (default)      |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Camera black screen | Run on a real device; emulators rarely support camera |
| Network error / timeout | Check IP in `constants.dart`; confirm same Wi-Fi; start Flask with `python app.py` |
| `CLEARTEXT not permitted` on Android | Add `usesCleartextTraffic="true"` (see Step 3) |
| Camera permission denied | Go to device Settings → Apps → ARVision Gold → Permissions |
| `flutter pub get` fails | Run `flutter upgrade` then retry |
