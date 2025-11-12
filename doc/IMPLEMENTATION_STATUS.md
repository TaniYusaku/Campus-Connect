# Implementation Status

This document summarizes the current implementation versus the documented requirements.

## Backend (Hono)
### 実装済み
- POST `/api/auth/register`, POST `/api/auth/login`, POST `/api/auth/refresh`
- GET `/api/users/me`, PUT `/api/users/me`, DELETE `/api/users/me`
- GET `/api/users/encounters`
- POST `/api/encounters`（手動登録用エンドポイント。通常フローは /observe で相互検知後に生成）
- POST `/api/encounters/observe`（tempId観測イベントの受信・相互観測でEncounter生成）
- POST `/api/encounters/register-tempid`（広告中のtempIdを登録、期限付き）
- POST `/api/users/:userId/like`（相互いいね成立時に即マッチ作成）
- DELETE `/api/users/:userId/like`（マッチ前のみ取り消し可）
- GET `/api/users/friends`
- POST `/api/users/:userId/block`（ブロック解除は仕様として提供しない）
- GET `/api/users/blocked`
- GET `/api/users/likes/recent`
- GET `/api/users/:userId`（公開プロフィール取得）
- `recentEncounters` に接触回数 (`encounterCount`) を蓄積し、APIで返却
- 同性限定フィルタは廃止し、`/api/users/encounters` はブロック状態のみでフィルタリング

### 要件との差分 / 未対応項目
- 各一覧APIのページネーション
- Firestore TTLポリシーの導入（`recentEncounters.expiresAt` など、任意だが推奨）
- アカウント削除時にlikes/matchesなど関連データをまとめて削除する仕組み（現状はユーザードキュメントとAuthユーザーのみ）

## Frontend (Flutter)
### 実装済み
- 登録 / ログイン画面および状態管理
- 登録完了直後は自動でホームへ遷移し、ホーム側でオンボーディングを1回だけ挟む導線に統一
- Friendsタブ：カード型タイルで学部/学年・再会情報・SNSリンクを見やすく表示（SNSはコピー可のチップで提供）
- Encountersタブ：`/api/users/encounters` を表示し、いいね／取り消し／ブロック操作に対応。さらに「すべて/男性/女性」のタブと「同じ学部だけ」「同じ学年だけ」のフィルタを実装
- Friendsタブ：マッチ済みユーザー一覧表示、プロフィールモーダル表示、ブロック操作
- Profileタブ：プロフィール編集（写真アップロード、自己紹介、学部・学年、SNSリンクなど）
- BLE Scan画面：フォアグラウンドスキャン、RSSIしきい値調整、Campus Connectフィルタ切り替え
- BLE Advertise：15分ごとのtempIdローテーションとバックエンド登録
- `ApiService` 内でのトークンリフレッシュ（期限前更新＋401リトライ）
- 設定画面：通知トグル、ブロック一覧、ログアウト／退会導線
- アプリ内通知バナー（連続すれ違い、友達成立、友達との再会）

### 要件との差分 / 未対応項目
- 現時点でドキュメントとの差分はありません。新機能を追加する際に更新します。

## Security / Operational Notes
- Firebaseサービスアカウント鍵は `.gitignore` 対象。コミットしない運用を継続し、必要に応じ `.env` や秘密管理ストアに保存する。
- **補足**: ローカル環境には `apps/backend/serviceAccountKey.json` を配置しているが、`.gitignore` に含めてあり Git 管理からは除外済み。リポジトリにコミット・push はされていない。
- `FIREBASE_WEB_API_KEY` などの環境変数は `.env` などでローカル管理する。

## メモ
- ドキュメントはHonoベースAPI構成に合わせて更新済み。
- BLEはフォアグラウンド専用として確定。バックグラウンド対応は実装しない方針。
- マッチは相互いいね成立時に即成立。再会通知はアプリ内通知で提供予定。
