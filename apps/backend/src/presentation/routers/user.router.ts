import { Hono } from 'hono';
import { authMiddleware } from '../middlewares/auth.middleware';
import { UserRepository } from '../../infrastructure/firebase/user.repository';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';

export const userRouter = new Hono();
const userRepository = new UserRepository();

// このルーターに属するすべてのルートに認証ミドルウェアを適用
userRouter.use('/*', authMiddleware);

const updateUserSchema = z.object({
  userName: z.string().min(1).optional(),
  // 今後更新したい項目があればここに追加
});

// GET /api/users/me
userRouter.get('/me', async (c) => {
  // ミドルウェアによってセットされたユーザー情報を取得
  const decodedToken = c.get('user');
  const userId = decodedToken.uid;

  const user = await userRepository.findById(userId);
  if (!user) {
    return c.json({ error: 'User not found' }, 404);
  }

  return c.json(user);
});

// PUT /api/users/me
userRouter.put(
  '/me',
  zValidator('json', updateUserSchema),
  async (c) => {
    const userId = c.get('user').uid;
    const updatableUserInfo = c.req.valid('json');

    try {
      const updatedUser = await userRepository.update(userId, updatableUserInfo);
      return c.json(updatedUser);
    } catch (error) {
      console.error('Failed to update user:', error);
      return c.json({ error: 'Failed to update user' }, 500);
    }
  }
);

// DELETE /api/users/me
userRouter.delete('/me', async (c) => {
  const userId = c.get('user').uid;

  try {
    await userRepository.delete(userId);
    return c.json({ message: 'User account deleted successfully' });
  } catch (error) {
    console.error('Failed to delete user:', error);
    return c.json({ error: 'Failed to delete user account' }, 500);
  }
}); 