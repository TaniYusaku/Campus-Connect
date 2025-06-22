import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { authMiddleware } from '../middlewares/auth.middleware';
import { EncounterRepository } from '../../infrastructure/firebase/encounter.repository';

const encounterSchema = z.object({
  encounteredUserId: z.string().min(1),
});

const encounterTidSchema = z.array(z.object({
  tid: z.string().min(1),
  rssi: z.number(),
  timestamp: z.number(),
}));

export const encounterRouter = new Hono();
const encounterRepository = new EncounterRepository();

// このルーターに属するAPIはすべて認証が必要
encounterRouter.use('/*', authMiddleware);

// POST /api/encounters
encounterRouter.post(
  '/',
  zValidator('json', encounterTidSchema),
  async (c) => {
    const user = c.get('user');
    const scanResults = c.req.valid('json');
    const tids = scanResults.map((item: any) => item.tid);
    try {
      // 有効なTIDからUIDを特定
      const encounteredUids = await encounterRepository.findUidsByTids(tids);
      // 自分自身との遭遇は除外
      const filteredUids = encounteredUids.filter(uid => uid !== user.uid);
      // 遭遇記録を作成
      for (const encounteredUserId of filteredUids) {
        await encounterRepository.create(user.uid, encounteredUserId);
      }
      return c.json({ message: 'Encounters recorded successfully' }, 201);
    } catch (error) {
      console.error('Failed to record encounters:', error);
      return c.json({ error: 'Failed to record encounters' }, 500);
    }
  }
); 