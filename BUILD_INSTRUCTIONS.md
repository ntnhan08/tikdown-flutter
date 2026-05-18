# TikDown Flutter v2.0 — Huong dan Build

## Thong tin
| Muc | Gia tri |
|---|---|
| Framework | Flutter 3.22+ / Dart 3.3+ |
| URL | https://tikdown.ddns.net |
| Package | com.tikdown.app |
| Min SDK | Android 8.0 (API 26) |

---

## Buoc 1 — Cai Flutter SDK

Tai ve tai: https://docs.flutter.dev/get-started/install

Sau khi cai xong, kiem tra:
```bash
flutter doctor
```
Dam bao "Android toolchain" va "Flutter" co dau check xanh.

---

## Buoc 2 — Cai dependencies

```bash
cd TikDown_Flutter
flutter pub get
```

---

## Buoc 3 — Build APK

```bash
# APK debug (nhanh, dung de test)
flutter build apk --debug

# APK release (toi uu, nho hon, nhanh hon)
flutter build apk --release

# APK tach rieng theo CPU (nho hon nua)
flutter build apk --split-per-abi --release
```

APK o tai:
```
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (64-bit - khuyen dung)
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (32-bit)
```

---

## Buoc 4 — Chay tren may ao / thiet bi that

```bash
# Xem danh sach thiet bi
flutter devices

# Chay truc tiep (hot reload)
flutter run

# Chay release mode
flutter run --release
```

---

## Cau truc du an

```
TikDown_Flutter/
├── lib/
│   ├── main.dart          # Entry point + MaterialApp
│   ├── app_theme.dart     # Mau sac, gradient, theme
│   ├── splash_screen.dart # Splash voi particle animation
│   └── webview_screen.dart# Man hinh WebView chinh
├── assets/
│   └── images/
│       └── ic_logo.png    # Logo TikDown
├── android/
│   └── app/src/main/
│       ├── kotlin/.../MainActivity.kt
│       ├── AndroidManifest.xml
│       └── res/...        # Icons, styles
└── pubspec.yaml           # Dependencies
```

---

## Tinh nang

### Giao dien
- Splash screen voi 58 hat neon bay (ParticleView Flutter custom)
- Glow ring 4 lop pulse xung quanh logo
- Gradient text "TikDown" (cam -> vang -> cam)
- Logo pop-in voi elasticOut easing
- 3 chấm loading nhan nhay theo thu tu
- Progress bar gradient cau vong (cam-vang-do) co glow shadow
- SwipeRefresh mau cam
- Man hinh loi dep voi icon, gradient button, glow effect
- Download overlay thanh tien trinh gradient

### Tinh nang chinh
- WebView voi flutter_inappwebview (manh nhat hien tai)
- Cache LOAD_CACHE_ELSE_NETWORK (khong reload thua)
- configChanges day du trong Manifest (khong restart Activity)
- onSaveInstanceState / restoreState (khoi phuc sau khi bi kill)
- pauseTimers / resumeTimers (tiet kiem pin khi background)
- Download file voi Dio (co progress bar + cookie forwarding)
- Kiem tra mang truoc khi tai
- Back navigation thong minh (quay lai / dialog thoat)
- External links hoi xac nhan
- Dark/Light mode tu dong

---

## Thay doi URL
File: `lib/webview_screen.dart`
```dart
static const String _targetUrl = 'https://tikdown.ddns.net';
```
