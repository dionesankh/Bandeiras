const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.join(__dirname, "..", "js", "play-games-adapter.js"),
  "utf8"
);

function loadAdapter(contextValues = {}) {
  const context = {
    console,
    ...contextValues
  };

  vm.runInNewContext(source, context, {
    filename: "play-games-adapter.js"
  });

  return context.FlagGamePlayGames;
}

async function testWebFallbackDoesNotThrow() {
  const adapter = loadAdapter({
    location: { protocol: "https:" }
  });

  assert.equal(adapter.available, false);

  const availability = await adapter.isAvailable();
  assert.equal(availability.available, false);
  assert.equal(availability.status, "unsupported_platform");
  assert.equal(availability.error.code, "unsupported_platform");

  const auth = await adapter.getAuthenticationStatus();
  assert.equal(auth.available, false);
  assert.equal(auth.authenticated, false);

  const retry = await adapter.requestAuthenticationRetry();
  assert.equal(retry.available, false);

  const player = await adapter.getPlayerSummary();
  assert.equal(player.available, false);
  assert.equal(player.player, null);

  const sync = await adapter.syncSavedGame({ payload: {} });
  assert.equal(sync.available, false);
  assert.equal(sync.status, "unsupported_platform");
}

async function testAndroidWithoutNativePlugin() {
  const adapter = loadAdapter({
    FlagGameNativePlatform: "android",
    Capacitor: {
      getPlatform: () => "android",
      Plugins: {}
    }
  });

  assert.equal(adapter.available, false);

  const result = await adapter.isAvailable();
  assert.equal(result.status, "native_plugin_unavailable");
  assert.equal(result.error.code, "native_plugin_unavailable");
}

async function testNativePluginSuccess() {
  const adapter = loadAdapter({
    Capacitor: {
      getPlatform: () => "android",
      Plugins: {
        FlagGamePlayGames: {
          isAvailable: async () => ({
            available: true,
            configured: true,
            status: "available",
            playServicesStatus: 0
          }),
          getAuthenticationStatus: async () => ({
            available: true,
            authenticated: true,
            status: "authentication_status"
          }),
          requestAuthenticationRetry: async () => ({
            available: true,
            authenticated: true,
            status: "authentication_retry"
          }),
          getPlayerSummary: async () => ({
            available: true,
            authenticated: true,
            status: "player_summary",
            player: {
              playerId: "player-1",
              displayName: "Player One"
            }
          }),
          syncSavedGame: async () => ({
            available: true,
            authenticated: true,
            status: "snapshot_loaded",
            payload: { schemaVersion: 1 }
          }),
          commitSavedGame: async () => ({
            available: true,
            authenticated: true,
            status: "snapshot_committed"
          }),
          submitLeaderboardScore: async payload => ({
            available: true,
            authenticated: true,
            status: "leaderboard_score_submitted",
            leaderboardKey: payload.leaderboardKey,
            score: payload.score
          }),
          unlockAchievement: async payload => ({
            available: true,
            authenticated: true,
            status: "achievement_unlocked",
            achievementKey: payload.achievementKey
          }),
          openLeaderboards: async () => ({
            available: true,
            authenticated: true,
            status: "leaderboards_opened"
          }),
          openAchievements: async () => ({
            available: true,
            authenticated: true,
            status: "achievements_opened"
          })
        }
      }
    }
  });

  assert.equal(adapter.available, true);
  assert.equal(adapter.leaderboards, false);
  assert.equal(adapter.cloudSave, false);
  assert.equal(adapter.achievements, false);

  const availability = await adapter.isAvailable();
  assert.equal(availability.available, true);
  assert.equal(availability.configured, true);
  assert.equal(availability.playServicesStatus, 0);

  const auth = await adapter.getAuthenticationStatus();
  assert.equal(auth.authenticated, true);

  const player = await adapter.getPlayerSummary();
  assert.equal(player.player.displayName, "Player One");

  const sync = await adapter.syncSavedGame({ payload: { ok: true } });
  assert.equal(sync.payload.schemaVersion, 1);

  const leaderboard = await adapter.submitLeaderboardScore({
    leaderboardKey: "world_challenge_progress",
    score: 195
  });
  assert.equal(leaderboard.score, 195);

  const achievement = await adapter.unlockAchievement({
    achievementKey: "countries_195"
  });
  assert.equal(achievement.achievementKey, "countries_195");
}

async function testNativePluginFailureBecomesStructuredError() {
  const adapter = loadAdapter({
    Capacitor: {
      getPlatform: () => "android",
      Plugins: {
        FlagGamePlayGames: {
          isAvailable: async () => {
            throw new Error("boom");
          }
        }
      }
    }
  });

  const result = await adapter.isAvailable();
  assert.equal(result.available, false);
  assert.equal(result.status, "error");
  assert.equal(result.error.code, "native_call_failed");
  assert.match(result.error.details, /boom/);
}

(async () => {
  for (const test of [
    testWebFallbackDoesNotThrow,
    testAndroidWithoutNativePlugin,
    testNativePluginSuccess,
    testNativePluginFailureBecomesStructuredError
  ]) {
    await test();
    console.log(`ok - ${test.name}`);
  }
})();
