# Implementation Status

This document summarizes current code vs documented requirements.

Backend (Hono)
- Implemented
  - POST `/api/auth/register`, POST `/api/auth/login`
  - GET `/api/users/me`, PUT `/api/users/me`, DELETE `/api/users/me`
  - GET `/api/users/encounters`
  - POST `/api/encounters`
  - POST `/api/encounters/observe` (tempId観測イベントの受信・相互観測でEncounter生成)
  - POST `/api/encounters/register-tempid` (広告中のtempIdを登録、期限付き)
  - POST `/api/users/:userId/like`（相互いいね成立時に即マッチ作成に変更）
  - GET `/api/users/friends`
  - GET `/api/users/blocked`
  - POST/DELETE `/api/users/:userId/block`
- Missing vs requirements
  - DELETE `/users/{userId}/like`
  - PUT `/users/me/device`
  - GET `/users/{userId}` (public profile)
  - Pagination for list endpoints
  - Firestore TTLポリシー適用（任意・推奨、`recentEncounters.expiresAt` フィールド）

Frontend (Flutter)
- Implemented
  - Register/Login screens and state management
  - Encounters list consuming `/api/users/encounters`
  - BLE scan screen (foreground) with RSSI threshold & CC filter
  - BLE advertising via `ble_peripheral`, tempId rotation (15min) and backend registration
  - Token refresh/expiry handling in `ApiService` (proactive + 401 retry)
  - サーバ側の24hクリーンアップジョブ（`recentEncounters`定期削除、1時間毎）
  - サーバ側のtempIdsクリーンアップジョブ（`tempIds`の期限切れ削除、15分毎）
- Missing vs requirements
  - Navigation post-registration
  - Friends list UI polish（プロフィール写真/SNS、アンブロックなど）
  - Profile edit (photo/bio/hobbies/SNS)
  - BLE: バックグラウンド動作対応（省電力/OS制約考慮）

Security/Operational
- `apps/backend/serviceAccountKey.json` exists in repo; keep out of VCS and rotate if leaked.
- `.env` carries `FIREBASE_WEB_API_KEY` for REST login.

Notes
- Docs updated to reflect Hono-based server (was TBD/Cloud Functions leaning).
 - BLE docs aligned to plugin-based v0 plan (no background yet).
 - 要件更新: マッチは相互いいね時に即成立。再会時の通知は後続で実装予定。
