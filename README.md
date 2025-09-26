Campus Connect (Monorepo)

Overview
- Student matching app based on BLE encounters.
- Monorepo: `apps/backend` (Node/Hono + Firebase Admin), `apps/frontend` (Flutter).

Quick Start
- Backend: `cd apps/backend && npm install && npm run dev` (needs `.env` and service account JSON)
- Frontend: `cd apps/frontend && flutter pub get && flutter run`

Docs
- Requirements: `doc/REQUIREMENTS.md`
- Backend spec: `apps/backend/doc/backend_requirements.md`
- Tech stack: `apps/backend/doc/tech_stack.md`
- Implementation status: `doc/IMPLEMENTATION_STATUS.md`

Security
- Do NOT commit secrets. Keep `apps/backend/serviceAccountKey.json` out of VCS and rotate if already exposed.
