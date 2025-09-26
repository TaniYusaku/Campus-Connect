# Implementation Status

This document summarizes current code vs documented requirements.

Backend (Hono)
- Implemented
  - POST `/api/auth/register`, POST `/api/auth/login`
  - GET `/api/users/me`, PUT `/api/users/me`, DELETE `/api/users/me`
  - GET `/api/users/encounters`
  - POST `/api/encounters`
  - POST `/api/users/:userId/like`
  - GET `/api/users/friends`
  - GET `/api/users/blocked`
  - POST/DELETE `/api/users/:userId/block`
- Missing vs requirements
  - DELETE `/users/{userId}/like`
  - PUT `/users/me/device`
  - GET `/users/{userId}` (public profile)
  - Pagination for list endpoints

Frontend (Flutter)
- Implemented
  - Register/Login screens and state management
  - Encounters list consuming `/api/users/encounters`
- Missing vs requirements
  - Navigation post-registration
  - Friends list and profile UI with backend wiring
  - Like/Block actions UI
  - Profile edit (photo/bio/hobbies/SNS)
  - Token refresh/expiry handling
  - BLE: 現時点はドキュメント方針を `flutter_blue_plus` に変更（フォアグラウンドのみ、スキャン中心）。

Security/Operational
- `apps/backend/serviceAccountKey.json` exists in repo; keep out of VCS and rotate if leaked.
- `.env` carries `FIREBASE_WEB_API_KEY` for REST login.

Notes
- Docs updated to reflect Hono-based server (was TBD/Cloud Functions leaning).
 - BLE docs aligned to plugin-based v0 plan (no background yet).
