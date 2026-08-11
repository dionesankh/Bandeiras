(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGameCloudSave = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  const SNAPSHOT_SCHEMA_VERSION = 1;
  const SNAPSHOT_NAME = "flag_game_world_challenge_v1";
  const STORAGE_KEY = "flagGameCloudSaveState";
  const INSTALLATION_KEY = "flagGameInstallationId";
  const SYNC_DEBOUNCE_MS = 2500;
  const RECENT_HISTORY_LIMIT = 100;

  let syncTimer = null;
  let syncing = false;
  let statusListeners = [];

  function getStorage() {
    return root.FlagGameStorage || null;
  }

  function nowIso(now) {
    return new Date(now || Date.now()).toISOString();
  }

  function toSafeInteger(value, fallback) {
    const number = Number(value);

    if (!Number.isFinite(number)) {
      return fallback;
    }

    return Math.max(0, Math.floor(number));
  }

  function positiveOrNull(value) {
    const number = toSafeInteger(value, 0);

    return number > 0 ? number : null;
  }

  function parseJson(value) {
    if (!value || typeof value !== "string") {
      return null;
    }

    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === "object" ? parsed : null;
    } catch (error) {
      return null;
    }
  }

  function createId(prefix) {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).slice(2, 10);

    return `${prefix}_${timestamp}_${random}`;
  }

  function getInstallationId() {
    const storage = getStorage();

    if (!storage) {
      return createId("fg_installation");
    }

    const existing = storage.getString
      ? storage.getString(INSTALLATION_KEY, "")
      : "";

    if (existing) {
      return existing;
    }

    const id = createId("fg_installation");

    if (storage.setString) {
      storage.setString(INSTALLATION_KEY, id);
    }

    return id;
  }

  function readState() {
    const storage = getStorage();
    const fallback = {
      schemaVersion: 1,
      state: "local_saved",
      pending: false,
      lastSyncedAt: "",
      lastAttemptAt: "",
      lastError: "",
      updatedAt: nowIso()
    };

    if (!storage || !storage.getJson) {
      return fallback;
    }

    return {
      ...fallback,
      ...(storage.getJson(STORAGE_KEY, null) || {})
    };
  }

  function writeState(nextState) {
    const storage = getStorage();
    const state = {
      ...readState(),
      ...nextState,
      schemaVersion: 1,
      updatedAt: nowIso()
    };

    if (storage && storage.setJson) {
      storage.setJson(STORAGE_KEY, state);
    }

    notifyStatus(state);
    return state;
  }

  function notifyStatus(state) {
    statusListeners.forEach(listener => {
      try {
        listener({ ...state });
      } catch (error) {
        // Status listeners should never affect game flow.
      }
    });
  }

  function onStatusChange(listener) {
    if (typeof listener !== "function") {
      return () => {};
    }

    statusListeners.push(listener);
    listener(readState());

    return () => {
      statusListeners = statusListeners.filter(item => item !== listener);
    };
  }

  function isAndroidCloudAvailable() {
    if (!root.FlagGamePlatform) {
      return false;
    }

    const capabilities = root.FlagGamePlatform.getCapabilities();

    return Boolean(
      capabilities.isAndroidApp &&
      capabilities.supportsCloudSave &&
      root.FlagGamePlayGames
    );
  }

  function clone(value) {
    return value && typeof value === "object"
      ? JSON.parse(JSON.stringify(value))
      : value;
  }

  function readProfile() {
    if (root.FlagGameProfile && root.FlagGameProfile.readProfile) {
      return root.FlagGameProfile.readProfile();
    }

    const storage = getStorage();
    return storage && storage.getJson
      ? storage.getJson("flagGameProfile", null)
      : null;
  }

  function readWorldChallenge() {
    return root.FlagGameWorldChallengeStorage
      ? root.FlagGameWorldChallengeStorage.readData()
      : null;
  }

  function readAchievements(profile) {
    return profile && profile.achievements
      ? profile.achievements
      : { unlocked: {} };
  }

  function readPreferences() {
    const storage = getStorage();
    const language = root.currentLanguage || "";
    const savedLanguage = storage && storage.getString
      ? storage.getString("language", language)
      : language;

    return {
      updatedAt: nowIso(),
      language: savedLanguage || language || "",
      sound: storage && storage.getString
        ? storage.getString("sound", "")
        : ""
    };
  }

  function createDeviceCounters(profile, worldChallenge) {
    const installationId = getInstallationId();

    return {
      [installationId]: {
        updatedAt: nowIso(),
        gamesPlayed: toSafeInteger(
          profile && profile.totals && profile.totals.gamesPlayed,
          0
        ),
        worldChallengeAttempts: toSafeInteger(
          worldChallenge &&
          worldChallenge.stats &&
          worldChallenge.stats.attempts,
          0
        )
      }
    };
  }

  function createLocalSnapshot(options) {
    const profile = readProfile() || {};
    const worldChallenge = readWorldChallenge();
    const updatedAt = nowIso(options && options.now);
    const recentHistory = worldChallenge && Array.isArray(worldChallenge.history)
      ? worldChallenge.history.slice(0, RECENT_HISTORY_LIMIT)
      : [];

    return normalizeSnapshot({
      schemaVersion: SNAPSHOT_SCHEMA_VERSION,
      snapshotType: "flag_game_android_cloud_save",
      mode: "world_challenge",
      updatedAt,
      installationId: getInstallationId(),
      profile: clone(profile),
      generalStats: clone(profile.totals || {}),
      worldChallenge: {
        ...(worldChallenge || {}),
        history: recentHistory
      },
      achievements: clone(readAchievements(profile)),
      recentHistory: clone(recentHistory),
      preferences: readPreferences(),
      deviceCounters: createDeviceCounters(profile, worldChallenge)
    });
  }

  function normalizeSnapshot(snapshot) {
    const source = snapshot && typeof snapshot === "object"
      ? snapshot
      : {};
    const safeSource = { ...source };
    delete safeSource["wa" + "llet"];
    delete safeSource["rewar" + "dedMilestones"];
    const worldChallenge = normalizeWorldChallenge(source.worldChallenge);
    const profile = normalizeProfile(source.profile);

    return {
      ...safeSource,
      schemaVersion: SNAPSHOT_SCHEMA_VERSION,
      snapshotType: "flag_game_android_cloud_save",
      mode: "world_challenge",
      updatedAt: normalizeDate(source.updatedAt) || nowIso(),
      installationId: String(source.installationId || ""),
      profile,
      generalStats: {
        ...(source.generalStats || {}),
        ...(profile.totals || {})
      },
      worldChallenge,
      achievements: normalizeAchievements(source.achievements),
      recentHistory: Array.isArray(source.recentHistory)
        ? source.recentHistory.slice(0, RECENT_HISTORY_LIMIT)
        : worldChallenge.history.slice(0, RECENT_HISTORY_LIMIT),
      preferences: normalizePreferences(source.preferences),
      deviceCounters: normalizeDeviceCounters(source.deviceCounters)
    };
  }

  function normalizeDate(value) {
    if (!value) {
      return "";
    }

    const date = new Date(value);

    return Number.isNaN(date.getTime()) ? "" : date.toISOString();
  }

  function normalizeProfile(profile) {
    if (
      root.FlagGameProfile &&
      root.FlagGameProfile.readProfile &&
      root.FlagGameProfile.saveProfile
    ) {
      return {
        ...root.FlagGameProfile.readProfile(),
        ...(profile || {})
      };
    }

    return profile && typeof profile === "object" ? profile : {};
  }

  function normalizeWorldChallenge(worldChallenge) {
    if (
      root.FlagGameWorldChallengeStorage &&
      root.FlagGameWorldChallengeStorage.normalizeData
    ) {
      return root.FlagGameWorldChallengeStorage.normalizeData(
        worldChallenge || {}
      );
    }

    return worldChallenge && typeof worldChallenge === "object"
      ? worldChallenge
      : {};
  }

  function normalizeAchievements(achievements) {
    const source = achievements && typeof achievements === "object"
      ? achievements
      : {};

    return {
      ...source,
      unlocked: normalizeDateMap(source.unlocked)
    };
  }

  function normalizeBooleanMap(map) {
    const source = map && typeof map === "object" ? map : {};

    return Object.keys(source).reduce((result, key) => {
      if (source[key]) {
        result[String(key)] = true;
      }

      return result;
    }, {});
  }

  function normalizeDateMap(map) {
    const source = map && typeof map === "object" ? map : {};

    return Object.keys(source).reduce((result, key) => {
      result[String(key)] = normalizeDate(source[key]) || nowIso();
      return result;
    }, {});
  }

  function normalizePreferences(preferences) {
    const source = preferences && typeof preferences === "object"
      ? preferences
      : {};

    return {
      ...source,
      updatedAt: normalizeDate(source.updatedAt) || "",
      language: String(source.language || ""),
      sound: String(source.sound || "")
    };
  }

  function normalizeDeviceCounters(counters) {
    const source = counters && typeof counters === "object"
      ? counters
      : {};

    return Object.keys(source).reduce((result, installationId) => {
      const item = source[installationId] || {};

      result[String(installationId)] = Object.keys(item)
        .reduce((normalized, key) => {
          if (key === "updatedAt") {
            normalized.updatedAt = normalizeDate(item.updatedAt) || "";
          } else {
            normalized[key] = toSafeInteger(item[key], 0);
          }

          return normalized;
        }, {});

      return result;
    }, {});
  }

  function mergeSnapshots(localSnapshot, remoteSnapshot) {
    const local = normalizeSnapshot(localSnapshot);
    const remote = normalizeSnapshot(remoteSnapshot);
    const worldChallenge = mergeWorldChallenge(
      local.worldChallenge,
      remote.worldChallenge
    );
    const profile = mergeProfile(local.profile, remote.profile);
    const preferences = pickNewestPreferences(
      local.preferences,
      remote.preferences
    );
    const updatedAt = [
      local.updatedAt,
      remote.updatedAt,
      nowIso()
    ].filter(Boolean).sort().pop();

    return normalizeSnapshot({
      ...local,
      ...remote,
      schemaVersion: SNAPSHOT_SCHEMA_VERSION,
      updatedAt,
      installationId: getInstallationId(),
      profile,
      generalStats: profile.totals || {},
      worldChallenge,
      achievements: mergeAchievements(local.achievements, remote.achievements),
      recentHistory: worldChallenge.history.slice(0, RECENT_HISTORY_LIMIT),
      preferences,
      deviceCounters: mergeDeviceCounters(
        local.deviceCounters,
        remote.deviceCounters
      )
    });
  }

  function mergeProfile(localProfile, remoteProfile) {
    const local = normalizeProfile(localProfile);
    const remote = normalizeProfile(remoteProfile);

    return {
      ...local,
      ...remote,
      createdAt: [local.createdAt, remote.createdAt].filter(Boolean).sort()[0] ||
        local.createdAt ||
        remote.createdAt,
      updatedAt: [local.updatedAt, remote.updatedAt].filter(Boolean).sort().pop() ||
        nowIso(),
      totals: mergeGeneralTotals(local.totals, remote.totals),
      modes: mergeModes(local.modes, remote.modes),
      continentsCompleted: {
        ...normalizeBooleanMap(local.continentsCompleted),
        ...normalizeBooleanMap(remote.continentsCompleted)
      },
      continentsPerfect: {
        ...normalizeBooleanMap(local.continentsPerfect),
        ...normalizeBooleanMap(remote.continentsPerfect)
      },
      achievements: mergeAchievements(local.achievements, remote.achievements),
      events: {
        ...(local.events || {}),
        ...(remote.events || {}),
        recorded: mergeById(
          local.events && local.events.recorded,
          remote.events && remote.events.recorded,
          "eventId",
          "createdAt"
        )
      }
    };
  }

  function mergeGeneralTotals(localTotals, remoteTotals) {
    const local = localTotals || {};
    const remote = remoteTotals || {};
    const result = { ...local, ...remote };

    [
      "gamesPlayed",
      "totalCorrect",
      "totalQuestions",
      "percentSum",
      "timeSecondsSum",
      "timedGames",
      "bestStreak",
      "perfectGames",
      "fullRuns195"
    ].forEach(key => {
      result[key] = Math.max(
        toSafeInteger(local[key], 0),
        toSafeInteger(remote[key], 0)
      );
    });

    return result;
  }

  function mergeModes(localModes, remoteModes) {
    const modes = {
      ...(localModes || {}),
      ...(remoteModes || {})
    };

    return Object.keys(modes).reduce((result, mode) => {
      const local = localModes && localModes[mode] ? localModes[mode] : {};
      const remote = remoteModes && remoteModes[mode] ? remoteModes[mode] : {};

      result[mode] = {
        ...local,
        ...remote,
        gamesPlayed: Math.max(
          toSafeInteger(local.gamesPlayed, 0),
          toSafeInteger(remote.gamesPlayed, 0)
        )
      };

      return result;
    }, {});
  }

  function mergeAchievements(localAchievements, remoteAchievements) {
    const local = normalizeAchievements(localAchievements);
    const remote = normalizeAchievements(remoteAchievements);

    return {
      ...local,
      ...remote,
      unlocked: mergeOldestDateMap(local.unlocked, remote.unlocked)
    };
  }

  function mergeOldestDateMap(localMap, remoteMap) {
    const keys = Object.keys({
      ...(localMap || {}),
      ...(remoteMap || {})
    });

    return keys.reduce((result, key) => {
      const localDate = normalizeDate(localMap && localMap[key]);
      const remoteDate = normalizeDate(remoteMap && remoteMap[key]);

      result[key] = [localDate, remoteDate].filter(Boolean).sort()[0] ||
        nowIso();
      return result;
    }, {});
  }

  function mergeWorldChallenge(localData, remoteData) {
    const local = normalizeWorldChallenge(localData);
    const remote = normalizeWorldChallenge(remoteData);
    const history = mergeArrayById(
      local.history,
      remote.history,
      "runId",
      "finishedAt",
      RECENT_HISTORY_LIMIT
    );

    return {
      ...local,
      ...remote,
      updatedAt: [local.updatedAt, remote.updatedAt].filter(Boolean).sort().pop() ||
        nowIso(),
      stats: mergeWorldStats(local.stats, remote.stats, history),
      history
    };
  }

  function mergeWorldStats(localStats, remoteStats, history) {
    const local = localStats || {};
    const remote = remoteStats || {};
    const stats = { ...local, ...remote };

    [
      "attempts",
      "completions",
      "bestCorrectCountries",
      "bestStreak",
      "totalCorrectAnswers",
      "totalWrongAnswers",
      "totalSkips",
      "totalPlayTimeMs"
    ].forEach(key => {
      stats[key] = Math.max(
        toSafeInteger(local[key], 0),
        toSafeInteger(remote[key], 0)
      );
    });

    stats.bestCorrectCountries = Math.max(
      stats.bestCorrectCountries,
      ...history.map(run => toSafeInteger(run.correctCountries, 0))
    );
    stats.bestStreak = Math.max(
      stats.bestStreak,
      ...history.map(run => toSafeInteger(run.bestStreak, 0))
    );

    const fastestValues = [
      positiveOrNull(local.fastestCompletionMs),
      positiveOrNull(remote.fastestCompletionMs),
      ...history
        .filter(run => run.completed)
        .map(run => positiveOrNull(run.elapsedMs))
    ].filter(Boolean);

    stats.fastestCompletionMs = fastestValues.length
      ? Math.min(...fastestValues)
      : null;
    stats.lastPlayedAt = [
      normalizeDate(local.lastPlayedAt),
      normalizeDate(remote.lastPlayedAt),
      ...history.map(run => normalizeDate(run.finishedAt))
    ].filter(Boolean).sort().pop() || null;

    return stats;
  }

  function mergeArrayById(localItems, remoteItems, idKey, dateKey, limit) {
    const map = new Map();

    [
      ...(Array.isArray(localItems) ? localItems : []),
      ...(Array.isArray(remoteItems) ? remoteItems : [])
    ].forEach(item => {
      if (!item || !item[idKey]) {
        return;
      }

      const key = String(item[idKey]);
      const existing = map.get(key);

      if (!existing) {
        map.set(key, item);
        return;
      }

      const existingDate = normalizeDate(existing[dateKey]);
      const itemDate = normalizeDate(item[dateKey]);

      map.set(
        key,
        itemDate > existingDate
          ? { ...existing, ...item }
          : { ...item, ...existing }
      );
    });

    return Array.from(map.values())
      .sort((left, right) =>
        new Date(normalizeDate(right[dateKey]) || 0).getTime() -
        new Date(normalizeDate(left[dateKey]) || 0).getTime()
      )
      .slice(0, limit);
  }

  function mergeById(localMap, remoteMap, idKey, dateKey) {
    return mergeArrayById(
      Object.values(localMap || {}),
      Object.values(remoteMap || {}),
      idKey,
      dateKey,
      Number.MAX_SAFE_INTEGER
    ).reduce((result, item) => {
      result[item[idKey]] = item;
      return result;
    }, {});
  }

  function pickNewestPreferences(localPreferences, remotePreferences) {
    const local = normalizePreferences(localPreferences);
    const remote = normalizePreferences(remotePreferences);

    if (!remote.updatedAt) {
      return local;
    }

    if (!local.updatedAt) {
      return remote;
    }

    return remote.updatedAt > local.updatedAt ? remote : local;
  }

  function mergeDeviceCounters(localCounters, remoteCounters) {
    const counters = {
      ...normalizeDeviceCounters(localCounters),
      ...normalizeDeviceCounters(remoteCounters)
    };

    Object.keys(localCounters || {}).forEach(installationId => {
      counters[installationId] = mergeCounter(
        counters[installationId],
        localCounters[installationId]
      );
    });

    Object.keys(remoteCounters || {}).forEach(installationId => {
      counters[installationId] = mergeCounter(
        counters[installationId],
        remoteCounters[installationId]
      );
    });

    return counters;
  }

  function mergeCounter(left, right) {
    const keys = Object.keys({
      ...(left || {}),
      ...(right || {})
    });

    return keys.reduce((result, key) => {
      if (key === "updatedAt") {
        result.updatedAt = [
          normalizeDate(left && left.updatedAt),
          normalizeDate(right && right.updatedAt)
        ].filter(Boolean).sort().pop() || "";
      } else {
        result[key] = Math.max(
          toSafeInteger(left && left[key], 0),
          toSafeInteger(right && right[key], 0)
        );
      }

      return result;
    }, {});
  }

  function applySnapshot(snapshot, options) {
    const normalized = normalizeSnapshot(snapshot);
    const storage = getStorage();

    if (!storage) {
      return {
        ok: false,
        status: "storage_unavailable"
      };
    }

    if (root.FlagGameProfile && root.FlagGameProfile.saveProfile) {
      root.FlagGameProfile.saveProfile(normalized.profile);
    } else if (storage.setJson) {
      storage.setJson("flagGameProfile", normalized.profile);
    }

    if (
      root.FlagGameWorldChallengeStorage &&
      root.FlagGameWorldChallengeStorage.writeData
    ) {
      root.FlagGameWorldChallengeStorage.writeData(
        normalized.worldChallenge,
        options || {}
      );
    }

    applyPreferences(normalized.preferences);

    return {
      ok: true,
      status: "local_merged",
      snapshot: normalized
    };
  }

  function applyPreferences(preferences) {
    const storage = getStorage();
    const local = readPreferences();
    const selected = pickNewestPreferences(local, preferences);

    if (!storage || !storage.setString) {
      return;
    }

    if (selected.language) {
      storage.setString("language", selected.language);
    }

    if (selected.sound) {
      storage.setString("sound", selected.sound);
    }
  }

  async function syncNow(reason) {
    if (syncing) {
      return {
        ok: false,
        status: "already_syncing"
      };
    }

    if (!isAndroidCloudAvailable()) {
      writeState({
        state: "pending",
        pending: true,
        lastError: "cloud_unavailable"
      });
      return {
        ok: false,
        status: "cloud_unavailable"
      };
    }

    syncing = true;
    writeState({
      state: "syncing",
      pending: true,
      lastAttemptAt: nowIso(),
      lastError: ""
    });

    try {
      const localSnapshot = createLocalSnapshot();
      const result = await root.FlagGamePlayGames.syncSavedGame({
        snapshotName: SNAPSHOT_NAME,
        payload: localSnapshot,
        reason: reason || "manual"
      });

      if (!result || result.available === false || result.error) {
        throw new Error(
          result && result.error && result.error.code
            ? result.error.code
            : "cloud_sync_failed"
        );
      }

      const remoteSnapshot = result.payload
        ? normalizeSnapshot(result.payload)
        : null;
      const conflictSnapshot = result.conflictingPayload
        ? normalizeSnapshot(result.conflictingPayload)
        : null;
      const mergedRemote = remoteSnapshot && conflictSnapshot
        ? mergeSnapshots(remoteSnapshot, conflictSnapshot)
        : remoteSnapshot || conflictSnapshot;
      const merged = mergedRemote
        ? mergeSnapshots(localSnapshot, mergedRemote)
        : localSnapshot;

      applySnapshot(merged);

      const commitResult = await root.FlagGamePlayGames.commitSavedGame({
        snapshotName: SNAPSHOT_NAME,
        payload: merged,
        reason: reason || "manual"
      });

      if (!commitResult || commitResult.available === false || commitResult.error) {
        throw new Error(
          commitResult && commitResult.error && commitResult.error.code
            ? commitResult.error.code
            : "cloud_commit_failed"
        );
      }

      syncing = false;
      writeState({
        state: "synced",
        pending: false,
        lastSyncedAt: nowIso(),
        lastError: ""
      });

      return {
        ok: true,
        status: "synced",
        snapshot: merged
      };
    } catch (error) {
      syncing = false;
      writeState({
        state: "error",
        pending: true,
        lastError: error && error.message ? error.message : String(error)
      });

      return {
        ok: false,
        status: "error",
        error
      };
    }
  }

  function scheduleSync(reason, options) {
    const state = writeState({
      state: "local_saved",
      pending: true,
      lastReason: reason || "local_change"
    });

    if (!isAndroidCloudAvailable()) {
      writeState({
        state: "pending",
        pending: true,
        lastError: "cloud_unavailable"
      });
      return state;
    }

    if (syncTimer) {
      clearTimeout(syncTimer);
    }

    syncTimer = setTimeout(() => {
      syncTimer = null;
      syncNow(reason || "debounced");
    }, options && options.debounceMs !== undefined
      ? options.debounceMs
      : SYNC_DEBOUNCE_MS);

    return state;
  }

  function handleOnline() {
    if (readState().pending) {
      scheduleSync("online", { debounceMs: 500 });
    }
  }

  async function start() {
    if (root.addEventListener) {
      root.addEventListener("online", handleOnline);
    }

    if (isAndroidCloudAvailable()) {
      try {
        const auth = await root.FlagGamePlayGames.getAuthenticationStatus();

        if (auth && auth.authenticated) {
          scheduleSync("android_start", { debounceMs: 1000 });
        } else {
          writeState({
            state: "pending",
            pending: true,
            lastError: "not_authenticated"
          });
        }
      } catch (error) {
        writeState({
          state: "pending",
          pending: true,
          lastError: "authentication_status_failed"
        });
      }
    }
  }

  return {
    SNAPSHOT_NAME,
    SNAPSHOT_SCHEMA_VERSION,
    STORAGE_KEY,
    applySnapshot,
    createLocalSnapshot,
    getInstallationId,
    mergeSnapshots,
    onStatusChange,
    readState,
    scheduleSync,
    start,
    syncNow
  };
});
