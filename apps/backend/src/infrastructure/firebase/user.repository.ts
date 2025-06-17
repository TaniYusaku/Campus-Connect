import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import type { IUserRepository, UpdatableUserInfo } from '../../domain/repositories/user.repository';
import type { User } from '../../domain/entities/user.entity';
import axios from 'axios';

// IUserRepositoryインターフェースを実際にFirebaseを使って実装するクラス
export class UserRepository implements IUserRepository {
  // ↓↓↓↓ ここから修正 ↓↓↓↓
  // プロパティをgetterに変更して、呼び出されるまで初期化を遅らせる
  private get db() {
    return getFirestore();
  }
  private get auth() {
    return getAuth();
  }
  private get userCollection() {
    return this.db.collection('users');
  }
  // ↑↑↑↑ ここまで修正 ↑↑↑↑

  async createUser(authInfo: { email: string; password?: string; userName: string }): Promise<User> {
    // 1. Firebase Authenticationにユーザーを作成
    const userRecord = await this.auth.createUser({ // this.authがgetterを呼び出す
      email: authInfo.email,
      password: authInfo.password,
      displayName: authInfo.userName,
    });

    const newUser: User = {
      id: userRecord.uid,
      userName: authInfo.userName,
      email: authInfo.email,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    // 2. Firestoreにユーザードキュメントを作成
    await this.userCollection.doc(userRecord.uid).set(newUser); // this.userCollectionがgetterを呼び出す

    return newUser;
  }

  async findById(id: string): Promise<User | null> {
    const doc = await this.userCollection.doc(id).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data() as User;
  }

  async signIn(email: string, password: string): Promise<{ token: string; user: User }> {
    const apiKey = process.env.FIREBASE_WEB_API_KEY;

    console.log('[DEBUG] Reading FIREBASE_WEB_API_KEY:', apiKey);
    
    const authUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;

    const response = await axios.post(authUrl, {
      email,
      password,
      returnSecureToken: true,
    });

    const idToken = response.data.idToken;
    const uid = response.data.localId;

    const user = await this.findById(uid);
    if (!user) {
      throw new Error('User not found in Firestore.');
    }

    return { token: idToken, user };
  }

  async update(id: string, userInfo: UpdatableUserInfo): Promise<User> {
    const userRef = this.userCollection.doc(id);

    const updateData = {
      ...userInfo,
      updatedAt: new Date(),
    };

    await userRef.update(updateData);

    const updatedDoc = await userRef.get();
    return updatedDoc.data() as User;
  }

  async delete(id: string): Promise<void> {
    await this.userCollection.doc(id).delete();
    await this.auth.deleteUser(id);
  }
}