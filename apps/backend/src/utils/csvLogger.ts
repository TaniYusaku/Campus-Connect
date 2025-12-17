import { appendFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const LOG_DIR = join(process.cwd(), 'logs');

const HEADERS: Record<string, string> = {
  'ble_observations.csv': 'ServerTimestamp,ReporterUserId,ObservedTempId,ResolvedUserId,ResolutionStatus,RSSI,ClientTimestamp',
  'tempid_registrations.csv': 'RegisteredAt,UserId,TempId,ExpiresAt',
  'encounters.csv': 'Timestamp,User1Id,User2Id,EncounterCount',
  'user_events.csv': 'Timestamp,UserId,EventType,TargetId,Metadata',
  'users_master.csv': 'UserId,Faculty,Grade,Gender,Mbti,Hobbies,RegisteredAt',
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
