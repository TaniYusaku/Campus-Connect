Frontend (Flutter)

Overview
- Flutter app with Riverpod state management and HTTP client.
- Auth and app prefs stored in `flutter_secure_storage`.
- Foreground BLE scanning via `flutter_blue_plus`, minimal advertising via `ble_peripheral`.
- Auto-advertise manager starts advertising when authenticated.

Requirements
- Flutter SDK (stable), iOS/Android toolchains.
- Backend reachable at `http://<host>:3000/api`.
- Android: minSdkVersion 23, BLE permissions set in `android/app/src/main/AndroidManifest.xml` (SCAN/CONNECT/ADVERTISE, legacy FINE_LOCATION for <= Android 11).
- iOS: `NSBluetoothAlwaysUsageDescription` and `NSBluetoothPeripheralUsageDescription` added in `ios/Runner/Info.plist`. iOS minimum 15.0.

Run
- `flutter pub get`
- `flutter run` (or specify API base via `--dart-define` below)

Config
- API base URL can be overridden via `--dart-define`:
  - `flutter run --dart-define=API_BASE_URL=http://<LAN_IP>:3000/api`
  - Default base is set in `lib/services/api_service.dart`.

Screens
- Register/Login: email/password flow hitting `/api/auth/*`.
- Home tabs: Encounters, Friends, Profile (friends/profile are placeholders for now).
- BLE Scan screen: toggle continuous scan, CC-only filter, RSSI threshold, and start/stop advertising.

BLE (v0) implemented
- Scan: Foreground-only, with in-app filter by Local Name prefix `CC-` or service UUID.
- Advertise: Local Name `CC-<tempId>` and minimal GATT service (read-only characteristic with the current tempId).
- TempId rotation: every 15 minutes, persisted locally and sent to backend (`POST /api/encounters/register-tempid`).
- Observation upload: when a CC device is seen above RSSI threshold, send `POST /api/encounters/observe` (rate-limited per tempId).

Next Steps
- Enforce 24h TTL cleanup for `recentEncounters` on server (TTL policy or scheduled job).
- Implement in-app notifications when a match is detected again.
- Wire Friends/Profile screens and add like/block UI.
- Focus on polishing foreground scan/advertise UX (background動作はサポート対象外)。
