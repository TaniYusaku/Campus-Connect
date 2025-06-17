export interface ILikeRepository {
  create(likingUserId: string, likedUserId: string): Promise<void>;
  exists(likingUserId: string, likedUserId: string): Promise<boolean>;
} 