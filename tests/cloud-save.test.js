const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function createMemoryStorage(initial = {}) {
  const store = { ...initial };

  return {
    store,
    createEventId: () => "event-id",
    getRaw(key) {
      return Object.prototype.hasOwnProperty.call(store, key)
        ? store[key]
        : null;
    },
    setRaw(key, value) {
      store[key] = String(value);
      return true;
    },
    getJson(key, fallback) {
      const raw = this.getRaw(key);
      return raw ? JSON.parse(raw) : fallback;
    },
    setJson(key, value) {
      store[key] = JSON.stringify(value);
      return true;
    },
    getString(key, fallback) {
      const raw = this.getRaw(key);
      return raw === null ? fallback : String(raw);
    },
    setString(key, value) {
      store[key] = String(value);
      return true;
    },
    remove(key) {
      delete store[key];
      return true;
    }
  };
}

function loadCloudSave(contextValues = {}) {
  const source = fs.readFileSync(
    path.join(__dirname, "..", "js", "cloud-save.js"),
    "utf8"
  );
  const context = {
    console,
    setTimeout,
    clearTimeout,
    Date,
    Math,
    ...contextValues
  };

  vm.runInNewContext(source, context, {
    filename: "cloud-save.js"
  });

  return context.FlagGameCloudSave;
}

function createSnapshot(overrides = {}) {
  return {
    schemaVersion: 1,
    snapshotType: "flag_game_android_cloud_save",
    mode: "world_challenge",
    updatedAt: "2026-07-19T10:00:00.000Z",
    installationId: "install-a",
    profile: {
      schemaVersion: 2,
      createdAt: "2026-07-19T09:00:00.000Z",
      updatedAt: "2026-07-19T10:00:00.000Z",
      totals: {
        gamesPlayed: 1,
        totalCorrect: 10,
        totalQuestions: 20,
        percentSum: 50,
        timeSecondsSum: 60,
        timedGames: 1,
        bestStreak: 5,
        perfectGames: 0,
        fullRuns195: 0
      },
      modes: { world_challenge: { gamesPlayed: 1 } },
      continentsCompleted: {},
      continentsPerfect: {},
      achievements: { unlocked: {} },
      events: { recorded: {} }
    },
    worldChallenge: {
      schemaVersion: 1,
      mode: "world_challenge",
      createdAt: "2026-07-19T09:00:00.000Z",
      updatedAt: "2026-07-19T10:00:00.000Z",
      historyLimit: 100,
      stats: {
        attempts: 1,
        completions: 0,
        bestCorrectCountries: 10,
        bestStreak: 5,
        fastestCompletionMs: null,
        totalCorrectAnswers: 10,
        totalWrongAnswers: 1,
        totalSkips: 0,
        totalPlayTimeMs: 60000,
        lastPlayedAt: "2026-07-19T10:00:00.000Z"
      },
      history: [
        {
          runId: "run-a",
          startedAt: "2026-07-19T09:59:00.000Z",
          finishedAt: "2026-07-19T10:00:00.000Z",
          correctCountries: 10,
          wrongAnswers: 1,
          skips: 0,
          bestStreak: 5,
          elapsedMs: 60000,
          completed: false,
          livesRemaining: 1,
          continued: false,
          rankingEligible: false,
          platform: "android",
          gameVersion: "test"
        }
      ],
      migrations: { backups: [] }
    },
    achievements: { unlocked: {} },
    recentHistory: [],
    preferences: {
      updatedAt: "2026-07-19T10:00:00.000Z",
      language: "en",
      sound: "off"
    },
    deviceCounters: {
      "install-a": {
        updatedAt: "2026-07-19T10:00:00.000Z",
        gamesPlayed: 1
      }
    },
    ...overrides
  };
}

