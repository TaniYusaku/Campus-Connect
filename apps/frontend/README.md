Frontend (Flutter)

Overview
- Flutter app with Riverpod state management and http client.
- Auth token stored in `flutter_secure_storage`.

Requirements
- Flutter SDK (stable), iOS/Android toolchains.
- Backend reachable at `http://<host>:3000/api` (default is `localhost` for simulators).
- BLE (v0): Use `flutter_blue_plus` for scanning in foreground.
- Android: minSdkVersion >= 21, BLE permissions added in `android/app/src/main/AndroidManifest.xml`.
- iOS: `NSBluetoothAlwaysUsageDescription` added in `ios/Runner/Info.plist`.
 - iOS minimum: 15.0 (set in `ios/Podfile`).

Run
- `flutter pub get`
- `flutter run`

Screens
- Register/Login: simple email/password flow hitting `/api/auth/*`.
- Home tabs: Encounters, Friends, Profile (friends/profile are placeholders).

Config
- API base URL is hardcoded in `lib/services/api_service.dart`.
  - For real devices, replace `localhost` with your machine IP.

Next Steps
- Add UI for like/block and profile edit.
- Handle token expiry and re-login gracefully.
- Wire friends/profile screens to backend endpoints.
- Add BLE scan UI using `flutter_blue_plus` (foreground only for v0).
 - If you just added the plugin, fully stop and re-run the app (not just hot reload).
