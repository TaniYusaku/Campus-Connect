import { appendFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { getFirestore } from 'firebase-admin/firestore';
import type { User } from '../domain/entities/user.entity.js';

const LOG_DIR = join(process.cwd(), 'logs');

const HEADERS: Record<string, string> = {
  'ble_observations.csv':
    'ServerTimestamp,ReporterUserId,ObservedTempId,ResolvedUserId,ResolutionStatus,RSSI,ClientTimestamp,UserDetailsJson',
  'tempid_registrations.csv': 'RegisteredAt,UserId,TempId,ExpiresAt,UserDetailsJson',
  'encounters.csv': 'Timestamp,User1Id,User2Id,EncounterCount,UserDetailsJson',
  'user_events.csv': 'Timestamp,UserId,EventType,TargetId,Metadata,UserDetailsJson',
  'users_master.csv': 'LoggedAt,Action,UserId,UserName,Email,Faculty,Grade,Gender,ProfilePhotoUrl,Bio,Hobbies,Place,Activity,Mbti,SnsLinks,CreatedAt,UpdatedAt',
};

const toIsoString = (value: unknown): string => {
  if (!value) return '';
  if (value instanceof Date) return value.toISOString();
  const ts = value as { toDate?: () => Date };
  if (typeof ts?.toDate === 'function') {
    try {
      return ts.toDate().toISOString();
    } catch {
      return '';
    }
  }
  return '';
};

const formatHobbies = (hobbies: unknown): string => {
  if (!Array.isArray(hobbies)) return '';
  return hobbies
    .map((hobby) => String(hobby ?? '').trim())
    .filter((hobby) => hobby.length > 0)
    .join('|');
};

const formatSnsLinks = (links: unknown): string => {
  if (!links || typeof links !== 'object') return '';
  try {
    return JSON.stringify(links);
  } catch {
    return '';
  }
};

const pickUserDetails = (user: Partial<User> & { id: string }) => ({
  id: user.id,
  userName: user.userName ?? '',
  email: user.email ?? '',
  faculty: user.faculty ?? '',
  grade: user.grade ?? '',
  gender: user.gender ?? '',
  profilePhotoUrl: user.profilePhotoUrl ?? '',
  bio: user.bio ?? '',
  hobbies: user.hobbies ?? [],
  place: user.place ?? '',
  activity: user.activity ?? '',
  mbti: user.mbti ?? '',
  snsLinks: user.snsLinks ?? {},
  createdAt: toIsoString(user.createdAt),
  updatedAt: toIsoString(user.updatedAt),
});

export const logToCsv = (fileName: string, columns: (string | number | undefined | null)[]): void => {
  try {
    if (!existsSync(LOG_DIR)) {
      mkdirSync(LOG_DIR, { recursive: true });
    }

    const filePath = join(LOG_DIR, fileName);

    if (!existsSync(filePath) && HEADERS[fileName]) {
      writeFileSync(filePath, HEADERS[fileName] + '\n', 'utf-8');
    }

    const line = columns
      .map((col) => {
        if (col === null || col === undefined) return '';
        const str = String(col);
        if (str.includes(',') || str.includes('\n')) {
          return `"${str.replace(/"/g, '""')}"`;
        }
        return str;
      })
      .join(',');

    appendFileSync(filePath, line + '\n', 'utf-8');
  } catch (error) {
    console.error(`[CSV Log Error] Failed to write to ${fileName}:`, error);
  }
};

export const logUserSnapshot = (user: Partial<User> & { id: string }, action: string = 'snapshot'): void => {
  logToCsv('users_master.csv', [
    new Date().toISOString(),
    action,
    user.id,
    user.userName ?? '',
    user.email ?? '',
    user.faculty ?? '',
    user.grade ?? '',
    user.gender ?? '',
    user.profilePhotoUrl ?? '',
    user.bio ?? '',
    formatHobbies(user.hobbies),
    user.place ?? '',
    user.activity ?? '',
    user.mbti ?? '',
    formatSnsLinks(user.snsLinks),
    toIsoString(user.createdAt),
    toIsoString(user.updatedAt),
  ]);
};

// 任意のCSVログを書き出したタイミングで、関連するユーザーのスナップショットも併記する
export const logWithUserDetails = async (
  fileName: string,
  columns: (string | number | undefined | null)[],
  userIds: string[] = [],
  action?: string,
): Promise<void> => {
  const uniqueIds = Array.from(new Set(userIds)).filter((id) => !!id);
  let userDetailsJson: string | undefined;
  let fetchedSnapshots: { id: string; snap: any }[] | undefined;

  if (uniqueIds.length > 0) {
    try {
      const db = getFirestore();
      fetchedSnapshots = await Promise.all(
        uniqueIds.map((id) =>
          db
            .collection('users')
            .doc(id)
            .get()
            .then((snap) => ({ id, snap })),
        ),
      );
      const details: Record<string, ReturnType<typeof pickUserDetails>> = {};
      fetchedSnapshots.forEach(({ id, snap }) => {
        if (snap.exists) {
          details[id] = pickUserDetails(snap.data() as User);
        } else {
          details[id] = pickUserDetails({ id });
        }
      });
      if (Object.keys(details).length > 0) {
        userDetailsJson = JSON.stringify(details);
      }
    } catch (err) {
      console.error(`[CSV Log Error] Failed to fetch user details for ${fileName}:`, err);
    }
  }

  logToCsv(fileName, userDetailsJson ? [...columns, userDetailsJson] : columns);

  if (uniqueIds.length === 0) return;
  const snapshotsForSnapshot = fetchedSnapshots;
  if (snapshotsForSnapshot) {
    snapshotsForSnapshot.forEach(({ id, snap }) => {
      if (snap.exists) {
        logUserSnapshot(snap.data() as User, action ?? fileName);
      } else {
        logUserSnapshot({ id }, action ?? fileName);
      }
    });
  } else {
    // 詳細取得に失敗した場合もスナップショットだけは試みる
    try {
      const db = getFirestore();
      const snapshots = await Promise.all(
        uniqueIds.map((id) =>
          db
            .collection('users')
            .doc(id)
            .get()
            .then((snap) => ({ id, snap })),
        ),
      );
      snapshots.forEach(({ id, snap }) => {
        if (snap.exists) {
          logUserSnapshot(snap.data() as User, action ?? fileName);
        } else {
          logUserSnapshot({ id }, action ?? fileName);
        }
      });
    } catch (err) {
      console.error(`[CSV Log Error] Failed to append user snapshots for ${fileName}:`, err);
    }
  }
};
