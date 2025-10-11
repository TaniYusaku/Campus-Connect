export interface IMatchRepository {
  create(userId1: string, userId2: string): Promise<void>;
  findAll(userId: string): Promise<string[]>;
  deletePair(userId1: string, userId2: string): Promise<void>;
}
