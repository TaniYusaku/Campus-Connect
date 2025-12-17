import { appendFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { User } from '../domain/entities/user.entity.js';

const LOG_DIR = join(process.cwd(), 'logs');

const HEADERS: Record<string, string> = {
  'ble_observations.csv': 'ServerTimestamp,ReporterUserId,ObservedTempId,ResolvedUserId,ResolutionStatus,RSSI,ClientTimestamp',
  'tempid_registrations.csv': 'RegisteredAt,UserId,TempId,ExpiresAt',
  'encounters.csv': 'Timestamp,User1Id,User2Id,EncounterCount',
  'user_events.csv': 'Timestamp,UserId,EventType,TargetId,Metadata',
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
