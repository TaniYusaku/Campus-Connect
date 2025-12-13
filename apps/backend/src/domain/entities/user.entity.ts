export type User = {
  id: string; // Firebase AuthenticationのUID
  userName: string;
  email: string;
  createdAt: Date;
  updatedAt: Date;
  readonly faculty?: string;
  readonly grade?: number;
  readonly gender?: string;
  readonly profilePhotoUrl?: string;
  readonly bio?: string;
  readonly hobbies?: string[];
  readonly place?: string;
  readonly activity?: string;
  readonly mbti?: string;
  readonly snsLinks?: { [key: string]: string };
};
