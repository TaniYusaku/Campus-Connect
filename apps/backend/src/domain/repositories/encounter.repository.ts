import type { Encounter, EncounteredUser } from '../entities/encounter.entity.js';

export interface IEncounterRepository {
  create(userId: string, encounteredUserId: string): Promise<boolean>;
  findRecentEncounteredUsers(userId: string): Promise<EncounteredUser[]>;
  deleteBetween(userId1: string, userId2: string): Promise<void>;
}
