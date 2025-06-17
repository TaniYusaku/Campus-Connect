import type { MiddlewareHandler } from 'hono';
import { getAuth } from 'firebase-admin/auth';
import type { DecodedIdToken } from 'firebase-admin/auth';

// Honoのコンテキストに型定義を追加
// userプロパティにデコード済みトークンを格納できるようにする
declare module 'hono' {
  interface ContextVariableMap {
    user: DecodedIdToken;
  }
}

export const authMiddleware: MiddlewareHandler = async (c, next) => {
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
  } catch (error) {
    console.error('Token verification failed:', error);
    return c.json({ error: 'Unauthorized: Invalid token' }, 401);
  }
}; 