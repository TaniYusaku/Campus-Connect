export type User = {
  id: string; // Firebase AuthenticationのUID
  userName: string;
  email: string;
  createdAt: Date;
  updatedAt: Date;
  readonly faculty?: string;
  readonly grade?: number;
  readonly gender?: string;
  readonly sameGenderOnly?: boolean;
  readonly profilePhotoUrl?: string;
  readonly bio?: string;
  readonly hobbies?: string[];
  readonly snsLinks?: { [key: string]: string };
};
