import { getFirestore } from 'firebase-admin/firestore';
import { LikeRepository } from './like.repository';
import { MatchRepository } from './match.repository';
export class EncounterRepository {
    likeRepository;
    matchRepository;
    constructor(likeRepository = new LikeRepository(), matchRepository = new MatchRepository()) {
        this.likeRepository = likeRepository;
        this.matchRepository = matchRepository;
    }
    async create(userId1, userId2) {
        const db = getFirestore();
        const timestamp = new Date();
        const encounter1Ref = db.collection('users').doc(userId1).collection('recentEncounters').doc(userId2);
        const encounter2Ref = db.collection('users').doc(userId2).collection('recentEncounters').doc(userId1);
        const batch = db.batch();
        batch.set(encounter1Ref, { lastEncounteredAt: timestamp });
        batch.set(encounter2Ref, { lastEncounteredAt: timestamp });
        await batch.commit();
        const user1LikesUser2 = await this.likeRepository.exists(userId1, userId2);
        const user2LikesUser1 = await this.likeRepository.exists(userId2, userId1);
        if (user1LikesUser2 && user2LikesUser1) {
            await this.matchRepository.create(userId1, userId2);
            return true;
        }
        return false;
    }
    async findRecentEncounteredUsers(userId) {
        const db = getFirestore();
        const encountersCol = db.collection('users').doc(userId).collection('recentEncounters');
        const snapshot = await encountersCol.orderBy('lastEncounteredAt', 'desc').limit(50).get();
        if (snapshot.empty) {
            return [];
        }
        const encounteredUserIds = snapshot.docs.map(doc => doc.id);
        const limitedUserIds = encounteredUserIds.slice(0, 30);
        const usersCol = db.collection('users');
        const userDocs = await usersCol.where('id', 'in', limitedUserIds).get();
        const usersMap = new Map();
        userDocs.forEach(doc => {
            const user = doc.data();
            usersMap.set(user.id, user);
        });
        const sortedUsers = limitedUserIds.map(id => usersMap.get(id)).filter((user) => user !== undefined);
        return sortedUsers;
    }
}
