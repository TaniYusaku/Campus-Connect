import { getFirestore } from "firebase-admin/firestore";
export class LikeRepository {
    async create(likingUserId, likedUserId) {
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
    async exists(likingUserId, likedUserId) {
        const db = getFirestore();
        const likeDocRef = db.collection('users').doc(likingUserId).collection('likes').doc(likedUserId);
        const doc = await likeDocRef.get();
        return doc.exists;
    }
}
