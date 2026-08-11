export interface PlayGamesStructuredError {
  code: string;
  message: string;
  nativeMessage?: string;
  details?: string;
}

export interface PlayGamesPlayerSummary {
  playerId?: string;
  displayName?: string;
  iconImageUri?: string;
  hiResImageUri?: string;
}

export interface PlayGamesBridgeResult {
  available: boolean;
  configured?: boolean;
  authenticated?: boolean;
  status: string;
  method?: string;
  feature?: string;
  playServicesStatus?: number;
  player?: PlayGamesPlayerSummary | null;
  payload?: Record<string, unknown> | null;
  conflictingPayload?: Record<string, unknown> | null;
  conflict?: boolean;
  metadata?: Record<string, unknown> | null;
  leaderboardKey?: string | null;
  achievementKey?: string | null;
  score?: number;
  resourceKey?: string | null;
  error?: PlayGamesStructuredError | null;
}

export interface PlayGamesSavedGameRequest {
  snapshotName?: string;
  payload?: Record<string, unknown>;
  reason?: string;
}

export interface FlagGamePlayGamesPlugin {
  isAvailable(): Promise<PlayGamesBridgeResult>;
  getAuthenticationStatus(): Promise<PlayGamesBridgeResult>;
  requestAuthenticationRetry(): Promise<PlayGamesBridgeResult>;
  getPlayerSummary(): Promise<PlayGamesBridgeResult>;
  syncSavedGame(request: PlayGamesSavedGameRequest): Promise<PlayGamesBridgeResult>;
  commitSavedGame(request: PlayGamesSavedGameRequest): Promise<PlayGamesBridgeResult>;
  submitLeaderboardScore(request: {
    leaderboardKey: string;
    score: number;
    scoreTag?: string;
  }): Promise<PlayGamesBridgeResult>;
  unlockAchievement(request: {
    achievementKey: string;
  }): Promise<PlayGamesBridgeResult>;
  openLeaderboards(): Promise<PlayGamesBridgeResult>;
  openAchievements(): Promise<PlayGamesBridgeResult>;
  requestServerSideAccess(options: {
    webClientId: string;
    forceRefreshToken?: boolean;
  }): Promise<{ serverAuthCode: string }>;
}
