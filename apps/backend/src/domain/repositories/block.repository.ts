export interface IBlockRepository {
  findAll(userId: string): Promise<string[]>;
  create(blockerId: string, blockedId: string): Promise<void>;
  delete(blockerId: string, blockedId: string): Promise<void>;
} 