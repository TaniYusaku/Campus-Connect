import type { User } from '../entities/user.entity';

// ユーザーデータに関する操作のインターフェース（契約）を定義します
export interface IUserRepository {
  // Firebase AuthenticationとFirestoreにユーザーを作成する
  createUser(authInfo: { email: string; password?: string; userName: string }): Promise<User>;
  // IDを指定してユーザーをFirestoreから取得する
  findById(id: string): Promise<User | null>;
  // ↓↓↓↓ 以下を追記 ↓↓↓↓
  signIn(email: string, password: string): Promise<{ token: string; user: User }>;
  // ↓↓↓↓ 以下を追記 ↓↓↓↓
  update(id: string, userInfo: UpdatableUserInfo): Promise<User>;
  // ↓↓↓↓ 以下を追記 ↓↓↓↓
  delete(id: string): Promise<void>;
}

// 更新可能なユーザー情報の型
export type UpdatableUserInfo = {
  userName?: string;
};
