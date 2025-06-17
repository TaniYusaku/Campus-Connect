export interface IMatchRepository {
  create(userId1: string, userId2: string): Promise<void>;
} 