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

Docs
- Requirements: `doc/REQUIREMENTS.md`
- Backend spec: `apps/backend/doc/backend_requirements.md`
- Tech stack: `apps/backend/doc/tech_stack.md`
- Implementation status: `doc/IMPLEMENTATION_STATUS.md`

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
