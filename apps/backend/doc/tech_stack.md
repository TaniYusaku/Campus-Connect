### **バックエンド技術仕様書 Ver. 1.0**

**作成日**: 2025年6月17日
**作成者**: Gemini

#### **1. 概要**

##### **1.1. ドキュメントの目的**
本ドキュメントは、アプリケーション「Campus Connect」のバックエンドに関する技術的な仕様を定義するものである。バックエンド開発におけるアーキテクチャ、使用技術、データベース構造、API設計の指針となることを目的とする。

##### **1.2. プロジェクト概要**
同じ大学の学生が、BLE（Bluetooth Low Energy）による物理的な「すれ違い」をきっかけとして繋がるためのマッチングアプリケーション。ユーザーはすれ違った相手に匿名で「いいね」を送り、相互に「いいね」した状態で再度すれ違うことでマッチングが成立する、偶然の再会を重視した体験を提供する。

#### **2. 全体アーキテクチャ**

本サービスのシステムは、クライアントアプリケーションと Hono ベースのAPI（Firebase Admin連携）で構成される。

* **クライアント (Client)**: Flutterで開発されたiOS/Androidアプリケーション。UI/UXの提供、BLEによる他ユーザーのスキャン、およびバックエンドAPIの呼び出しを担当する。
* **バックエンド (Backend)**: Node.js + Hono で実装したREST API。Firebase Admin SDKを利用して Auth/Firestore/Storage を操作する。
* **連携 (Interaction)**: クライアントは `/api/*` のRESTエンドポイント経由でやり取りする（Firebase SDK直接利用はしない）。マッチング判定などのビジネスロジックはサーバー側で処理する。

#### **3. 使用技術スタック**

| カテゴリ | 技術名 | 備考 |
| :--- | :--- | :--- |
| **PaaS** | Firebase | Firestore / Storage / Auth のバックエンド基盤。 |
| **データベース** | Cloud Firestore | ユーザー情報、すれ違いログ等の永続化。 |
| **認証** | Firebase Authentication | メール/パスワード認証（サーバー経由で実行）。 |
| **サーバーロジック** | Node.js + Hono | `/api` 配下のRESTサーバー（Firebase Admin SDK利用）。 |

#### **4. 認証方式**

##### **4.1. 認証フロー**
MVP ではメール/パスワード認証を採用し、サーバーの `/api/auth/register` と `/api/auth/login` を経由して Firebase Authentication にユーザーを作成・サインインする。京都産業大学ドメイン（`*.kyoto-su.ac.jp`）のメールアドレスのみ受け付ける。

1.  ユーザーが登録画面でメール・パスワード・ニックネーム等を入力し、`/api/auth/register` がユーザーを作成する。
2.  登録後、`/api/auth/login` でサインインし、発行されたトークンをクライアントが保持する。

##### **4.2. 将来的な拡張**
大学メールドメイン以外への対応や追加の本人確認フローは別途検討とする。

#### **5. データベース設計（Firestoreデータモデル）**

##### **5.1. 設計思想**
Firestoreのドキュメント指向モデルを最大限に活用し、パフォーマンスと拡張性を両立させる。ユーザーデータを中心に据え、関連データはサブコレクションとして管理することで、データ構造の肥大化を防ぐ。

##### **5.2. コレクション定義**

###### **5.2.1. `users` コレクション**
* **パス**: `users/{userId}`
* **説明**: ユーザーのプロフィール情報やアカウント状態を管理する。
* **フィールド**:
| フィールド名         | 型 (Type)         | 説明                                               |
| :---                | :---              | :---                                              |
| `id`                | `string`          | ユーザーID                                         |
| `userName`          | `string`          | ユーザー名                                         |
| `email`             | `string`          | メールアドレス                                     |
| `faculty`           | `string`          | 学部 (例: "情報学部")                              |
| `grade`             | `number`          | 学年 (例: 2)                                       |
| `profilePhotoUrl`   | `string`          | プロフィール写真のURL                              |
| `bio`               | `string`          | 自己紹介文                                         |
| `hobbies`           | `array<string>`   | 趣味・興味のタグリスト (例: ["読書", "映画"])      |
| `snsLinks`          | `map`             | SNSリンク (例: `{ "x": "user_x" }`)              |
| `createdAt`         | `timestamp`       | 作成日時                                           |
| `updatedAt`         | `timestamp`       | 更新日時                                           |

