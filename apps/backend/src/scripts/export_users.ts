import 'dotenv/config';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import type { User } from '../domain/entities/user.entity.js';
import { logUserSnapshot } from '../utils/csvLogger.js';

const bootstrapFirebase = () => {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  const serviceAccountPath = resolve(__dirname, '../../serviceAccountKey.json');
  const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf-8'));
  const sa = serviceAccount as any;
  const defaultBucket = sa?.project_id ? `${sa.project_id}.appspot.com` : undefined;
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET || defaultBucket;

  initializeApp({
    credential: cert(serviceAccount as ServiceAccount),
    storageBucket: bucketName,
  });
};

const main = async () => {
  bootstrapFirebase();
  const db = getFirestore();
  const snapshot = await db.collection('users').get();

  snapshot.forEach((doc) => {
    const data = doc.data() as Partial<User> & { id?: string };
    const userId = data.id || doc.id;
    logUserSnapshot({ ...data, id: userId }, 'export');
  });

  console.log(`Exported ${snapshot.size} users to logs/users_master.csv`);
};

main().catch((err) => {
  console.error('Export users failed:', err);
  process.exitCode = 1;
});
