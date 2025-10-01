import 'dotenv/config';

import { Hono } from 'hono'
import { serve } from '@hono/node-server'
import { initializeApp, cert, type ServiceAccount } from 'firebase-admin/app'
import serviceAccount from '../serviceAccountKey.json' assert { type: 'json' }
import { authRouter } from './presentation/routers/auth.router'
import { userRouter } from './presentation/routers/user.router'
import { encounterRouter } from './presentation/routers/encounter.router'

try {
    const sa: any = serviceAccount as any;
    const defaultBucket = sa?.project_id ? `${sa.project_id}.appspot.com` : undefined;
    const bucketName = process.env.FIREBASE_STORAGE_BUCKET || defaultBucket;
    initializeApp({
        credential: cert(serviceAccount as ServiceAccount),
        storageBucket: bucketName,
    });
    console.log('Firebase Admin SDK initialized successfully.');
    if (!bucketName) {
      console.warn('Warning: No storage bucket configured. Set FIREBASE_STORAGE_BUCKET or ensure service account has project_id.');
    } else {
      console.log(`Using storage bucket: ${bucketName}`);
    }
} catch (error) {
    console.error('Firebase Admin SDK initialization error:', error);
}

const app = new Hono().basePath('/api')

// simple request logger for debugging connectivity
app.use('*', async (c, next) => {
  console.log(`${c.req.method} ${c.req.path}`)
  return next()
})

app.get('/', (c) => {
    return c.text('Hello Campus Connect API!')
})

app.get('/test', (c) => {
    return c.text('Test route is working!')
  })
// ↓↓↓↓ ルーターを登録 ↓↓↓↓
app.route('/auth', authRouter);
app.route('/users', userRouter);
app.route('/encounters', encounterRouter);

const port = 3000
console.log(`Server is running on http://0.0.0.0:${port}`)

serve({
    fetch: app.fetch,
    port,
    // Bind to all interfaces so physical devices can reach the server
    hostname: '0.0.0.0',
})
