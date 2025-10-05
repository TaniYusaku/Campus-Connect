export interface ILikeRepository {
  create(likingUserId: string, likedUserId: string): Promise<void>;
  exists(likingUserId: string, likedUserId: string): Promise<boolean>;
  findRecent(likingUserId: string, since: Date): Promise<string[]>; // returns liked userIds
  delete(likingUserId: string, likedUserId: string): Promise<void>;
}
