import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { authMiddleware } from '../middlewares/auth.middleware';
import { EncounterRepository } from '../../infrastructure/firebase/encounter.repository';

const encounterSchema = z.object({
  encounteredUserId: z.string().min(1),
});

const observeSchema = z.object({
  observedId: z.string().min(1),
  rssi: z.number(),
  timestamp: z.string().optional(),
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
// 端末が観測した一時IDを送る想定の仮実装（今は受け取りのみ）
encounterRouter.post('/observe', zValidator('json', observeSchema), async (c) => {
  const user = c.get('user');
  const { observedId, rssi, timestamp } = c.req.valid('json');
  console.log('observe', { reporter: user.uid, observedId, rssi, timestamp });
  // TODO: observedId -> userId の解決とすれ違い記録ロジックを追加
  return c.json({ ok: true }, 201);
});
