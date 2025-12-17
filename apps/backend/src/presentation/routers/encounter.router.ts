import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { EncounterRepository } from '../../infrastructure/firebase/encounter.repository.js';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logWithUserDetails, nowJstString, toJstString } from '../../utils/csvLogger.js';

const encounterSchema = z.object({
  encounteredUserId: z.string().min(1),
});

const observeSchema = z.object({
  observedId: z.string().min(1),
  rssi: z.number(),
  timestamp: z.string().optional(),
});

const registerTempIdSchema = z.object({
  tempId: z.string().min(1),
  // Deprecated: server now ignores client-provided expiry and relies on its own clock.
  expiresAt: z.union([z.string(), z.number()]).optional(),
});

// tempId の寿命: 広告のローテーション（5分）より少し長めに保持して解決漏れを防ぐ
const tempIdTtlMinutes = Math.max(1, Number(process.env.TEMPID_TTL_MINUTES ?? '6'));

export const encounterRouter = new Hono();
const encounterRepository = new EncounterRepository();

// このルーターに属するAPIはすべて認証が必要
encounterRouter.use('/*', authMiddleware);

// POST /api/encounters
encounterRouter.post(
  '/',
  zValidator('json', encounterSchema),
  async (c) => {
    const user = c.get('user');
    const { encounteredUserId } = c.req.valid('json');
    const db = getFirestore();

    // 自分自身とのすれ違いは記録しない
    if (user.uid === encounteredUserId) {
      return c.json({ error: 'Cannot encounter yourself' }, 400);
    }

    try {
      const matchCreated = await encounterRepository.create(user.uid, encounteredUserId);
      try {
        const [u1, u2] = [user.uid as string, encounteredUserId].sort();
        const doc = await db.collection('users').doc(u1).collection('recentEncounters').doc(u2).get();
        const count = doc.exists ? (doc.data() as { count?: number } | undefined)?.count : undefined;
        await logWithUserDetails(
          'encounters.csv',
          [nowJstString(), u1, u2, count ?? ''],
          [
            { role: 'User1', userId: u1 },
            { role: 'User2', userId: u2 },
          ],
          'encounter:create',
        );
      } catch (err) {
        console.error('Failed to log encounter CSV (manual):', err);
      }
      return c.json({ message: 'Encounter recorded successfully', matchCreated }, 201);
    } catch (error) {
      console.error('Failed to record encounter:', error);
      return c.json({ error: 'Failed to record encounter' }, 500);
    }
  }
);

