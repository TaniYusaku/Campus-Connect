import { getFirestore } from 'firebase-admin/firestore';
import type { Announcement } from '../../domain/entities/announcement.entity.js';

export class AnnouncementRepository {
  async listRecent(limit = 20): Promise<Announcement[]> {
    const db = getFirestore();
    const snapshot = await db
      .collection('announcements')
      .orderBy('publishedAt', 'desc')
      .limit(limit)
      .get();

    if (snapshot.empty) {
      return [];
    }

    return snapshot.docs.map((doc) => {
      const data = doc.data();
      const publishedAt = data.publishedAt?.toDate?.() ?? new Date();
      return {
        id: doc.id,
        title: data.title ?? '',
        body: data.body ?? '',
        publishedAt,
        linkUrl: data.linkUrl,
        importance: data.importance,
      } satisfies Announcement;
    });
  }
}
