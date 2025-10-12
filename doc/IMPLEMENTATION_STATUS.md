# Implementation Status

This document summarizes the current implementation versus the documented requirements.

## Backend (Hono)
### 実装済み
- POST `/api/auth/register`, POST `/api/auth/login`, POST `/api/auth/refresh`
- GET `/api/users/me`, PUT `/api/users/me`, DELETE `/api/users/me`
- GET `/api/users/encounters`
- POST `/api/encounters`
- POST `/api/encounters/observe`（tempId観測イベントの受信・相互観測でEncounter生成）
- POST `/api/encounters/register-tempid`（広告中のtempIdを登録、期限付き）
- POST `/api/users/:userId/like`（相互いいね成立時に即マッチ作成）
- DELETE `/api/users/:userId/like`（マッチ前のみ取り消し可）
- GET `/api/users/friends`
- POST `/api/users/:userId/block`（ブロック解除は仕様として提供しない）
- GET `/api/users/blocked`
- GET `/api/users/likes/recent`
- GET `/api/users/:userId`（公開プロフィール取得）

### 要件との差分 / 未対応項目
- PUT `/users/me/device`（通知用デバイストークン登録）
- 各一覧APIのページネーション
- Firestore TTLポリシーの導入（`recentEncounters.expiresAt` など、任意だが推奨）

## Frontend (Flutter)
### 実装済み
- 登録 / ログイン画面および状態管理
- Encountersタブ：`/api/users/encounters` を表示し、いいね／取り消し／ブロック操作に対応
- Friendsタブ：マッチ済みユーザー一覧表示、プロフィールモーダル表示、ブロック操作
- Profileタブ：プロフィール編集（写真アップロード、自己紹介、学部・学年、SNSリンクなど）
- BLE Scan画面：フォアグラウンドスキャン、RSSIしきい値調整、Campus Connectフィルタ切り替え
- BLE Advertise：15分ごとのtempIdローテーションとバックエンド登録
- `ApiService` 内でのトークンリフレッシュ（期限前更新＋401リトライ）
- 設定画面：通知トグル、ブロック一覧、ログアウト／退会導線

### 要件との差分 / 未対応項目
- 登録完了後のナビゲーション改善（オンボーディング／ホーム遷移のUX調整）
- Friends画面のUIブラッシュアップ（タイル表示やプロフィール要素の強化）
- マッチ成立時の演出（ポップアップ等）
- BLEのバックグラウンド対応（将来検討事項）

## Security / Operational Notes
- Firebaseサービスアカウント鍵は `.gitignore` 対象。コミットしない運用を継続し、必要に応じ `.env` や秘密管理ストアに保存する。
- **補足**: ローカル環境には `apps/backend/serviceAccountKey.json` を配置しているが、`.gitignore` に含めてあり Git 管理からは除外済み。リポジトリにコミット・push はされていない。
- `FIREBASE_WEB_API_KEY` などの環境変数は `.env` などでローカル管理する。

## メモ
- ドキュメントはHonoベースAPI構成に合わせて更新済み。
- BLE設計はv0想定（フォアグラウンドのみ）。バックグラウンド対応は後続タスクとする。
- マッチは相互いいね成立時に即成立。再会通知は将来追加予定。
