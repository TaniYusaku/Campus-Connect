import { getFirestore } from 'firebase-admin/firestore';
import type { IBlockRepository } from '../../domain/repositories/block.repository.js';

export class BlockRepository implements IBlockRepository {
  async findAll(userId: string): Promise<string[]> {
    const db = getFirestore();
    const blockedCol = db.collection('users').doc(userId).collection('blockedUsers');
    const snapshot = await blockedCol.get();
    if (snapshot.empty) {
      return [];
    }
    return snapshot.docs.map(doc => doc.id);
  }

  async findAllIds(userId: string): Promise<string[]> {
    const db = getFirestore();
    const blockedCol = db.collection('users').doc(userId).collection('blockedUsers');
    const snapshot = await blockedCol.get();
    if (snapshot.empty) {
      return [];
    }
    return snapshot.docs.map(doc => doc.id);
  }

  async create(blockerId: string, blockedId: string): Promise<void> {
    const db = getFirestore();
    const ref = db.collection('users').doc(blockerId).collection('blockedUsers').doc(blockedId);
    await ref.set({ createdAt: new Date() });
  }

  async delete(blockerId: string, blockedId: string): Promise<void> {
    const db = getFirestore();
    const ref = db.collection('users').doc(blockerId).collection('blockedUsers').doc(blockedId);
    await ref.delete();
  }
} 
