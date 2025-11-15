// ------------------------------
// index.ts (Node.js v22対応・完全版)
// ------------------------------

import 'dotenv/config';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { initializeApp, cert, type ServiceAccount } from 'firebase-admin/app';

// ===== ルーター =====
// NodeNext モードでは .js 拡張子が必要
import { authRouter } from './presentation/routers/auth.router.js';
import { userRouter } from './presentation/routers/user.router.js';
import { encounterRouter } from './presentation/routers/encounter.router.js';
import { announcementRouter } from './presentation/routers/announcement.router.js';

// ===== 定期ジョブ =====
import { startRecentEncountersCleanup } from './jobs/cleanup_recent_encounters.js';
import { startTempIdsCleanup } from './jobs/cleanup_temp_ids.js';

// ------------------------------
// Firebase Admin SDK 初期化
// ------------------------------
try {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  const serviceAccountPath = resolve(__dirname, '../serviceAccountKey.json');
  const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf-8'));

  const sa = serviceAccount as any;
  const defaultBucket = sa?.project_id ? `${sa.project_id}.appspot.com` : undefined;
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET || defaultBucket;

  initializeApp({
    credential: cert(serviceAccount as ServiceAccount),
    storageBucket: bucketName,
  });

  console.log('✅ Firebase Admin SDK initialized successfully.');
  if (!bucketName) {
    console.warn('⚠️  No storage bucket configured. Set FIREBASE_STORAGE_BUCKET or ensure service account has project_id.');
  } else {
    console.log(`🪣 Using storage bucket: ${bucketName}`);
  }
} catch (error) {
  console.error('❌ Firebase Admin SDK initialization error:', error);
}

// ------------------------------
// Hono アプリ設定
// ------------------------------
const app = new Hono().basePath('/api');

// すべてのリクエストをログ（デバッグ用）
app.use('*', async (c, next) => {
  console.log(`${c.req.method} ${c.req.path}`);
  return next();
});

// 動作確認ルート
app.get('/', (c) => c.text('Hello Campus Connect API!'));
app.get('/test', (c) => c.text('Test route is working!'));

// ルーター登録
app.route('/auth', authRouter);
app.route('/users', userRouter);
app.route('/encounters', encounterRouter);
app.route('/announcements', announcementRouter);

// ------------------------------
// サーバー起動
// ------------------------------
const port = Number(process.env.PORT ?? 3000);
console.log(`🚀 Server is running on http://0.0.0.0:${port}`);

serve({
  fetch: app.fetch,
  port,
  hostname: '0.0.0.0', // 全インターフェースで待ち受け
});

// ------------------------------
// 定期クリーンアップ処理
// ------------------------------
const cleanupIntervalMin = Number(process.env.CLEANUP_INTERVAL_MINUTES ?? '60');
const disableCleanup =
  process.env.DISABLE_CLEANUP === '1' ||
  cleanupIntervalMin <= 0 ||
  Number.isNaN(cleanupIntervalMin);

if (disableCleanup) {
  console.log('🧹 recentEncounters cleanup is disabled');
} else {
  console.log(`🧹 Starting recentEncounters cleanup every ${cleanupIntervalMin} minutes`);
  startRecentEncountersCleanup(cleanupIntervalMin);
}

const tempIdsIntervalMin = Number(process.env.TEMPIDS_CLEANUP_INTERVAL_MINUTES ?? '15');
const disableTempIdsCleanup =
  process.env.DISABLE_TEMPIDS_CLEANUP === '1' ||
  tempIdsIntervalMin <= 0 ||
  Number.isNaN(tempIdsIntervalMin);

if (disableTempIdsCleanup) {
  console.log('🧩 tempIds cleanup is disabled');
} else {
  console.log(`🧩 Starting tempIds cleanup every ${tempIdsIntervalMin} minutes`);
  startTempIdsCleanup(tempIdsIntervalMin);
}
