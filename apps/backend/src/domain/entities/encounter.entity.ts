export type Encounter = {
  id: string; // FirestoreのドキュメントID
  userId: string; // すれ違った側のユーザーID
  encounteredUserId: string; // すれ違われた側のユーザーID
  timestamp: Date; // すれ違った日時
};

export type RecentEncounter = {
  lastEncounteredAt: Date;
}; 