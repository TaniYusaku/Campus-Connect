export type Announcement = {
  id: string;
  title: string;
  body: string;
  publishedAt: Date;
  linkUrl?: string;
  importance?: 'normal' | 'important';
};
