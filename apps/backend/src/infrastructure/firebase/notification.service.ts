import { getMessaging } from 'firebase-admin/messaging';
import type { IDeviceRepository } from '../../domain/repositories/device.repository';

const INVALID_TOKEN_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

export class NotificationService {
  constructor(private readonly deviceRepository: IDeviceRepository) {}

  async sendReencounterNotification(options: {
    userId: string;
    peerUserId: string;
    peerDisplayName: string;
  }): Promise<void> {
    const { userId, peerUserId, peerDisplayName } = options;
    const tokens = await this.deviceRepository.getTokens(userId);
    if (tokens.length === 0) {
      return;
    }

    try {
      const response = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: 'Campus Connect',
          body: `${peerDisplayName}さんとまた会いました！`,
        },
        data: {
          type: 'RE-ENCOUNTER',
          peerUserId,
        },
      });

      if (response.failureCount > 0) {
        const removals: Promise<void>[] = [];
        response.responses.forEach((res, index) => {
          if (!res.success) {
            const code = res.error?.code;
            if (code && INVALID_TOKEN_CODES.has(code)) {
              removals.push(this.deviceRepository.removeByToken(userId, tokens[index]!));
            }
          }
        });
        if (removals.length > 0) {
          await Promise.allSettled(removals);
        }
      }
    } catch (error) {
      console.error('[push] re-encounter notification failed', { userId, error });
    }
  }
}
