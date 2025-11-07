### **バックエンド技術仕様書 Ver. 1.0**

**作成日**: 2025年6月17日
**作成者**: Gemini

#### **1. 概要**

##### **1.1. ドキュメントの目的**
本ドキュメントは、アプリケーション「Campus Connect」のバックエンドに関する技術的な仕様を定義するものである。バックエンド開発におけるアーキテクチャ、使用技術、データベース構造、API設計の指針となることを目的とする。

##### **1.2. プロジェクト概要**
同じ大学の学生が、BLE（Bluetooth Low Energy）による物理的な「すれ違い」をきっかけとして繋がるためのマッチングアプリケーション。ユーザーはすれ違った相手に匿名で「いいね」を送り、相互に「いいね」した状態で再度すれ違うことでマッチングが成立する、偶然の再会を重視した体験を提供する。

#### **2. 全体アーキテクチャ**

本サービスのシステムは、クライアントアプリケーションとFirebaseプラットフォーム上のバックエンドサービス群で構成される。

* **クライアント (Client)**: Flutterで開発されたiOS/Androidアプリケーション。UI/UXの提供、BLEによる他ユーザーのスキャン、およびバックエンドAPIの呼び出しを担当する。
* **バックエンド (Backend)**: GoogleのFirebaseプラットフォームを全面的に採用する。認証、データベース、サーバーサイドロジックなどの機能を提供する。
* **連携 (Interaction)**: クライアントはFirebase SDKを介して、認証（Firebase Authentication）やデータベース（Firestore）と直接通信する。マッチング判定などの複雑なビジネスロジックは、クライアントからのリクエストをトリガーとして実行されるサーバーロジック（API）を介して処理される。

#### **3. 使用技術スタック**

| カテゴリ | 技術名 | 備考 |
| :--- | :--- | :--- |
| **PaaS** | Firebase | バックエンド機能全般の基盤。 |
| **データベース** | Cloud Firestore | ユーザー情報、すれ違いログ等の永続化。 |
| **認証** | Firebase Authentication | ユーザーの識別と認証管理。 |
| **サーバーロジック** | 未定（※） | ビジネスロジックを実行する環境。 |

※ 現時点では具体的な実装方法は未定だが、Firebaseエコシステムとの親和性から **Cloud Functions** の利用が第一候補となる。

#### **4. 認証方式**

##### **4.1. 認証フロー**
MVP（Minimum Viable Product）リリースでは、ユーザー登録のハードルを下げるため **Firebase Anonymous Authentication（メールアドレス認証）** を採用する。

1.  ユーザーがアプリを初回起動した際、クライアントは自動的にFirebaseのメールアドレス認証を実行する。
2.  FirebaseはユニークなユーザーID（UID）を発行し、ユーザーはログイン状態となる。
3.  このUIDは、Firestore上のユーザーデータと紐づけるための主キーとして使用される。

##### **4.2. 将来的な拡張**
将来的に、メールアドレス認証アカウントを大学のメールアドレス等に紐づけて恒久的なアカウントにアップグレードする機能の追加を検討する。

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
- `POST /api/users/:userId/block` / `DELETE /api/users/:userId/block` ブロック/解除

未実装/要検討（要件との差分）
- `DELETE /users/{userId}/like` いいね取り消し
- ~~`PUT /users/me/device` デバイストークン登録~~ → アプリ内通知のみのため不要
- `GET /users/{userId}` 他者プロフィール取得（公開情報のみ）
- ページネーション（encounters/friends/blocked 一覧）
###### **5.2.6. `tempIds` コレクション**
* **パス**: `tempIds/{tempId}`
* **説明**: 端末が広告中の一時IDと、その所有ユーザー/有効期限を管理する。
* **フィールド**:
| フィールド名 | 型 (Type) | 説明 |
| :--- | :--- | :--- |
| `userId` | `string` | このtempIdのユーザーID |
| `updatedAt` | `Timestamp` | 登録更新時刻 |
| `expiresAt` | `Timestamp` | 失効時刻（TTLポリシー対象） |
