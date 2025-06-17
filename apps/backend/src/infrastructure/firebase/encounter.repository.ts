import { getFirestore } from 'firebase-admin/firestore';
import type { IEncounterRepository } from '../../domain/repositories/encounter.repository';
import type { Encounter } from '../../domain/entities/encounter.entity';

export class EncounterRepository implements IEncounterRepository {
  private get db() {
    return getFirestore();
  }
  private encounterCollection = this.db.collection('recentEncounters');

  async create(userId: string, encounteredUserId: string): Promise<Encounter> {
    const timestamp = new Date();

    const docRef = await this.encounterCollection.add({
      userId,
      encounteredUserId,
      timestamp,
    });

    const newEncounter: Encounter = {
      id: docRef.id,
      userId,
      encounteredUserId,
      timestamp,
    };

    return newEncounter;
  }
} 