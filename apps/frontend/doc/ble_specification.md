## BLE 技術方針 / 詳細仕様（v0 方針）

1. 実装アーキテクチャ（v0）
- Flutter プラグインを使用します。
- 使用プラグイン: `flutter_blue_plus` ^2.0.0（参考: https://pub.dev/packages/flutter_blue_plus）
- スコープ: フォアグラウンドのみ対応します（バックグラウンド動作はサポートしません）。

2. すれ違い判定
- 基本: RSSI がしきい値（初期値: ≥ -80dBm）を超えたら観測イベントを送信し、**サーバが5分以内の双方向観測を検出した場合のみ Encounter を確定**します（`/api/encounters/observe` 発火→サーバ内で相互観測を確認）。
- フィルタ: RSSI 閾値はUIから調整可能。同一端末は5分デバウンス（相互観測成立後も5分）で過剰送信を避ける。

3. アドバタイズ（v0）
- 最小アドバタイズを導入済みです（前景のみ）。
- 使用プラグイン: `ble_peripheral`（pubspec参照）
- 仕様:
  - Local Name: `CC-<advertiseId>` を広告
  - GATT Service: `kCcServiceUuid` に read-only characteristic `kCcCharacteristicUuid` を1つ配置し、`advertiseId` を文字列で保持
  - `advertiseId` は端末内に安全に保存・再利用（`flutter_secure_storage`）
  - 通知/notify は未使用（必要に応じて後続検討）

4. スキャン仕様
- フィルタ: 指定 Service UUID のみ。受信時に RSSI とタイムスタンプを付与。
- デバウンス: 同一 tempID は期間内1件に集約、最終検知時刻を更新。
- 保存/表示: サーバ側の`recentEncounters`を利用して表示（クライアントはメモリ中心）。
  24hのTTL自動削除はサーバ設定（TTLポリシー/定期ジョブ）で対応予定。

5. バックグラウンド動作
- 実装対象外です。フォアグラウンドでの動作のみを想定し続けます。

6. 権限/設定
- iOS: `NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`, 必要に応じて `UIBackgroundModes` 設定。
- Android: `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_SCAN`, `ACCESS_FINE_LOCATION` (API 31+ の権限モデルに対応)。

7. サーバー連携
- v0: 観測イベントを送信（`POST /api/encounters/observe`）。
- 広告側の現在tempIdを登録（`POST /api/encounters/register-tempid`）。
- v1: マッチング判定に使う正式なサマリ送信（`POST /api/encounters` など）へ段階移行。

8. 実装スコープ（v0）
- `flutter_blue_plus` によるスキャン開始/停止、権限確認/要求。
- UI: ステータス表示、スキャン結果のリスト表示（RSSI/デバイス名など）。
- 保存: 必要に応じて端末内に簡易キャッシュ（メモリ or ローカルDB）。

9. オープンな設計項目（質問）
- ペリフェラル側プラグイン: `ble_peripheral` を使用中。
- v0で最小アドバタイズまで導入済み。バックグラウンド対応は行いません。
- RSSI 閾値やフィルタ条件は固定値で開始し、後から調整で問題ありませんか？（合意済み）

10. セキュリティ（すれ違い検知フロー）
- なりすまし/リプレイ対策: tempIdは5分ごとにローテーションし、有効期限（~6分）付きでサーバに登録。
  サーバは相互観測を5分以内の双方向で判定。期限切れのtempIdや古い観測は無効化し、再利用（リプレイ）の効果を下げる。
- 通信経路の暗号化: 現行MVPでは時間制約によりHTTPエンドポイント（例: `http://esencnts.kyoto-su.ac.jp:3000/api`）で運用しています。将来的に本番導線ではHTTPSへ切り替える方針です。BLE広告自体は平文だが、含まれるのは一時IDのみ。
- リクエスト認証: すべての保護APIはFirebase IDトークン（Bearer）で認証し、バックエンドで検証。
- tempIdと固有userIdの紐づけ: Firestoreの`tempIds/{tempId}`に`{ userId, expiresAt }`として保存し、有効期限で解決可否を制御。
