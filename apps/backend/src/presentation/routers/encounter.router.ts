import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { authMiddleware } from '../middlewares/auth.middleware.js';
import { EncounterRepository } from '../../infrastructure/firebase/encounter.repository.js';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

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
  // Optional ISO string or epoch millis; server will cap to around 16 minutes if omitted
  expiresAt: z.union([z.string(), z.number()]).optional(),
});

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

    // 自分自身とのすれ違いは記録しない
    if (user.uid === encounteredUserId) {
      return c.json({ error: 'Cannot encounter yourself' }, 400);
    }

    try {
      const matchCreated = await encounterRepository.create(user.uid, encounteredUserId);
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

  // tempId -> userId を解決（期限切れは無効）
  console.log('observe recv', { reporter: user.uid, observedId, rssi, timestamp });
  const tempDoc = await db.collection('tempIds').doc(observedId).get();
  if (!tempDoc.exists) {
    console.log('observe unresolved: no tempId doc');
    return c.json({ ok: true, resolved: false }, 202);
  }
  const tdata = tempDoc.data() as { userId: string; expiresAt?: FirebaseFirestore.Timestamp } | undefined;
  if (!tdata || !tdata.expiresAt || tdata.expiresAt.toMillis() <= now.toMillis()) {
    console.log('observe unresolved: expired or missing', tdata);
    return c.json({ ok: true, resolved: false }, 202);
  }

  const otherId = tdata.userId;
  const me = user.uid as string;
  if (otherId === me) {
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

  if (bothSeen && cooledDown) {
    try {
      console.log('observe mutual: creating encounter', { u1, u2 });
      const matchCreated = await encounterRepository.create(u1, u2);
      await obsRef.set({ lastEncounteredAt: now }, { merge: true });
      return c.json({ ok: true, resolved: true, mutual: true, matchCreated }, 201);
    } catch (e) {
      console.error('observe mutual create failed', e);
      return c.json({ error: 'Failed to record mutual encounter' }, 500);
    }
  }

  return c.json({ ok: true, resolved: true, mutual: false }, 202);
});

// POST /api/encounters/register-tempid
// 広告側が現在の一時IDを登録し、観測時解決に使う
encounterRouter.post('/register-tempid', zValidator('json', registerTempIdSchema), async (c) => {
  const { uid } = c.get('user');
  const { tempId, expiresAt } = c.req.valid('json');
  const db = getFirestore();
  // Default expiry ~16 minutes from now to cover 15-min rotation plus margin
  const now = Date.now();
  let expiresMs: number;
  if (typeof expiresAt === 'number') {
    expiresMs = expiresAt;
  } else if (typeof expiresAt === 'string') {
    const parsed = Date.parse(expiresAt);
    expiresMs = isNaN(parsed) ? now + 16 * 60 * 1000 : parsed;
  } else {
    expiresMs = now + 16 * 60 * 1000;
  }
  const payload = {
    userId: uid,
    updatedAt: Timestamp.fromMillis(now),
    expiresAt: Timestamp.fromMillis(expiresMs),
  };
  await db.collection('tempIds').doc(tempId).set(payload, { merge: true });
  return c.json({ ok: true });
});
