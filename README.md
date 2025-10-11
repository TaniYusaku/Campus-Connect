Campus Connect (Monorepo)

Overview
- Student matching app based on BLE encounters.
- Monorepo: `apps/backend` (Node/Hono + Firebase Admin), `apps/frontend` (Flutter).

Quick Start
- Backend: `cd apps/backend && npm install && npm run dev` (needs `.env` and service account JSON)
- Frontend: `cd apps/frontend && flutter pub get && flutter run`
- Frontend can override API base URL via dart-define:
  - Example: `flutter run --dart-define=API_BASE_URL=http://<LAN_IP>:3000/api`
  - Default (if omitted) is defined in `lib/services/api_service.dart`.
 - Backend cleanup:
   - Encounters: `CLEANUP_INTERVAL_MINUTES=60` (default). Disable with `DISABLE_CLEANUP=1`.
   - TempIds: `TEMPIDS_CLEANUP_INTERVAL_MINUTES=15` (default). Disable with `DISABLE_TEMPIDS_CLEANUP=1`.

Docs
- Requirements: `doc/REQUIREMENTS.md`
- Backend spec: `apps/backend/doc/backend_requirements.md`
- Tech stack: `apps/backend/doc/tech_stack.md`
- Implementation status: `doc/IMPLEMENTATION_STATUS.md`

API Endpoints (MVP)
- `POST /api/auth/register`, `POST /api/auth/login`
- `GET /api/users/me`, `PUT /api/users/me`, `DELETE /api/users/me`
- `GET /api/users/encounters`
- `POST /api/encounters`, `POST /api/encounters/observe`, `POST /api/encounters/register-tempid`
- `POST /api/users/:userId/like`, `DELETE /api/users/:userId/like` (取り消しは未マッチ時のみ。マッチ済みはブロックを使用)
- `GET /api/users/friends`
- `POST /api/users/:userId/block`（解除不可。ブロックすると互いの友達・すれ違いリストから除外）

BLE (v0) Overview
- Scan (foreground): `flutter_blue_plus`. In-app filter by Local Name prefix `CC-` or Campus Connect service UUID. RSSI threshold adjustable in UI (default -80 dBm).
- Advertise (foreground): `ble_peripheral`. Local Name `CC-<tempId>` and minimal GATT service with a read-only characteristic holding the current tempId.
- TempId rotation: every 15 minutes. TempId is persisted locally and registered to the backend with ~16 min expiry.
- Observation upload: on encountering a CC device above the threshold, client sends `POST /api/encounters/observe` (rate-limited per tempId).

BLE Security Summary
- Anti-replay/spoofing: short-lived tempIds (15 min) with server-side expiry; mutual encounter requires two-way observations within ~5 minutes.
- Transport encryption: App ↔ API over HTTPS; signed URL uploads use HTTPS. BLE advertising is plaintext but only contains the rotating tempId.
- API authentication: Firebase ID token (Bearer) required for protected endpoints; verified by backend.
- TempId mapping: Firestore `tempIds/{tempId}` → `{ userId, expiresAt }` used to resolve observations, honoring expiry.

24h TTL (Recent Encounters)
- The server runs a periodic cleanup that deletes `users/*/recentEncounters/*` older than 24 hours (collection group query), by default every 60 minutes.
- Production alternative: enable Firestore TTL policy on `recentEncounters.expiresAt` (we now write this field as `lastEncounteredAt + 24h`).
- If you see `FAILED_PRECONDITION` from the cleanup, create a Composite Index for collection group `recentEncounters` on field `lastEncounteredAt` (ascending), or rely on the built-in fallback which iterates per-user collections.

TempIds Cleanup
- Expired tempIds (`tempIds/*` with `expiresAt <= now`) are periodically deleted (default every 15 minutes).
- Production alternative: enable TTL on `tempIds.expiresAt` and let Firestore auto-delete them.

Security
- Do NOT commit secrets. Keep `apps/backend/serviceAccountKey.json` out of VCS and rotate if already exposed.
- If the key was ever committed, remove it from tracking and rotate:
  - Untrack locally: `git rm --cached apps/backend/serviceAccountKey.json`
  - Add/verify ignore rules (already present in `.gitignore`)
  - Rotate/reissue the Firebase service account key and update the local file

Profile Photo Upload (MVP)
- Backend requires `FIREBASE_STORAGE_BUCKET` in `apps/backend/.env` (e.g. `your-project-id.appspot.com`).
- Flow:
  1) Client requests a signed URL: `POST /api/users/me/profile-photo/upload-url` with JSON `{ contentType: "image/jpeg" }`.
  2) Client PUTs the image bytes to the signed URL with the same `Content-Type`.
  3) Client confirms: `POST /api/users/me/profile-photo/confirm` with `{ objectPath }`. Server makes it public and saves URL in profile.
- Frontend uses `image_picker` to pick images. Run `flutter pub get` after adding the dependency.
