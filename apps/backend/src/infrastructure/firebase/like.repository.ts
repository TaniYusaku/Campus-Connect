import { getFirestore } from "firebase-admin/firestore";
import type { ILikeRepository } from "../../domain/repositories/like.repository";

export class LikeRepository implements ILikeRepository {
  async create(likingUserId: string, likedUserId: string): Promise<void> {
    const db = getFirestore();
    const likeDocRef = db
      .collection('users')
      .doc(likingUserId)
      .collection('likes')
      .doc(likedUserId);

    await likeDocRef.set({
      createdAt: new Date(),
    });
  }

  async exists(likingUserId: string, likedUserId: string): Promise<boolean> {
    const db = getFirestore();
    const likeDocRef = db.collection('users').doc(likingUserId).collection('likes').doc(likedUserId);
    const doc = await likeDocRef.get();
    return doc.exists;
  }

  async findRecent(likingUserId: string, since: Date): Promise<string[]> {
    const db = getFirestore();
    const likesCol = db.collection('users').doc(likingUserId).collection('likes');
    const snap = await likesCol
      .where('createdAt', '>=', since)
      .orderBy('createdAt', 'desc')
      .limit(200)
      .get();
    if (snap.empty) return [];
    return snap.docs.map((d) => d.id);
  }

  async delete(likingUserId: string, likedUserId: string): Promise<void> {
    const db = getFirestore();
    const likeDocRef = db
      .collection('users')
      .doc(likingUserId)
      .collection('likes')
      .doc(likedUserId);
    await likeDocRef.delete();
  }
}
