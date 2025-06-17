import type { Encounter } from '../entities/encounter.entity';
import type { User } from '../entities/user.entity';

export interface IEncounterRepository {
  create(userId: string, encounteredUserId: string): Promise<boolean>;
  findRecentEncounteredUsers(userId: string): Promise<User[]>;
} 