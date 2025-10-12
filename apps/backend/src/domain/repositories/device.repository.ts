export type DeviceUpsertPayload = {
  token: string;
  platform?: string;
  deviceId?: string;
  appVersion?: string;
  locale?: string;
};

export interface IDeviceRepository {
  upsert(userId: string, payload: DeviceUpsertPayload): Promise<void>;
  getTokens(userId: string): Promise<string[]>;
  removeByToken(userId: string, token: string): Promise<void>;
}
