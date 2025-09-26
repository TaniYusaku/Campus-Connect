Backend (Hono + Firebase Admin)

- Requirements: Node 20+, Firebase service account JSON, `FIREBASE_WEB_API_KEY`.

Setup
- Copy your service account to `apps/backend/serviceAccountKey.json` (keep it out of VCS).
- Create `.env` with `FIREBASE_WEB_API_KEY=...`.
- Install deps and run: `npm install && npm run dev`

Server
- Base path: `/api`, default port `3000`.
- Health: `GET /api/` returns text.

Main Endpoints
- `POST /api/auth/register` create user (Auth + Firestore)
- `POST /api/auth/login` email/password → Firebase ID token
- `GET /api/users/me` get current user
- `PUT /api/users/me` update profile
- `DELETE /api/users/me` delete account
- `GET /api/users/encounters` recent encounters (blocked filtered)
- `POST /api/encounters` record encounter, create match if mutual like
- `POST /api/users/:userId/like` like a user
- `GET /api/users/friends` matched friends
- `GET /api/users/blocked` blocked users
- `POST/DELETE /api/users/:userId/block` block/unblock

Pending/Gaps
- `DELETE /users/{userId}/like`, `PUT /users/me/device`, `GET /users/{userId}`
- Pagination for list endpoints

Notes
- Do not commit service keys. Consider rotating existing keys if already pushed.

Service Account Key (for beginners)
- What it is: A special JSON file that lets the server talk to Firebase as an admin.
- Why keep it secret: Anyone who gets it can read/write your Firebase data.
- Where to put it: Keep only on your computer (e.g. `apps/backend/serviceAccountKey.json`). Do not upload to Git.
- How to use locally: Place the file above and run the server. It will be read by the code.
- If you already pushed it to Git:
  1) Remove from Git history: `git rm --cached apps/backend/serviceAccountKey.json` and commit.
  2) In Google Cloud Console, delete the leaked key and create a new one.
  3) Replace the local file with the new key JSON.
  4) Make sure `.gitignore` ignores `apps/backend/serviceAccountKey.json` (already configured).
