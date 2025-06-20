import { getFirestore } from 'firebase-admin/firestore';
export class BlockRepository {
    async findAll(userId) {
        const db = getFirestore();
        const blockedCol = db.collection('users').doc(userId).collection('blockedUsers');
        const snapshot = await blockedCol.get();
        if (snapshot.empty) {
            return [];
        }
        return snapshot.docs.map(doc => doc.id);
    }
    async findAllIds(userId) {
        const db = getFirestore();
        const blockedCol = db.collection('users').doc(userId).collection('blockedUsers');
        const snapshot = await blockedCol.get();
        if (snapshot.empty) {
            return [];
        }
        return snapshot.docs.map(doc => doc.id);
    }
    async create(blockerId, blockedId) {
        const db = getFirestore();
        const ref = db.collection('users').doc(blockerId).collection('blockedUsers').doc(blockedId);
        await ref.set({ createdAt: new Date() });
    }
    async delete(blockerId, blockedId) {
        const db = getFirestore();
        const ref = db.collection('users').doc(blockerId).collection('blockedUsers').doc(blockedId);
        await ref.delete();
    }
}
