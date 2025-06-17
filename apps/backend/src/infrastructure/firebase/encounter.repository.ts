import { getFirestore } from 'firebase-admin/firestore';

import type { IEncounterRepository } from '../../domain/repositories/encounter.repository';

import type { ILikeRepository } from '../../domain/repositories/like.repository';

import type { IMatchRepository } from '../../domain/repositories/match.repository';

import type { User } from '../../domain/entities/user.entity';

import { LikeRepository } from './like.repository';

import { MatchRepository } from './match.repository';



export class EncounterRepository implements IEncounterRepository {

constructor(

private readonly likeRepository: ILikeRepository = new LikeRepository(),

private readonly matchRepository: IMatchRepository = new MatchRepository()

) {}



async create(userId1: string, userId2: string): Promise<boolean> {

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



async findRecentEncounteredUsers(userId: string): Promise<User[]> {

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



const usersMap = new Map<string, User>();

userDocs.forEach(doc => {

const user = doc.data() as User;

usersMap.set(user.id, user);

});



const sortedUsers = limitedUserIds.map(id => usersMap.get(id)).filter((user): user is User => user !== undefined);



return sortedUsers;

}

}