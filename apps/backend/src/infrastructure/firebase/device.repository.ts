import { getFirestore } from 'firebase-admin/firestore';
import type { DeviceUpsertPayload, IDeviceRepository } from '../../domain/repositories/device.repository.js';

const encodeTokenId = (token: string) => Buffer.from(token).toString('base64url');

export class DeviceRepository implements IDeviceRepository {
  async upsert(userId: string, payload: DeviceUpsertPayload): Promise<void> {
    const db = getFirestore();
    const now = new Date();
    const docId = encodeTokenId(payload.token);
    const ref = db.collection('users').doc(userId).collection('devices').doc(docId);
    await ref.set(
      {
        token: payload.token,
        platform: payload.platform,
        deviceId: payload.deviceId,
        appVersion: payload.appVersion,
        locale: payload.locale,
        updatedAt: now,
        createdAt: now,
      },
      { merge: true }
    );
  }

  async getTokens(userId: string): Promise<string[]> {
    const db = getFirestore();
    const snapshot = await db.collection('users').doc(userId).collection('devices').get();
    if (snapshot.empty) {
      return [];
    }
    return snapshot.docs
      .map((doc) => doc.data()?.token as string | undefined)
      .filter((token): token is string => typeof token === 'string' && token.length > 0);
  }

  async removeByToken(userId: string, token: string): Promise<void> {
    const db = getFirestore();
    const docId = encodeTokenId(token);
    await db.collection('users').doc(userId).collection('devices').doc(docId).delete();
  }
}