function createContext(storage, nativeResults = {}) {
  const WorldChallengeStorage = require("../js/world-challenge-storage.js");

  return {
    FlagGameStorage: storage,
    FlagGameWorldChallengeStorage: WorldChallengeStorage,
    FlagGameProfile: {
      readProfile() {
        return storage.getJson("flagGameProfile", createSnapshot().profile);
      },
      saveProfile(profile) {
        storage.setJson("flagGameProfile", profile);
        return profile;
      }
    },
    FlagGamePlatform: {
      getCapabilities() {
        return {
          isAndroidApp: true,
          supportsCloudSave: true
        };
      }
    },
    FlagGamePlayGames: {
      syncSavedGame: async () => nativeResults.sync,
      commitSavedGame: async request => {
        nativeResults.committed = request.payload;
        return nativeResults.commit || {
          available: true,
          status: "snapshot_committed"
        };
      }
    }
  };
}

function testMergeKeepsBestRecordsAndUniqueIds() {
  const storage = createMemoryStorage();
  const CloudSave = loadCloudSave(createContext(storage));
  const local = createSnapshot();
  const remote = createSnapshot({
    updatedAt: "2026-07-19T11:00:00.000Z",
    worldChallenge: {
      ...createSnapshot().worldChallenge,
      stats: {
        ...createSnapshot().worldChallenge.stats,
        bestCorrectCountries: 195,
        fastestCompletionMs: 900000
      },
      history: [
        createSnapshot().worldChallenge.history[0],
        {
          ...createSnapshot().worldChallenge.history[0],
          runId: "run-b",
          correctCountries: 195,
          completed: true,
          elapsedMs: 900000,
          finishedAt: "2026-07-19T11:00:00.000Z"
        }
      ]
    }
  });
  const merged = CloudSave.mergeSnapshots(local, remote);

  assert.equal(merged.worldChallenge.stats.bestCorrectCountries, 195);
  assert.equal(merged.worldChallenge.stats.fastestCompletionMs, 900000);
  assert.equal(merged.worldChallenge.history.length, 2);
}

function testPreferencesUseNewestUpdatedAt() {
  const storage = createMemoryStorage();
  const CloudSave = loadCloudSave(createContext(storage));
  const merged = CloudSave.mergeSnapshots(
    createSnapshot({
      preferences: {
        updatedAt: "2026-07-19T10:00:00.000Z",
        language: "en",
        sound: "off"
      }
    }),
    createSnapshot({
      preferences: {
        updatedAt: "2026-07-19T12:00:00.000Z",
        language: "pt-BR",
        sound: "on"
      }
    })
  );

  assert.equal(merged.preferences.language, "pt-BR");
  assert.equal(merged.preferences.sound, "on");
}

async function testSyncNeverDropsLocalOnCloudFailure() {
  const storage = createMemoryStorage({
    flagGameProfile: JSON.stringify(createSnapshot().profile)
  });
  const CloudSave = loadCloudSave(createContext(storage, {
    sync: {
      available: true,
      error: { code: "network_unavailable" }
    }
  }));

  const before = storage.getRaw("flagGameProfile");
  const result = await CloudSave.syncNow("test");

  assert.equal(result.ok, false);
  assert.equal(storage.getRaw("flagGameProfile"), before);
  assert.equal(CloudSave.readState().pending, true);
}

async function testSyncCommitsMergedConflict() {
  const storage = createMemoryStorage({
    flagGameProfile: JSON.stringify(createSnapshot().profile)
  });
  const remote = createSnapshot({
    worldChallenge: {
      ...createSnapshot().worldChallenge,
      history: [
        {
          ...createSnapshot().worldChallenge.history[0],
          runId: "run-cloud",
          correctCountries: 50,
          finishedAt: "2026-07-19T12:00:00.000Z"
        }
      ]
    }
  });
  const native = {
    sync: {
      available: true,
      status: "snapshot_conflict",
      conflict: true,
      payload: remote,
      conflictingPayload: createSnapshot()
    }
  };
  const CloudSave = loadCloudSave(createContext(storage, native));
  const result = await CloudSave.syncNow("test");

  assert.equal(result.ok, true);
  assert.equal(native.committed.worldChallenge.history.length, 2);
  assert.equal(CloudSave.readState().pending, false);
}

(async () => {
  for (const test of [
    testMergeKeepsBestRecordsAndUniqueIds,
    testPreferencesUseNewestUpdatedAt,
    testSyncNeverDropsLocalOnCloudFailure,
    testSyncCommitsMergedConflict
  ]) {
    await test();
    console.log(`ok - ${test.name}`);
  }
})();
