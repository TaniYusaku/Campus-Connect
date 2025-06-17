export type User = {
  id: string; // Firebase AuthenticationのUID
  userName: string;
  email: string;
  createdAt: Date;
  updatedAt: Date;
};
