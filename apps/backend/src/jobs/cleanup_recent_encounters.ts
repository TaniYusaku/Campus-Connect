import { getFirestore, Timestamp, FieldPath } from 'firebase-admin/firestore';

/**
 * Deletes documents in collectionGroup `recentEncounters` whose
 * `lastEncounteredAt` is older than the given threshold.
 * Returns the number of documents deleted in this invocation.
 */
export async function cleanupRecentEncounters(options?: {
  olderThanMs?: number;
  batchLimit?: number;
  maxBatches?: number;
}): Promise<number> {
  const olderThanMs = options?.olderThanMs ?? 24 * 60 * 60 * 1000; // 24h
  const batchLimit = options?.batchLimit ?? 400; // stay below 500 writes per batch
  const maxBatches = options?.maxBatches ?? 10; // safety guard

  const db = getFirestore();
  const cutoff = Timestamp.fromMillis(Date.now() - olderThanMs);

  let totalDeleted = 0;
  try {
    for (let i = 0; i < maxBatches; i++) {
      const snap = await db
        .collectionGroup('recentEncounters')
        .where('lastEncounteredAt', '<', cutoff)
        .limit(batchLimit)
        .get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      totalDeleted += snap.size;
    }
    return totalDeleted;
  } catch (e: any) {
    if (e?.code === 9) {
      console.warn('[cleanup] collectionGroup index missing, falling back to per-user cleanup. Consider creating an index or enabling Firestore TTL.');
      const fallbackDeleted = await cleanupRecentEncountersByUser({ olderThanMs, perUserBatchLimit: 200, userPageSize: 50, maxUsers: 500 });
      return fallbackDeleted;
    }
    throw e;
  }
}

/**
 * Kicks off a periodic cleanup job.
 * intervalMinutes: how often to run (default 60 min).
 */
export function startRecentEncountersCleanup(intervalMinutes = 60) {
  const intervalMs = Math.max(1, intervalMinutes) * 60 * 1000;
  const run = async () => {
    try {
      const deleted = await cleanupRecentEncounters();
      if (deleted > 0) {
        console.log(`[cleanup] recentEncounters deleted: ${deleted}`);
      } else {
        console.log('[cleanup] recentEncounters nothing to delete');
      }
    } catch (e) {
      console.error('[cleanup] recentEncounters failed', e);
    }
  };
  // initial delay to avoid hammering on boot
  setTimeout(run, 30 * 1000);
  setInterval(run, intervalMs);
}

/**
 * Fallback: iterate users and delete old entries from each user's
 * `recentEncounters` subcollection.
 */
async function cleanupRecentEncountersByUser(options?: {
  olderThanMs?: number;
  perUserBatchLimit?: number;
  userPageSize?: number;
  maxUsers?: number;
}): Promise<number> {
  const db = getFirestore();
  const olderThanMs = options?.olderThanMs ?? 24 * 60 * 60 * 1000;
  const perUserBatchLimit = options?.perUserBatchLimit ?? 200;
  const userPageSize = options?.userPageSize ?? 50;
  const maxUsers = options?.maxUsers ?? 500;
  const cutoff = Timestamp.fromMillis(Date.now() - olderThanMs);

  let totalDeleted = 0;
  let processedUsers = 0;
  let lastDocId: string | undefined = undefined;

  while (processedUsers < maxUsers) {
    let usersQuery = db.collection('users').orderBy(FieldPath.documentId()).limit(userPageSize);
    if (lastDocId) {
      usersQuery = usersQuery.startAfter(lastDocId);
    }
    const usersSnap = await usersQuery.get();
    if (usersSnap.empty) break;

    for (const userDoc of usersSnap.docs) {
      processedUsers++;
      // delete old encounters for this user in small batches
      // loop until no more old docs or we've hit perUserBatchLimit for this pass
      while (true) {
        const oldSnap = await userDoc.ref
          .collection('recentEncounters')
          .where('lastEncounteredAt', '<', cutoff)
          .limit(perUserBatchLimit)
          .get();
        if (oldSnap.empty) break;
        const batch = db.batch();
        oldSnap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        totalDeleted += oldSnap.size;
        // If we deleted less than the limit, likely no more for this user
        if (oldSnap.size < perUserBatchLimit) break;
      }
      if (processedUsers >= maxUsers) break;
    }
    lastDocId = usersSnap.docs[usersSnap.docs.length - 1].id;
  }
  return totalDeleted;
}
