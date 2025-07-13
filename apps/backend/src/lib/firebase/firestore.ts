import { getFirestore } from 'firebase-admin/firestore';

export type TemporaryId = {
  userId: string;
  tempId: string;
  expirationAt: FirebaseFirestore.Timestamp;
};

export const findUserByTemporaryId = async (tempId: string): Promise<TemporaryId | null> => {
  const db = getFirestore();
  const now = new Date();
  const snapshot = await db.collection('temporary_ids')
    .where('tempId', '==', tempId)
    .get();
  if (snapshot.empty) {
    return null;
  }
  const doc = snapshot.docs[0].data() as TemporaryId;
  // 有効期限切れの場合はnullを返す
  if (doc.expirationAt.toDate() <= now) {
    return null;
  }
  return doc;
}; 