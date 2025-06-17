import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { authMiddleware } from '../middlewares/auth.middleware';
import { EncounterRepository } from '../../infrastructure/firebase/encounter.repository';

const encounterSchema = z.object({
  encounteredUserId: z.string().min(1),
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