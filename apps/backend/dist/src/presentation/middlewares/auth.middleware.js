import { getAuth } from 'firebase-admin/auth';
export const authMiddleware = async (c, next) => {
    const authHeader = c.req.header('Authorization');
    if (!authHeader) {
        return c.json({ error: 'Authorization header is missing' }, 401);
    }
    const [bearer, token] = authHeader.split(' ');
    if (bearer !== 'Bearer' || !token) {
        return c.json({ error: 'Invalid Authorization header format' }, 401);
    }
    try {
        const auth = getAuth();
        const decodedToken = await auth.verifyIdToken(token);
        // 検証成功後、コンテキストにデコード済みトークンをセット
        c.set('user', decodedToken);
        await next();
    }
    catch (error) {
        console.error('Token verification failed:', error);
        return c.json({ error: 'Unauthorized: Invalid token' }, 401);
    }
};
