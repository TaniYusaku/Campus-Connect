import { Hono } from 'hono';
import { v4 as uuidv4 } from 'uuid';
import { getFirestore } from 'firebase-admin/firestore';

export type TemporaryId = {
  userId: string;
  tempId: string;
  expirationAt: FirebaseFirestore.Timestamp;
};

export const createTemporaryId = async (userId: string, tempId: string, expirationAt: Date): Promise<void> => {
  const db = getFirestore();
  const temporaryIdData: TemporaryId = {
    userId,
    tempId,
    expirationAt: FirebaseFirestore.Timestamp.fromDate(expirationAt),
  };
  await db.collection('temporary_ids').add(temporaryIdData);
};
import { authMiddleware } from '../../presentation/middlewares/auth.middleware';

const app = new Hono();

// 認証ミドルウェアを適用
app.use('/*', authMiddleware);

app.post('/', async (c) => {
  // ミドルウェアでセットされたuserからuserIdを取得
  const user = c.get('user');
  const userId = user.uid;

  if (!userId) {
    return c.json({ error: 'User ID not found in token' }, 400);
  }

  // 一時ID生成
  const tempId = uuidv4();
  // 有効期限（15分後）
  const expirationAt = new Date();
  expirationAt.setMinutes(expirationAt.getMinutes() + 15);

  try {
    await createTemporaryId(userId, tempId, expirationAt);
    return c.json({ tempId });
  } catch (error) {
    console.error('Failed to create temporary ID:', error);
    return c.json({ error: 'Internal Server Error' }, 500);
  }
});

export default app; 