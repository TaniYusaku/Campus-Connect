import { Hono } from 'hono';
import { AnnouncementRepository } from '../../infrastructure/firebase/announcement.repository.js';
import type { Announcement } from '../../domain/entities/announcement.entity.js';

const announcementRouter = new Hono();
const repository = new AnnouncementRepository();

announcementRouter.get('/', async (c) => {
  try {
    const items = await repository.listRecent();
    const payload = items.map((item: Announcement) => ({
      ...item,
      publishedAt: item.publishedAt.toISOString(),
    }));
    return c.json(payload);
  } catch (error) {
    console.error('Failed to fetch announcements', error);
    return c.json({ error: 'Failed to fetch announcements' }, 500);
  }
});

export { announcementRouter };
