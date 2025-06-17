import type { Encounter } from '../entities/encounter.entity';

export interface IEncounterRepository {
  create(userId: string, encounteredUserId: string): Promise<Encounter>;
} 