import 'dotenv/config';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cert, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { logToCsv } from '../utils/csvLogger.js';

const toIsoString = (value: unknown): string => {
  if (!value) return '';
  if (value instanceof Date) return value.toISOString();
  if (typeof (value as { toDate?: () => Date }).toDate === 'function') {
    try {
      return (value as { toDate: () => Date }).toDate().toISOString();
    } catch {
      return '';
    }
  }
  return '';
};

const formatHobbies = (hobbies: unknown): string => {
  if (!Array.isArray(hobbies)) return '';
  return hobbies.map((hobby) => String(hobby)).join('|');
};

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
    const data = doc.data() as {
      id?: string;
      faculty?: string;
      grade?: number;
      gender?: string;
      mbti?: string;
      hobbies?: string[];
      createdAt?: unknown;
    };
    const userId = data.id || doc.id;
    logToCsv('users_master.csv', [
      userId,
      data.faculty ?? '',
      data.grade ?? '',
      data.gender ?? '',
      data.mbti ?? '',
      formatHobbies(data.hobbies),
      toIsoString(data.createdAt),
    ]);
  });

  console.log(`Exported ${snapshot.size} users to logs/users_master.csv`);
};

main().catch((err) => {
  console.error('Export users failed:', err);
  process.exitCode = 1;
});
