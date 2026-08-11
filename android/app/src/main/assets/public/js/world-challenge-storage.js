(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.FlagGameWorldChallengeStorage = factory();
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function () {
  const STORAGE_KEY = "flagGameWorldChallenge";
  const BACKUP_KEY = "flagGameWorldChallengeBackup";
  const TEMP_KEY = "flagGameWorldChallengeTemp";
  const LEGACY_RECORDS_KEY = "flagGameWorldChallengeRecords";
  const MODE = "world_challenge";
  const SCHEMA_VERSION = 1;
  const HISTORY_LIMIT = 100;

  const STATS_DEFAULTS = {
    attempts: 0,
    completions: 0,
    bestCorrectCountries: 0,
    bestStreak: 0,
    fastestCompletionMs: null,
    totalCorrectAnswers: 0,
    totalWrongAnswers: 0,
    totalSkips: 0,
    totalPlayTimeMs: 0,
    lastPlayedAt: null
  };

  function getDefaultStorage() {
    if (
      typeof FlagGameStorage !== "undefined" &&
      FlagGameStorage
    ) {
      return FlagGameStorage;
    }

    const memoryStore = {};

    return {
      getRaw(key) {
        return Object.prototype.hasOwnProperty.call(memoryStore, key)
          ? memoryStore[key]
          : null;
      },
      setRaw(key, value) {
        memoryStore[key] = String(value);
        return true;
      }
    };
  }

  function toSafeInteger(value, fallback) {
    const number = Number(value);

    if (!Number.isFinite(number)) {
      return fallback;
    }

    return Math.max(0, Math.floor(number));
  }

  function toSafeNullableInteger(value) {
    if (value === null || value === undefined || value === "") {
      return null;
    }

    return toSafeInteger(value, 0);
  }

  function toBoolean(value) {
    return value === true;
  }

  function toIsoString(value, fallback) {
    if (!value) {
      return fallback || null;
    }

    const date = new Date(value);

    return Number.isNaN(date.getTime())
      ? (fallback || null)
      : date.toISOString();
  }

  function nowIso(now) {
    return new Date(now || Date.now()).toISOString();
  }

  function createEmptyData(now) {
    const createdAt = nowIso(now);

    return {
      schemaVersion: SCHEMA_VERSION,
      mode: MODE,
      createdAt,
      updatedAt: createdAt,
      historyLimit: HISTORY_LIMIT,
      stats: { ...STATS_DEFAULTS },
      history: [],
      migrations: {
        backups: []
      }
    };
  }

  function normalizeStats(stats) {
    const source = stats && typeof stats === "object"
      ? stats
      : {};

    return {
      ...source,
      attempts: toSafeInteger(source.attempts, 0),
      completions: toSafeInteger(source.completions, 0),
      bestCorrectCountries: toSafeInteger(source.bestCorrectCountries, 0),
      bestStreak: toSafeInteger(source.bestStreak, 0),
      fastestCompletionMs: toSafeNullableInteger(source.fastestCompletionMs),
      totalCorrectAnswers: toSafeInteger(source.totalCorrectAnswers, 0),
      totalWrongAnswers: toSafeInteger(source.totalWrongAnswers, 0),
      totalSkips: toSafeInteger(source.totalSkips, 0),
      totalPlayTimeMs: toSafeInteger(source.totalPlayTimeMs, 0),
      lastPlayedAt: toIsoString(source.lastPlayedAt, null)
    };
  }

  function normalizeRun(run, now) {
    const source = run && typeof run === "object"
      ? run
      : {};
    const startedAt =
      toIsoString(source.startedAt, null) || nowIso(now);
    const finishedAt =
      toIsoString(source.finishedAt, null) || startedAt;
    const elapsedMs = toSafeInteger(source.elapsedMs, 0);

    return {
      ...source,
      runId: String(source.runId || createRunId(now)),
      startedAt,
      finishedAt,
      correctCountries: toSafeInteger(source.correctCountries, 0),
      wrongAnswers: toSafeInteger(source.wrongAnswers, 0),
      skips: toSafeInteger(source.skips, 0),
      bestStreak: toSafeInteger(source.bestStreak, 0),
      elapsedMs,
      completed: toBoolean(source.completed),
      livesRemaining: toSafeInteger(source.livesRemaining, 0),
      continued: toBoolean(source.continued),
      rankingEligible: toBoolean(source.rankingEligible),
      platform: String(source.platform || detectPlatform()),
      gameVersion: String(source.gameVersion || getGameVersion())
    };
  }

  function normalizeHistory(history, now, limit) {
    const seen = new Set();
    const normalized = [];

    (Array.isArray(history) ? history : []).forEach(run => {
      const normalizedRun = normalizeRun(run, now);

      if (seen.has(normalizedRun.runId)) {
        return;
      }

      seen.add(normalizedRun.runId);
      normalized.push(normalizedRun);
    });

    return normalized
      .sort((left, right) =>
        new Date(right.finishedAt).getTime() -
        new Date(left.finishedAt).getTime()
      )
      .slice(0, limit);
  }

  function normalizeData(data, options) {
    const now = options && options.now;
    const empty = createEmptyData(now);
    const source = data && typeof data === "object"
      ? data
      : {};
    const limit = Math.max(
      1,
      toSafeInteger(source.historyLimit, HISTORY_LIMIT) || HISTORY_LIMIT
    );

    return {
      ...empty,
      ...source,
      schemaVersion: SCHEMA_VERSION,
      mode: MODE,
      createdAt: toIsoString(source.createdAt, empty.createdAt) ||
        empty.createdAt,
      updatedAt: toIsoString(source.updatedAt, empty.updatedAt) ||
        empty.updatedAt,
      historyLimit: limit,
      stats: normalizeStats(source.stats),
      history: normalizeHistory(source.history, now, limit),
      migrations: {
        ...empty.migrations,
        ...(source.migrations || {}),
        backups: Array.isArray(source.migrations && source.migrations.backups)
          ? source.migrations.backups.slice()
          : []
      }
    };
  }

  function parseStored(raw) {
    if (!raw) {
      return {
        data: null,
        invalid: false
      };
    }

    try {
      return {
        data: JSON.parse(raw),
        invalid: false
      };

    } catch (error) {
      return {
        data: null,
        invalid: true,
        error
      };
    }
  }

  function createDataFromLegacyRecords(raw, options) {
    const parsed = parseStored(raw);

    if (!parsed.data || typeof parsed.data !== "object") {
      return null;
    }

    const legacy = parsed.data;
    const data = createEmptyData(options && options.now);
    const bestCompletedSeconds =
      toSafeNullableInteger(legacy.bestCompletedSeconds);

    data.stats = {
      ...data.stats,
      attempts: toSafeInteger(legacy.gamesPlayed, 0),
      completions: bestCompletedSeconds === null ? 0 : 1,
      bestCorrectCountries: toSafeInteger(legacy.bestProgress, 0),
      bestStreak: toSafeInteger(legacy.bestStreak, 0),
      fastestCompletionMs: bestCompletedSeconds === null
        ? null
        : bestCompletedSeconds * 1000
    };
    data.legacyRecords = {
      ...legacy,
      migratedFrom: LEGACY_RECORDS_KEY
    };

    return data;
  }

  function shouldBackup(rawData) {
    return Boolean(
      rawData &&
      (
        rawData.schemaVersion !== SCHEMA_VERSION ||
        rawData.mode !== MODE ||
        !rawData.stats ||
        !Array.isArray(rawData.history)
      )
    );
  }

  function writeAtomic(storage, data) {
    const serialized = JSON.stringify(data);

    if (storage.setRaw) {
      storage.setRaw(TEMP_KEY, serialized);
      storage.setRaw(STORAGE_KEY, serialized);

      if (storage.remove) {
        storage.remove(TEMP_KEY);
      }

      return true;
    }

    return storage.setJson(STORAGE_KEY, data);
  }

  function writeBackup(storage, raw, reason, now) {
    if (!raw || !storage.setRaw) {
      return null;
    }

    const backupId = `${BACKUP_KEY}:${Date.now().toString(36)}`;
    const backupPayload = JSON.stringify({
      schemaVersion: 1,
      createdAt: nowIso(now),
      reason,
      storageKey: STORAGE_KEY,
      raw
    });

    storage.setRaw(backupId, backupPayload);

    return backupId;
  }

  function readData(options) {
    const storage = (options && options.storage) || getDefaultStorage();
    const raw = storage.getRaw
      ? storage.getRaw(STORAGE_KEY)
      : JSON.stringify(storage.getJson(STORAGE_KEY, null));
    const legacyRaw = !raw && storage.getRaw
      ? storage.getRaw(LEGACY_RECORDS_KEY)
      : null;
    const legacyData = legacyRaw
      ? createDataFromLegacyRecords(legacyRaw, options || {})
      : null;
    const parsed = parseStored(raw);
    const backupReason = parsed.invalid
      ? "invalid_json"
      : legacyData
        ? "legacy_records_migration"
      : shouldBackup(parsed.data)
        ? "schema_migration"
        : "";
    const backupId = backupReason && (raw || legacyRaw)
      ? writeBackup(
        storage,
        raw || legacyRaw,
        backupReason,
        options && options.now
      )
      : null;
    const data = normalizeData(
      legacyData || parsed.data,
      options || {}
    );

    if (backupId) {
      data.migrations.backups = [
        ...data.migrations.backups,
        {
          backupId,
          reason: backupReason,
          createdAt: nowIso(options && options.now)
        }
      ];
      data.updatedAt = nowIso(options && options.now);
      writeAtomic(storage, data);
    }

    return data;
  }

  function createRunId(now) {
    const timestamp = new Date(now || Date.now()).getTime().toString(36);
    const random = Math.random().toString(36).slice(2, 10);

    return `wc_run_${timestamp}_${random}`;
  }

  function detectPlatform() {
    if (
      typeof FlagGamePlatform !== "undefined" &&
      FlagGamePlatform
    ) {
      const capabilities = FlagGamePlatform.getCapabilities();

      if (capabilities.isAndroidApp) {
        return "android";
      }

      if (capabilities.isChromeExtension) {
        return "chrome_extension";
      }

      if (capabilities.isEdgeExtension) {
        return "edge_extension";
      }

      if (capabilities.isFirefoxExtension) {
        return "firefox_extension";
      }

      return "web";
    }

    if (typeof navigator === "undefined") {
      return "node";
    }

    const userAgent = navigator.userAgent || "";

    if (/Android/i.test(userAgent)) {
      return "android";
    }

    if (
      typeof chrome !== "undefined" &&
      chrome.runtime &&
      chrome.runtime.id
    ) {
      return "extension";
    }

    return "web";
  }

  function getGameVersion() {
    if (
      typeof window !== "undefined" &&
      window.FLAG_GAME_VERSION
    ) {
      return String(window.FLAG_GAME_VERSION);
    }

    if (
      typeof document !== "undefined" &&
      document.documentElement &&
      document.documentElement.dataset.gameVersion
    ) {
      return String(document.documentElement.dataset.gameVersion);
    }

    return "local";
  }

  function recordRun(run, options) {
    const storage = (options && options.storage) || getDefaultStorage();
    const now = (options && options.now) || Date.now();
    const data = readData({ ...(options || {}), storage, now });
    const normalizedRun = normalizeRun(run, now);
    const alreadyRecorded = data.history.some(
      item => item.runId === normalizedRun.runId
    );

    if (alreadyRecorded) {
      return {
        data,
        run: normalizedRun,
        duplicate: true
      };
    }

    const nextStats = normalizeStats(data.stats);
    nextStats.attempts += 1;
    nextStats.completions += normalizedRun.completed ? 1 : 0;
    nextStats.bestCorrectCountries = Math.max(
      nextStats.bestCorrectCountries,
      normalizedRun.correctCountries
    );
    nextStats.bestStreak = Math.max(
      nextStats.bestStreak,
      normalizedRun.bestStreak
    );
    nextStats.totalCorrectAnswers += normalizedRun.correctCountries;
    nextStats.totalWrongAnswers += normalizedRun.wrongAnswers;
    nextStats.totalSkips += normalizedRun.skips;
    nextStats.totalPlayTimeMs += normalizedRun.elapsedMs;
    nextStats.lastPlayedAt = normalizedRun.finishedAt;

    if (
      normalizedRun.completed &&
      (
        nextStats.fastestCompletionMs === null ||
        normalizedRun.elapsedMs < nextStats.fastestCompletionMs
      )
    ) {
      nextStats.fastestCompletionMs = normalizedRun.elapsedMs;
    }

    const nextData = {
      ...data,
      updatedAt: nowIso(now),
      stats: nextStats,
      history: [
        normalizedRun,
        ...data.history
      ].slice(0, data.historyLimit || HISTORY_LIMIT)
    };

    writeAtomic(storage, nextData);

    return {
      data: nextData,
      run: normalizedRun,
      duplicate: false
    };
  }

  function getStats(options) {
    return readData(options).stats;
  }

  function writeData(data, options) {
    const storage = (options && options.storage) || getDefaultStorage();
    const now = (options && options.now) || Date.now();
    const normalized = normalizeData(data, { ...(options || {}), now });

    normalized.updatedAt = nowIso(now);

    return {
      data: normalized,
      written: writeAtomic(storage, normalized)
    };
  }

  return {
    HISTORY_LIMIT,
    MODE,
    SCHEMA_VERSION,
    STORAGE_KEY,
    createEmptyData,
    createRunId,
    getStats,
    normalizeData,
    normalizeRun,
    readData,
    recordRun,
    writeData
  };
});
