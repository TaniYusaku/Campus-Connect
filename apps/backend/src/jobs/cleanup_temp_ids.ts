import { getFirestore, Timestamp } from 'firebase-admin/firestore';

/**
 * Deletes expired tempIds where `expiresAt` <= now.
 * Returns number of documents deleted.
 */
export async function cleanupTempIds(options?: {
  batchLimit?: number;
  maxBatches?: number;
}): Promise<number> {
  const batchLimit = options?.batchLimit ?? 400; // under 500 writes per batch
  const maxBatches = options?.maxBatches ?? 10;

  const db = getFirestore();
  const now = Timestamp.now();
  let totalDeleted = 0;

  for (let i = 0; i < maxBatches; i++) {
    const snap = await db
      .collection('tempIds')
      .where('expiresAt', '<=', now)
      .limit(batchLimit)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    totalDeleted += snap.size;
  }

  return totalDeleted;
}

export function startTempIdsCleanup(intervalMinutes = 15) {
  const intervalMs = Math.max(1, intervalMinutes) * 60 * 1000;
  const run = async () => {
    try {
      const deleted = await cleanupTempIds();
      if (deleted > 0) {
        console.log(`[cleanup] tempIds deleted: ${deleted}`);
      }
    } catch (e) {
      console.error('[cleanup] tempIds failed', e);
    }
  };
  // initial delay
  setTimeout(run, 20 * 1000);
  setInterval(run, intervalMs);
}