// POST /api/encounters/observe
// 端末が観測した一時IDを送る: 相互観測（短時間内の双方向）になった時のみ Encounter を作成
encounterRouter.post('/observe', zValidator('json', observeSchema), async (c) => {
  const user = c.get('user');
  const { observedId, rssi, timestamp } = c.req.valid('json');
  const db = getFirestore();
  const now = Timestamp.now();
  const serverTimestamp = nowJstString();
  let resolvedUserId = '';
  const logObservation = async (status: string) => {
    await logWithUserDetails('ble_observations.csv', [
      serverTimestamp,
      user.uid,
      observedId,
      resolvedUserId,
      status,
      rssi,
      timestamp ?? '',
    ], [
      { role: 'Reporter', userId: user.uid },
      { role: 'Resolved', userId: resolvedUserId || undefined },
    ], 'ble_observation');
  };

  // tempId -> userId を解決（期限切れは無効）
  console.log('observe recv', { reporter: user.uid, observedId, rssi, timestamp });
  const tempDoc = await db.collection('tempIds').doc(observedId).get();
  if (!tempDoc.exists) {
    console.log('observe unresolved: no tempId doc');
    await logObservation('not_found');
    return c.json({ ok: true, resolved: false }, 202);
  }
  const tdata = tempDoc.data() as { userId: string; expiresAt?: FirebaseFirestore.Timestamp } | undefined;
  if (!tdata || !tdata.expiresAt || tdata.expiresAt.toMillis() <= now.toMillis()) {
    console.log('observe unresolved: expired or missing', tdata);
    resolvedUserId = tdata?.userId ?? '';
    await logObservation('expired');
    return c.json({ ok: true, resolved: false }, 202);
  }

  const otherId = tdata.userId;
  const me = user.uid as string;
  resolvedUserId = otherId;
  if (otherId === me) {
    await logObservation('self');
    return c.json({ ok: true, resolved: true, self: true }, 200);
  }

  // 相互観測の判定用ドキュメント（対のユーザーID順で1ドキュメント）
  const [u1, u2] = [me, otherId].sort();
  const fromU1toU2 = me === u1;
  const obsRef = db.collection('observations').doc(`${u1}_${u2}`);
  const field = fromU1toU2 ? 'lastU1ToU2' : 'lastU2ToU1';
  await obsRef.set({ [field]: now, u1, u2, updatedAt: now }, { merge: true });

  // 取り出して相互観測か確認
  const snap = await obsRef.get();
  const o = snap.data() as {
    lastU1ToU2?: FirebaseFirestore.Timestamp;
    lastU2ToU1?: FirebaseFirestore.Timestamp;
    lastEncounteredAt?: FirebaseFirestore.Timestamp;
  } | undefined;
  const mutualWindowMs = 5 * 60 * 1000; // 5分以内の双方向観測で成立（調整可）
  const nowMs = now.toMillis();
  const a = o?.lastU1ToU2?.toMillis();
  const b = o?.lastU2ToU1?.toMillis();
  const lastEnc = o?.lastEncounteredAt?.toMillis();

  const bothSeen = a != null && b != null && Math.abs(a - b) <= mutualWindowMs && (nowMs - Math.min(a, b)) <= mutualWindowMs;
  const cooledDown = lastEnc == null || (nowMs - lastEnc) > mutualWindowMs;

  console.log('observe resolved', {
    reporter: me,
    observedUser: otherId,
    fromU1toU2,
    lastU1ToU2: a,
    lastU2ToU1: b,
    mutualCandidate: bothSeen,
    cooledDown,
  });

  if (bothSeen && cooledDown) {
    let shouldCreate = false;
    try {
      shouldCreate = await db.runTransaction<boolean>(async (tx) => {
        const latest = await tx.get(obsRef);
        const data = latest.data() as {
          lastEncounteredAt?: FirebaseFirestore.Timestamp;
        } | undefined;
        const lastEncTx = data?.lastEncounteredAt?.toMillis();
        if (lastEncTx == null || nowMs - lastEncTx > mutualWindowMs) {
          tx.set(obsRef, { lastEncounteredAt: now }, { merge: true });
          return true;
        }
        return false;
      });
    } catch (e) {
      console.error('observe mutual transaction failed', e);
      return c.json({ error: 'Failed to record mutual encounter' }, 500);
    }
    if (shouldCreate) {
      try {
        console.log('observe mutual: creating encounter', { u1, u2 });
        const matchCreated = await encounterRepository.create(u1, u2);
        await logObservation('mutual_created');
        try {
          const doc = await db.collection('users').doc(u1).collection('recentEncounters').doc(u2).get();
          const count = doc.exists ? (doc.data() as { count?: number } | undefined)?.count : undefined;
          await logWithUserDetails(
            'encounters.csv',
            [nowJstString(), u1, u2, count ?? ''],
            [
              { role: 'User1', userId: u1 },
              { role: 'User2', userId: u2 },
            ],
            'encounter:mutual',
          );
        } catch (logErr) {
          console.error('Failed to log encounter CSV (mutual observe):', logErr);
        }
        return c.json({ ok: true, resolved: true, mutual: true, matchCreated }, 201);
      } catch (e) {
        console.error('observe mutual create failed', e);
        await logObservation('mutual_error');
        return c.json({ error: 'Failed to record mutual encounter' }, 500);
      }
    }
  }
  await logObservation('resolved_only');

  return c.json({ ok: true, resolved: true, mutual: false }, 202);
});

// POST /api/encounters/register-tempid
// 広告側が現在の一時IDを登録し、観測時解決に使う
encounterRouter.post('/register-tempid', zValidator('json', registerTempIdSchema), async (c) => {
  const { uid } = c.get('user');
  const { tempId, expiresAt: clientExpiresAt } = c.req.valid('json');
  const db = getFirestore();
  // Server-trusted expiry: ignore client clock to avoid skew issues.
  const now = Date.now();
  const expiresMs = now + tempIdTtlMinutes * 60 * 1000;
  const payload = {
    userId: uid,
    updatedAt: Timestamp.fromMillis(now),
    expiresAt: Timestamp.fromMillis(expiresMs),
  };
  console.log('register-tempid request', {
    uid,
    tempId,
    expiresAtMs: expiresMs,
    clientExpiresAt,
  });
  try {
    await db.collection('tempIds').doc(tempId).set(payload, { merge: true });
    console.log('register-tempid stored', { uid, tempId });
    await logWithUserDetails(
      'tempid_registrations.csv',
      [nowJstString(), uid, tempId, toJstString(new Date(expiresMs))],
      [{ role: 'User', userId: uid }],
      'tempid:register',
    );
    return c.json({ ok: true, expiresAt: toJstString(new Date(expiresMs)) });
  } catch (err) {
    console.error('register-tempid error', { uid, tempId, err });
    throw err;
  }
});
