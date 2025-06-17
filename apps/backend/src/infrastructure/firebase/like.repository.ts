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
} 