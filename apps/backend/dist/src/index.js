import 'dotenv/config';
import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { initializeApp, cert } from 'firebase-admin/app';
import serviceAccount from '../serviceAccountKey.json' assert { type: 'json' };
import { authRouter } from './presentation/routers/auth.router';
import { userRouter } from './presentation/routers/user.router';
import { encounterRouter } from './presentation/routers/encounter.router';
try {
    initializeApp({
        credential: cert(serviceAccount),
    });
    console.log('Firebase Admin SDK initialized successfully.');
}
catch (error) {
    console.error('Firebase Admin SDK initialization error:', error);
}
const app = new Hono().basePath('/api');
app.get('/', (c) => {
    return c.text('Hello Campus Connect API!');
});
app.get('/test', (c) => {
    return c.text('Test route is working!');
});
const api = new Hono();
// ↓↓↓↓ ルーターを登録 ↓↓↓↓
app.route('/auth', authRouter);
app.route('/users', userRouter);
app.route('/encounters', encounterRouter);
const port = 3000;
console.log(`Server is running on port ${port}`);
serve({
    fetch: app.fetch,
    port
});