###### **5.2.2. `recentEncounters` サブコレクション**
* **パス**: `users/{userId}/recentEncounters/{otherUserId}`
* **説明**: 「最近すれ違った人」リストの表示用データ。24時間で失効。
* **フィールド**:
| フィールド名 | 型 (Type) | 説明 |
| :--- | :--- | :--- |
| `lastEncounteredAt` | `Timestamp` | 最後にすれ違った日時。 |
| `expiresAt` | `Timestamp` | 失効予定時刻（`lastEncounteredAt + 24h`）。TTLポリシー対象。 |
| `count` | `number` | 接触回数。初回は1、以降のすれ違いでインクリメント。 |

###### **5.2.3. `likes` サブコレクション**
* **パス**: `users/{userId}/likes/{otherUserId}`
* **説明**: ユーザーが「いいね」した相手を記録する。
* **フィールド**:
| フィールド名 | 型 (Type) | 説明 |
| :--- | :--- | :--- |
| `createdAt` | `Timestamp` | 「いいね」した日時。 |

###### **5.2.4. `matches` サブコレクション**
* **パス**: `users/{userId}/matches/{otherUserId}`
* **説明**: マッチングが成立した相手（友達）を記録する。
* **フィールド**:
| フィールド名 | 型 (Type) | 説明 |
| :--- | :--- | :--- |
| `createdAt` | `Timestamp` | マッチングが成立した日時。 |

###### **5.2.5. `blockedUsers` サブコレクション**
* **パス**: `users/{userId}/blockedUsers/{otherUserId}`
* **説明**: ユーザーがブロックした相手を記録する。
* **フィールド**:
| フィールド名 | 型 (Type) | 説明 |
| :--- | :--- | :--- |
| `createdAt` | `Timestamp` | ブロックした日時。 |

##### **5.3. データ整合性とセキュリティ**
Firestoreセキュリティルールを用いて、ユーザーが自身のデータ以外を不正に読み書きできないよう、厳密なアクセス制御を行う。

#### **6. サーバーロジック（API）設計**

バックエンドは Node.js + Hono で実装済み。Firebase Admin SDK を利用し、Auth/Firestore を操作する。

- ベースパス: `/api`
- フレームワーク: Hono (`@hono/node-server`)
- 認証: Firebase ID トークンを Bearer で検証

実装済みの主なエンドポイント（2025-09 現在）
- `POST /api/auth/register` ユーザー登録（Auth + Firestore）
- `POST /api/auth/login` Firebase REST 経由でサインインし ID トークン発行
- `GET /api/users/me` サインイン中ユーザー取得
- `PUT /api/users/me` プロフィール更新
- `DELETE /api/users/me` アカウント削除
- `GET /api/users/encounters` 最近すれ違い一覧（ブロック除外）
- `POST /api/encounters` すれ違い記録（相互いいねならマッチ作成）
- `POST /api/users/:userId/like` いいね登録
- `GET /api/users/friends` マッチ（友達）一覧
- `GET /api/users/blocked` ブロック済みユーザー一覧
- `POST /api/auth/refresh` トークンリフレッシュ
- `POST /api/encounters/observe` すれ違い観測イベント
- `POST /api/encounters/register-tempid` tempId登録
- `DELETE /api/users/:userId/like` いいね取り消し（マッチ前のみ）
- `GET /api/users/likes/recent` 最近の「いいね」一覧
- `GET /api/users/:userId` 公開プロフィール取得
- `POST /api/users/:userId/block` ブロック（解除不可）

未実装/要検討（要件との差分）
- 一覧APIのページネーション（encounters/friends/blocked など）
- Firestore TTLポリシーの導入（`recentEncounters.expiresAt` など）
- 退会時にlikes/matches等の関連データをまとめて削除する仕組み
###### **5.2.6. `tempIds` コレクション**
* **パス**: `tempIds/{tempId}`
* **説明**: 端末が広告中の一時IDと、その所有ユーザー/有効期限を管理する。
* **フィールド**:
| フィールド名 | 型 (Type) | 説明 |
| :--- | :--- | :--- |
| `userId` | `string` | このtempIdのユーザーID |
| `updatedAt` | `Timestamp` | 登録更新時刻 |
| `expiresAt` | `Timestamp` | 失効時刻（TTLポリシー対象） |
