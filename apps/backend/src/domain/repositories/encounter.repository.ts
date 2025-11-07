import type { Encounter } from '../entities/encounter.entity';
import type { EncounteredUser } from '../entities/encounter.entity';

export interface IEncounterRepository {
  create(userId: string, encounteredUserId: string): Promise<boolean>;
  findRecentEncounteredUsers(userId: string): Promise<EncounteredUser[]>;
  deleteBetween(userId1: string, userId2: string): Promise<void>;
}
