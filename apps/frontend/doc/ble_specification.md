## BLE 技術方針 / 詳細仕様（v0 方針）

1. 実装アーキテクチャ（v0）
- Flutter プラグインを使用します。
- 使用プラグイン: `flutter_blue_plus` ^2.0.0（参考: https://pub.dev/packages/flutter_blue_plus）
- スコープ: バックグラウンド動作は考慮しません（フォアグラウンドのみ）。

2. すれ違い判定
- 基本: 一度検知したら「すれ違い」成立（要件のシンプル検知）。
- フィルタ: RSSI 閾値（初期値: ≥ -80dBm）。UIから閾値を調整可能。
  同一端末の重複検知は一定期間（例: 15分）内は上書きのみ（後続）。

3. アドバタイズ（v0）
- まずは「スキャンのみ」で実装開始します。
- アドバタイズが必要になった場合は、`flutter_blue_plus` の提供有無や別プラグイン（例: `flutter_ble_peripheral`）の採用を検討します。

4. スキャン仕様
- フィルタ: 指定 Service UUID のみ。受信時に RSSI とタイムスタンプを付与。
- デバウンス: 同一 tempID は期間内1件に集約、最終検知時刻を更新。
- 保存: アプリ内（SQLite/Isar等）に直近24hのみ保持。UI はこのローカルDBから表示。

5. バックグラウンド動作（v0）
- 対応しません（フォアグラウンドでの動作のみを想定）。

6. 権限/設定
- iOS: `NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`, 必要に応じて `UIBackgroundModes` 設定。
- Android: `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_SCAN`, `ACCESS_FINE_LOCATION` (API 31+ の権限モデルに対応)。

7. サーバー連携
- v0: 端末間検知の PoC としてローカル表示を優先（サーバー送信は任意）。
- v1: 検知イベントのサマリを API へ送信（`POST /api/encounters`）。

8. 実装スコープ（v0）
- `flutter_blue_plus` によるスキャン開始/停止、権限確認/要求。
- UI: ステータス表示、スキャン結果のリスト表示（RSSI/デバイス名など）。
- 保存: 必要に応じて端末内に簡易キャッシュ（メモリ or ローカルDB）。

9. オープンな設計項目（質問）
- ペリフェラル側が必要になった場合のプラグイン: `flutter_ble_peripheral` を想定（バージョンは必要時に確定）。
- v0 はスキャンのみで開始し、アドバタイズは後続フェーズで良いですか？（合意済み）
- RSSI 閾値やフィルタ条件は固定値で開始し、後から調整で問題ありませんか？（合意済み）
