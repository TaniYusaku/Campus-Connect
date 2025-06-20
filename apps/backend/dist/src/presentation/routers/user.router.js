import { Hono } from 'hono';
import { authMiddleware } from '../middlewares/auth.middleware';
import { UserRepository } from '../../infrastructure/firebase/user.repository';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { LikeRepository } from '../../infrastructure/firebase/like.repository';
import { EncounterRepository } from '../../infrastructure/firebase/encounter.repository';
import { MatchRepository } from '../../infrastructure/firebase/match.repository';
import { BlockRepository } from '../../infrastructure/firebase/block.repository';
export const userRouter = new Hono();
const userRepository = new UserRepository();
const likeRepository = new LikeRepository();
const encounterRepository = new EncounterRepository();
const matchRepository = new MatchRepository();
const blockRepository = new BlockRepository();
// このルーターに属するすべてのルートに認証ミドルウェアを適用
userRouter.use('/*', authMiddleware);
const updateUserSchema = z.object({
    userName: z.string().min(1).optional(),
    faculty: z.string().optional(),
    grade: z.number().optional(),
    profilePhotoUrl: z.string().url().optional(),
    bio: z.string().optional(),
    hobbies: z.array(z.string()).optional(),
    snsLinks: z.record(z.string()).optional(),
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
userRouter.put('/me', zValidator('json', updateUserSchema), async (c) => {
    const userId = c.get('user').uid;
    const updatableUserInfo = c.req.valid('json');
    try {
        const updatedUser = await userRepository.update(userId, updatableUserInfo);
        return c.json(updatedUser);
    }
    catch (error) {
        console.error('Failed to update user:', error);
        return c.json({ error: 'Failed to update user' }, 500);
    }
});
// DELETE /api/users/me
userRouter.delete('/me', async (c) => {
    const userId = c.get('user').uid;
    try {
        await userRepository.delete(userId);
        return c.json({ message: 'User account deleted successfully' });
    }
    catch (error) {
        console.error('Failed to delete user:', error);
        return c.json({ error: 'Failed to delete user account' }, 500);
    }
});
userRouter.post('/:userId/like', authMiddleware, async (c) => {
    const likingUser = c.get('user');
    const likedUserId = c.req.param('userId');
    if (likingUser.uid === likedUserId) {
        return c.json({ error: 'You cannot like yourself.' }, 400);
    }
    try {
        await likeRepository.create(likingUser.uid, likedUserId);
        return c.json({ message: 'Successfully liked user.' }, 201);
    }
    catch (error) {
        console.error('Failed to like user:', error);
        return c.json({ error: 'Failed to like user.' }, 500);
    }
});
// GET /api/users/encounters
userRouter.get('/encounters', async (c) => {
    const userId = c.get('user').uid;
    // ブロックしているユーザーIDのリストを取得
    const blockedUserIds = await blockRepository.findAllIds(userId);
    // すれ違ったユーザー一覧を取得
    const users = await encounterRepository.findRecentEncounteredUsers(userId);
    // ブロック済みユーザーを除外
    const safeUsers = users.filter(user => !blockedUserIds.includes(user.id)).map(({ email, ...rest }) => rest);
    return c.json(safeUsers);
});
// GET /api/users/friends
userRouter.get('/friends', async (c) => {
    const userId = c.get('user').uid;
    const blockedUserIds = await blockRepository.findAllIds(userId);
    const friendIds = await matchRepository.findAll(userId);
    // ブロック済みユーザーを除外
    const filteredIds = friendIds.filter(id => !blockedUserIds.includes(id));
    const users = await userRepository.findByIds(filteredIds);
    const safeUsers = users.map(({ email, ...rest }) => rest);
    return c.json(safeUsers);
});
// GET /api/users/blocked
userRouter.get('/blocked', async (c) => {
    const userId = c.get('user').uid;
    const blockedIds = await blockRepository.findAll(userId);
    const users = await userRepository.findByIds(blockedIds);
    const safeUsers = users.map(({ email, ...rest }) => rest);
    return c.json(safeUsers);
});
// 特定ユーザーのブロック/ブロック解除
userRouter.post('/:userId/block', async (c) => {
    const blockerId = c.get('user').uid;
    const blockedId = c.req.param('userId');
    if (blockerId === blockedId) {
        return c.json({ error: 'You cannot block yourself.' }, 400);
    }
    await blockRepository.create(blockerId, blockedId);
    return c.json({ message: 'User blocked successfully' }, 201);
});
userRouter.delete('/:userId/block', async (c) => {
    const blockerId = c.get('user').uid;
    const blockedId = c.req.param('userId');
    await blockRepository.delete(blockerId, blockedId);
    return c.json({ message: 'User unblocked successfully' });
});
