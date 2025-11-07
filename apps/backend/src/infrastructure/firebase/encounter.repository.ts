import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import type { IEncounterRepository } from '../../domain/repositories/encounter.repository';
import type { ILikeRepository } from '../../domain/repositories/like.repository';
import type { IMatchRepository } from '../../domain/repositories/match.repository';
import type { EncounteredUser, RecentEncounter } from '../../domain/entities/encounter.entity';
import { LikeRepository } from './like.repository';
import { MatchRepository } from './match.repository';

export class EncounterRepository implements IEncounterRepository {
  constructor(
    private readonly likeRepository: ILikeRepository = new LikeRepository(),
    private readonly matchRepository: IMatchRepository = new MatchRepository(),
  ) {}

  async create(userId1: string, userId2: string): Promise<boolean> {
    const db = getFirestore();
    const timestamp = new Date();
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const encounter1Ref = db
      .collection('users')
      .doc(userId1)
      .collection('recentEncounters')
      .doc(userId2);
    const encounter2Ref = db
      .collection('users')
      .doc(userId2)
      .collection('recentEncounters')
      .doc(userId1);

    const payload = {
      lastEncounteredAt: timestamp,
      expiresAt,
      count: FieldValue.increment(1),
    };
    const batch = db.batch();
    batch.set(encounter1Ref, payload, { merge: true });
    batch.set(encounter2Ref, payload, { merge: true });
    await batch.commit();

    const user1LikesUser2 = await this.likeRepository.exists(userId1, userId2);
    const user2LikesUser1 = await this.likeRepository.exists(userId2, userId1);

    if (user1LikesUser2 && user2LikesUser1) {
      await this.matchRepository.create(userId1, userId2);
      return true;
    }

    return false;
  }

  async findRecentEncounteredUsers(userId: string): Promise<EncounteredUser[]> {
    const db = getFirestore();
    const encountersCol = db.collection('users').doc(userId).collection('recentEncounters');
    const snapshot = await encountersCol.orderBy('lastEncounteredAt', 'desc').limit(50).get();

    if (snapshot.empty) {
      return [];
    }

    const metadata = new Map<string, { lastEncounteredAt?: Date; count?: number }>();
    const encounteredUserIds = snapshot.docs.map((doc) => {
      const data = doc.data() as Partial<RecentEncounter> & { lastEncounteredAt?: any; count?: number };
      const lastEncounteredAt = data.lastEncounteredAt
        ? (data.lastEncounteredAt.toDate ? data.lastEncounteredAt.toDate() : new Date(data.lastEncounteredAt))
        : undefined;
      metadata.set(doc.id, {
        lastEncounteredAt,
        count: typeof data.count === 'number' ? data.count : undefined,
      });
      return doc.id;
    });
    const limitedUserIds = encounteredUserIds.slice(0, 30);

    const usersCol = db.collection('users');
    const userDocs = await usersCol.where('id', 'in', limitedUserIds).get();

    const usersMap = new Map<string, EncounteredUser>();
    userDocs.forEach((doc) => {
      const user = doc.data() as EncounteredUser;
      if (!user.id) return;
      const meta = metadata.get(user.id);
      usersMap.set(user.id, {
        ...user,
        lastEncounteredAt: meta?.lastEncounteredAt,
        encounterCount: meta?.count ?? user.encounterCount ?? 1,
      });
    });

    const sortedUsers = limitedUserIds
      .map((id) => usersMap.get(id))
      .filter((user): user is EncounteredUser => user !== undefined);

    return sortedUsers;
  }

  async deleteBetween(userId1: string, userId2: string): Promise<void> {
    const db = getFirestore();

    const encounter1Ref = db
      .collection('users')
      .doc(userId1)
      .collection('recentEncounters')
      .doc(userId2);
    const encounter2Ref = db
      .collection('users')
      .doc(userId2)
      .collection('recentEncounters')
      .doc(userId1);

    const batch = db.batch();
    batch.delete(encounter1Ref);
    batch.delete(encounter2Ref);
    await batch.commit();
  }
}
