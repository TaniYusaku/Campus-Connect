import { getFirestore } from "firebase-admin/firestore";
import type { IMatchRepository } from "../../domain/repositories/match.repository";

export class MatchRepository implements IMatchRepository {
  async create(userId1: string, userId2: string): Promise<void> {
    const db = getFirestore();
    const timestamp = new Date();

    const match1Ref = db.collection('users').doc(userId1).collection('matches').doc(userId2);
    const match2Ref = db.collection('users').doc(userId2).collection('matches').doc(userId1);

    const batch = db.batch();
    batch.set(match1Ref, { createdAt: timestamp });
    batch.set(match2Ref, { createdAt: timestamp });

    await batch.commit();
  }

  async findAll(userId: string): Promise<string[]> {
    const db = getFirestore();
    const matchesCol = db.collection('users').doc(userId).collection('matches');
    const snapshot = await matchesCol.get();
    if (snapshot.empty) {
      return [];
    }
    return snapshot.docs.map(doc => doc.id);
  }
} 