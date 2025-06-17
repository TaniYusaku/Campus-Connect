import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import type { IUserRepository, UpdatableUserInfo } from '../../domain/repositories/user.repository';
import type { User } from '../../domain/entities/user.entity';
import axios from 'axios';

// IUserRepositoryインターフェースを実際にFirebaseを使って実装するクラス
export class UserRepository implements IUserRepository {
  constructor() {}

  async createUser(authInfo: { email: string; password?: string; userName: string }): Promise<User> {
    const auth = getAuth();
    const db = getFirestore();
    const userRecord = await auth.createUser({
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

    await db.collection('users').doc(userRecord.uid).set(newUser);
    return newUser;
  }

  async findById(id: string): Promise<User | null> {
    const db = getFirestore();
    const doc = await db.collection('users').doc(id).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data() as User;
  }

  async signIn(email: string, password: string): Promise<{ token: string; user: User }> {
    const apiKey = process.env.FIREBASE_WEB_API_KEY;
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
    const db = getFirestore();
    const userRef = db.collection('users').doc(id);
    const updateData = {
      ...userInfo,
      updatedAt: new Date(),
    };
    await userRef.update(updateData);
    const updatedDoc = await userRef.get();
    return updatedDoc.data() as User;
  }

  async delete(id: string): Promise<void> {
    const db = getFirestore();
    const auth = getAuth();
    await db.collection('users').doc(id).delete();
    await auth.deleteUser(id);
  }
}