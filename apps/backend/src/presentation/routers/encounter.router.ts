import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { authMiddleware } from '../middlewares/auth.middleware';
import { EncounterRepository } from '../../infrastructure/firebase/encounter.repository';
import { findUserByTemporaryId } from '../../lib/firebase/firestore';

const encounterSchema = z.object({
  encounteredUserId: z.string().min(1),
});

const encounterTempIdSchema = z.object({
  encounteredTempId: z.string().min(1),
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

// POST /api/encounters (一時ID照合方式)
encounterRouter.post(
  '/',
  zValidator('json', encounterTempIdSchema),
  async (c) => {
    const user = c.get('user');
    const { encounteredTempId } = c.req.valid('json');

    // 一時IDから相手ユーザーを検索
    let encounteredUserDoc;
    try {
      encounteredUserDoc = await findUserByTemporaryId(encounteredTempId);
    } catch (error) {
      console.error('Failed to find user by tempId:', error);
      return c.json({ error: 'Internal Server Error' }, 500);
    }

    // 無効なID・有効期限切れ・自分自身の場合は何もしない
    if (!encounteredUserDoc || encounteredUserDoc.userId === user.uid) {
      return c.json({ message: 'Encounter processed successfully.' });
    }

    // すれ違い記録
    try {
      const matchCreated = await encounterRepository.create(user.uid, encounteredUserDoc.userId);
      return c.json({ message: 'Encounter processed successfully.', matchCreated });
    } catch (error) {
      console.error('Failed to record encounter:', error);
      return c.json({ error: 'Failed to record encounter' }, 500);
    }
  }
); 