export interface FlagGameGoogleAuthPlugin {
  signInWithGoogle(options: {
    serverClientId: string;
    nonce?: string;
  }): Promise<{ idToken: string; nonce: string; email?: string }>;
}
