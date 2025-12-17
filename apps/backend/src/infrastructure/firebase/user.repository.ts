import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import type { IUserRepository, UpdatableUserInfo } from '../../domain/repositories/user.repository.js';
import type { User } from '../../domain/entities/user.entity.js';
import axios from 'axios';
import type { UpdateData } from 'firebase-admin/firestore';
import { logUserSnapshot } from '../../utils/csvLogger.js';

// IUserRepositoryインターフェースを実際にFirebaseを使って実装するクラス
export class UserRepository implements IUserRepository {
  constructor() {}

  async createUser(authInfo: { email: string; password?: string; userName: string; faculty?: string; grade?: number; gender?: string }): Promise<User> {
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
      faculty: authInfo.faculty,
      grade: authInfo.grade,
      gender: authInfo.gender,
    };

    await db.collection('users').doc(userRecord.uid).set(newUser);
    logUserSnapshot(newUser, 'create');
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

  async signIn(email: string, password: string): Promise<{ token: string; refreshToken: string; expiresIn: number; user: User }> {
    const apiKey = process.env.FIREBASE_WEB_API_KEY;
    const authUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;

    const response = await axios.post(authUrl, {
      email,
      password,
      returnSecureToken: true,
    });

    const idToken = response.data.idToken as string;
    const uid = response.data.localId as string;
    const refreshToken = response.data.refreshToken as string;
    const expiresIn = Number(response.data.expiresIn ?? '3600');

    const user = await this.findById(uid);
    if (!user) {
      throw new Error('User not found in Firestore.');
    }

    return { token: idToken, refreshToken, expiresIn, user };
  }

  /**
   * Exchange a Firebase refresh token for a new ID token using the Secure Token API.
   */
  async refreshIdToken(refreshToken: string): Promise<{ token: string; refreshToken: string; expiresIn: number; user: User }> {
    const apiKey = process.env.FIREBASE_WEB_API_KEY;
    const url = `https://securetoken.googleapis.com/v1/token?key=${apiKey}`;

    const response = await axios.post(url, {
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    });

    const idToken: string = response.data.id_token;
    const uid: string = response.data.user_id;
    const newRefresh: string = response.data.refresh_token;
    const expiresIn: number = Number(response.data.expires_in ?? '3600');

    const user = await this.findById(uid);
    if (!user) {
      throw new Error('User not found in Firestore.');
    }

    return { token: idToken, refreshToken: newRefresh, expiresIn, user };
  }

  async update(id: string, userInfo: UpdatableUserInfo): Promise<User> {
    const db = getFirestore();
    const userRef = db.collection('users').doc(id);
    const trimmedPlace = userInfo.place !== undefined ? (userInfo.place?.trim() ?? '') : undefined;
    const placeUpdate = trimmedPlace === undefined ? undefined : trimmedPlace.length === 0 ? FieldValue.delete() : trimmedPlace;

    const trimmedActivity = userInfo.activity !== undefined ? (userInfo.activity?.trim() ?? '') : undefined;
    const activityUpdate = trimmedActivity === undefined ? undefined : trimmedActivity.length === 0 ? FieldValue.delete() : trimmedActivity;

    const trimmedMbti = userInfo.mbti !== undefined ? (userInfo.mbti?.trim() ?? '') : undefined;
    const mbtiUpdate = trimmedMbti === undefined ? undefined : trimmedMbti.length === 0 ? FieldValue.delete() : trimmedMbti;

    let snsLinksUpdate: UpdateData<User>['snsLinks'] | undefined;
    if (userInfo.snsLinks !== undefined) {
      const sanitizedEntries = Object.entries(userInfo.snsLinks ?? {}).reduce<Record<string, string>>(
        (acc, [key, value]) => {
          const trimmed = value.trim();
          if (trimmed.length > 0) {
            acc[key] = trimmed;
          }
          return acc;
        },
        {},
      );
      snsLinksUpdate = Object.keys(sanitizedEntries).length === 0 ? FieldValue.delete() : sanitizedEntries;
    }

    const updateData: UpdateData<User> = {
      updatedAt: new Date(),
      ...(userInfo.userName !== undefined ? { userName: userInfo.userName } : {}),
      ...(userInfo.faculty !== undefined ? { faculty: userInfo.faculty } : {}),
      ...(userInfo.grade !== undefined ? { grade: userInfo.grade } : {}),
      ...(userInfo.gender !== undefined ? { gender: userInfo.gender } : {}),
      ...(userInfo.profilePhotoUrl !== undefined ? { profilePhotoUrl: userInfo.profilePhotoUrl } : {}),
      ...(userInfo.bio !== undefined ? { bio: userInfo.bio } : {}),
      ...(userInfo.hobbies !== undefined ? { hobbies: userInfo.hobbies } : {}),
      ...(placeUpdate !== undefined ? { place: placeUpdate } : {}),
      ...(activityUpdate !== undefined ? { activity: activityUpdate } : {}),
      ...(mbtiUpdate !== undefined ? { mbti: mbtiUpdate } : {}),
      ...(snsLinksUpdate !== undefined ? { snsLinks: snsLinksUpdate } : {}),
    };
    await userRef.update(updateData);
    const updatedDoc = await userRef.get();
    const updatedUser = updatedDoc.data() as User;
    logUserSnapshot(updatedUser, 'update');
    return updatedUser;
  }

  async delete(id: string): Promise<void> {
    const db = getFirestore();
    const auth = getAuth();
    const userRef = db.collection('users').doc(id);
    let existingUser: User | undefined;
    try {
      const snap = await userRef.get();
      if (snap.exists) {
        existingUser = snap.data() as User;
      }
    } catch {
      // ignore read errors for logging
    }
    await userRef.delete();
    await auth.deleteUser(id);
    logUserSnapshot(existingUser ?? { id }, 'delete');
  }

  async findByIds(userIds: string[]): Promise<User[]> {
    if (userIds.length === 0) return [];
    const db = getFirestore();
    // Firestoreのinクエリは最大10件までなので分割
    const chunkSize = 10;
    const chunks = [];
    for (let i = 0; i < userIds.length; i += chunkSize) {
      chunks.push(userIds.slice(i, i + chunkSize));
    }
    const users: User[] = [];
    for (const chunk of chunks) {
      const snapshot = await db.collection('users').where('id', 'in', chunk).get();
      snapshot.forEach(doc => {
        users.push(doc.data() as User);
      });
    }
    // 順序をuserIdsに揃える
    const userMap = new Map(users.map(u => [u.id, u]));
    return userIds.map(id => userMap.get(id)).filter((u): u is User => !!u);
  }
}
