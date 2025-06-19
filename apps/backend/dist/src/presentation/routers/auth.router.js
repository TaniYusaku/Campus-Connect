import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { UserRepository } from '../../infrastructure/firebase/user.repository';
// ユーザー登録の入力値スキーマ
const registerSchema = z.object({
    userName: z.string().min(1),
    email: z.string().email(),
    password: z.string().min(6),
    faculty: z.string().optional(),
    grade: z.number().optional(),
});
const loginSchema = z.object({
    email: z.string().email(),
    password: z.string(),
});
const userRepository = new UserRepository();
export const authRouter = new Hono();
// ユーザー登録エンドポイント
authRouter.post('/register', zValidator('json', registerSchema), async (c) => {
    const { userName, email, password, faculty, grade } = c.req.valid('json');
    try {
        const user = await userRepository.createUser({ userName, email, password, faculty, grade });
        // パスワードなど不要な情報は返さない
        const { id, userName: name, email: userEmail } = user;
        return c.json({ id, userName: name, email: userEmail }, 201);
    }
    catch (error) {
        // メールアドレスが既に使われている場合
        if (error.code === 'auth/email-already-exists') {
            return c.json({ error: 'This email is already in use' }, 409);
        }
        console.error(error);
        return c.json({ error: 'Failed to create user' }, 500);
    }
});
// ユーザーログインエンドポイント
authRouter.post('/login', zValidator('json', loginSchema), async (c) => {
    const { email, password } = c.req.valid('json');
    try {
        const { token, user } = await userRepository.signIn(email, password);
        return c.json({ token, user });
    }
    catch (error) {
        // axiosのエラーか、Firebase REST APIのエラーかを確認
        const errorCode = error.response?.data?.error?.message;
        if (errorCode === 'INVALID_PASSWORD' || errorCode === 'EMAIL_NOT_FOUND') {
            return c.json({ error: 'Invalid email or password' }, 401); // Unauthorized
        }
        console.error(error);
        return c.json({ error: 'Failed to login' }, 500);
    }
});
