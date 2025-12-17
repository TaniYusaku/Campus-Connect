import { appendFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { getFirestore } from 'firebase-admin/firestore';
import type { User } from '../domain/entities/user.entity.js';

const LOG_DIR = join(process.cwd(), 'logs');
const JST_OFFSET_MS = 9 * 60 * 60 * 1000;

const BASE_HEADERS: Record<string, string[]> = {
  'ble_observations.csv': ['ServerTimestamp', 'ReporterUserId', 'ObservedTempId', 'ResolvedUserId', 'ResolutionStatus', 'RSSI', 'ClientTimestamp'],
  'tempid_registrations.csv': ['RegisteredAt', 'UserId', 'TempId', 'ExpiresAt'],
  'encounters.csv': ['Timestamp', 'User1Id', 'User2Id', 'EncounterCount'],
  'user_events.csv': ['Timestamp', 'UserId', 'EventType', 'TargetId', 'Metadata'],
  'users_master.csv': ['LoggedAt', 'Action', 'UserId', 'UserName', 'Email', 'Faculty', 'Grade', 'Gender', 'ProfilePhotoUrl', 'Bio', 'Hobbies', 'Place', 'Activity', 'Mbti', 'SnsLinks', 'CreatedAt', 'UpdatedAt'],
};

const ROLE_COLUMNS: Record<string, string[]> = {
  'ble_observations.csv': ['Reporter', 'Resolved'],
  'tempid_registrations.csv': ['User'],
  'encounters.csv': ['User1', 'User2'],
  'user_events.csv': ['Actor', 'Target'],
};

const USER_DETAIL_FIELDS = ['UserName', 'Email', 'Faculty', 'Grade', 'Gender', 'ProfilePhotoUrl', 'Bio', 'Hobbies', 'Place', 'Activity', 'Mbti', 'SnsLinks', 'CreatedAt', 'UpdatedAt'];

const buildHeader = (fileName: string): string | undefined => {
  const base = BASE_HEADERS[fileName];
  if (!base) return undefined;
  const roles = ROLE_COLUMNS[fileName] ?? [];
  const roleColumns = roles.flatMap((role) => USER_DETAIL_FIELDS.map((f) => `${role}${f}`));
  return [...base, ...roleColumns].join(',');
};

export const toJstString = (date: Date): string => {
  // Excelで扱いやすい形式: YYYY-MM-DD HH:MM:SS（JST）
  const shifted = new Date(date.getTime() + JST_OFFSET_MS);
  const pad = (n: number) => n.toString().padStart(2, '0');
  const year = shifted.getUTCFullYear();
  const month = pad(shifted.getUTCMonth() + 1);
  const day = pad(shifted.getUTCDate());
  const hour = pad(shifted.getUTCHours());
  const minute = pad(shifted.getUTCMinutes());
  const second = pad(shifted.getUTCSeconds());
  return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
};

export const nowJstString = (): string => toJstString(new Date());

const toIsoString = (value: unknown): string => {
  if (!value) return '';
  let date: Date | null = null;
  if (value instanceof Date) {
    date = value;
  } else {
    const ts = value as { toDate?: () => Date };
    if (typeof ts?.toDate === 'function') {
      try {
        date = ts.toDate();
      } catch {
        date = null;
      }
    }
  }
  return date ? toJstString(date) : '';
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
  const entries = Object.entries(links).map(([k, v]) => `${k}=${String(v ?? '').trim()}`);
  return entries.length > 0 ? entries.join('|') : '';
};

const toDetailColumns = (user?: Partial<User> & { id: string }): string[] => {
  if (!user) {
    return USER_DETAIL_FIELDS.map(() => '');
  }
  const snsLinks = (() => {
    if (!user.snsLinks || typeof user.snsLinks !== 'object') return '';
    const entries = Object.entries(user.snsLinks).map(([k, v]) => `${k}=${String(v ?? '').trim()}`);
    return entries.length > 0 ? entries.join('|') : '';
  })();
  return [
    user.userName ?? '',
    user.email ?? '',
    user.faculty ?? '',
    user.grade !== undefined && user.grade !== null ? String(user.grade) : '',
    user.gender ?? '',
    user.profilePhotoUrl ?? '',
    user.bio ?? '',
    formatHobbies(user.hobbies),
    user.place ?? '',
    user.activity ?? '',
    user.mbti ?? '',
    snsLinks,
    toIsoString(user.createdAt),
    toIsoString(user.updatedAt),
  ];
};

export const logToCsv = (fileName: string, columns: (string | number | undefined | null)[]): void => {
  try {
    if (!existsSync(LOG_DIR)) {
      mkdirSync(LOG_DIR, { recursive: true });
    }

    const filePath = join(LOG_DIR, fileName);

    const header = buildHeader(fileName);
    if (!existsSync(filePath) && header) {
      // Excelが区切り文字を正しく認識するように先頭に `sep=,` を付与
      writeFileSync(filePath, `sep=,\n${header}\n`, 'utf-8');
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
    nowJstString(),
    action,
    user.id,
    user.userName ?? '',
    user.email ?? '',
    user.faculty ?? '',
    user.grade !== undefined && user.grade !== null ? String(user.grade) : '',
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

type LogUserRole = { role: string; userId?: string | null };

// 任意のCSVログを書き出したタイミングで、関与ユーザーを役割ごとにフラットな列で併記する
export const logWithUserDetails = async (
  fileName: string,
  columns: (string | number | undefined | null)[],
  users: LogUserRole[] = [],
  action?: string,
): Promise<void> => {
  const roles = ROLE_COLUMNS[fileName] ?? [];
  const roleToUserId = new Map<string, string>();
  users.forEach(({ role, userId }) => {
    if (role && userId) {
      roleToUserId.set(role, userId);
    }
  });

  const uniqueIds = Array.from(new Set(users.map((u) => u.userId).filter((id): id is string => !!id)));
  let fetchedSnapshots: { id: string; snap: any }[] | undefined;
  let userMap: Map<string, Partial<User> & { id: string }> | undefined;

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
      userMap = new Map<string, Partial<User> & { id: string }>();
      fetchedSnapshots.forEach(({ id, snap }) => {
        const data = snap.exists ? (snap.data() as User) : undefined;
        const merged: Partial<User> & { id: string } = { ...(data ?? {}), id };
        userMap?.set(id, merged);
      });
    } catch (err) {
      console.error(`[CSV Log Error] Failed to fetch user details for ${fileName}:`, err);
    }
  }

  const detailColumns = roles.flatMap((role) => {
    const uid = roleToUserId.get(role);
    const user = uid ? userMap?.get(uid) : undefined;
    return toDetailColumns(user);
  });

  logToCsv(fileName, [...columns, ...detailColumns]);

  if (userMap && userMap.size > 0) {
    userMap.forEach((data) => logUserSnapshot(data, action ?? fileName));
  }
};
