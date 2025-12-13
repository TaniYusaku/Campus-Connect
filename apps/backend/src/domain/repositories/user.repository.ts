import type { User } from '../entities/user.entity.js';

// ユーザーデータに関する操作のインターフェース（契約）を定義します
export interface IUserRepository {
  // Firebase AuthenticationとFirestoreにユーザーを作成する
  createUser(authInfo: { email: string; password?: string; userName: string; faculty?: string; grade?: number; gender?: string }): Promise<User>;
  // IDを指定してユーザーをFirestoreから取得する
  findById(id: string): Promise<User | null>;
  // ↓↓↓↓ 以下を追記 ↓↓↓↓
  signIn(email: string, password: string): Promise<{ token: string; refreshToken: string; expiresIn: number; user: User }>;
  // ↓↓↓↓ 以下を追記 ↓↓↓↓
  update(id: string, userInfo: UpdatableUserInfo): Promise<User>;
  // ↓↓↓↓ 以下を追記 ↓↓↓↓
  delete(id: string): Promise<void>;
  findByIds(userIds: string[]): Promise<User[]>;
}

// 更新可能なユーザー情報の型
export type UpdatableUserInfo = {
  userName?: string;
  faculty?: string;
  grade?: number;
  gender?: string;
  profilePhotoUrl?: string;
  bio?: string;
  hobbies?: string[];
  place?: string;
  activity?: string;
  mbti?: string;
  snsLinks?: { [key: string]: string };
};
