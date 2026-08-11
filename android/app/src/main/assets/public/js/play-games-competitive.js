(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGamePlayGamesCompetitive = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  const STORAGE_KEY = "flagGamePlayGamesCompetitive";
  const SCHEMA_VERSION = 1;
  const RETRY_DEBOUNCE_MS = 3000;
  const LEADERBOARDS = {
    progress: "world_challenge_progress",
    streak: "world_challenge_streak",
    fastest195: "world_challenge_fastest_195"
  };
  const ACHIEVEMENTS = {
    firstAttempt: "first_attempt",
    countries25: "countries_25",
    countries50: "countries_50",
    countries100: "countries_100",
    countries150: "countries_150",
    countries195: "countries_195",
    streak50: "streak_50",
    streak100: "streak_100",
    completeOneLife: "complete_one_life",
    completeNoLivesLost: "complete_no_lives_lost"
  };

  let statusListeners = [];
  let retryTimer = null;

  function nowIso() {
    return new Date().toISOString();
  }

  function getStorage() {
    return root.FlagGameStorage || null;
  }

  function readState() {
    const storage = getStorage();
    const fallback = {
      schemaVersion: SCHEMA_VERSION,
      updatedAt: nowIso(),
      pendingRuns: [],
      submittedRuns: {},
      submittedAchievements: {},
      status: "idle",
      lastError: "",
      lastSubmittedAt: ""
    };

    if (!storage || !storage.getJson) {
      return fallback;
    }

    const saved = storage.getJson(STORAGE_KEY, null);

    return normalizeState(saved || fallback);
  }

  function normalizeState(state) {
    const source = state && typeof state === "object" ? state : {};

    return {
      ...source,
      schemaVersion: SCHEMA_VERSION,
      updatedAt: source.updatedAt || nowIso(),
      pendingRuns: Array.isArray(source.pendingRuns)
        ? dedupePendingRuns(source.pendingRuns)
        : [],
      submittedRuns: source.submittedRuns &&
        typeof source.submittedRuns === "object"
          ? source.submittedRuns
          : {},
      submittedAchievements: source.submittedAchievements &&
        typeof source.submittedAchievements === "object"
          ? source.submittedAchievements
          : {},
      status: String(source.status || "idle"),
      lastError: String(source.lastError || ""),
      lastSubmittedAt: String(source.lastSubmittedAt || "")
    };
  }

  function writeState(nextState) {
    const storage = getStorage();
    const state = normalizeState({
      ...readState(),
      ...nextState,
      updatedAt: nowIso()
    });

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
        // UI listeners must not affect game flow.
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

  function getCapabilities() {
    return root.FlagGamePlatform
      ? root.FlagGamePlatform.getCapabilities()
      : {};
  }

  function isAndroidPlayGamesAvailable() {
    const capabilities = getCapabilities();

    return Boolean(
      capabilities.isAndroidApp &&
      root.FlagGamePlayGames &&
      root.FlagGamePlayGames.available
    );
  }

  function supportsLeaderboards() {
    const capabilities = getCapabilities();

    return Boolean(
      isAndroidPlayGamesAvailable() &&
      capabilities.supportsGlobalLeaderboards
    );
  }

  function supportsAchievements() {
    const capabilities = getCapabilities();

    return Boolean(
      isAndroidPlayGamesAvailable() &&
      capabilities.supportsOfficialAchievements
    );
  }

  async function getAuthenticationStatus() {
    if (!isAndroidPlayGamesAvailable()) {
      return {
        authenticated: false,
        status: "unavailable"
      };
    }

    try {
      return await root.FlagGamePlayGames.getAuthenticationStatus();
    } catch (error) {
      return {
        authenticated: false,
        status: "error",
        error
      };
    }
  }

  function toSafeInteger(value, fallback = 0) {
    const number = Number(value);

    if (!Number.isFinite(number)) {
      return fallback;
    }

    return Math.max(0, Math.floor(number));
  }

  function isValidRun(run) {
    if (!run || typeof run !== "object" || !run.runId) {
      return false;
    }

    const correctCountries = toSafeInteger(run.correctCountries, -1);
    const bestStreak = toSafeInteger(run.bestStreak, -1);
    const elapsedMs = toSafeInteger(run.elapsedMs, -1);

    return (
      correctCountries >= 0 &&
      correctCountries <= 195 &&
      bestStreak >= 0 &&
      elapsedMs >= 0
    );
  }

  function isEligibleForLeaderboards(run) {
    return Boolean(
      isValidRun(run) &&
      run.rankingEligible === true &&
      run.continued !== true
    );
  }

  function scoreTag(runId) {
    return String(runId || "")
      .replace(/[^A-Za-z0-9._~-]/g, "_")
      .slice(0, 64);
  }

  function buildLeaderboardSubmissions(run, stats) {
    const safeStats = stats && typeof stats === "object" ? stats : {};
    const bestCorrectCountries = Math.min(
      195,
      Math.max(
        toSafeInteger(run.correctCountries, 0),
        toSafeInteger(safeStats.bestCorrectCountries, 0)
      )
    );
    const bestStreak = Math.max(
      toSafeInteger(run.bestStreak, 0),
      toSafeInteger(safeStats.bestStreak, 0)
    );
    const submissions = [
      {
        leaderboardKey: LEADERBOARDS.progress,
        score: bestCorrectCountries,
        scoreTag: scoreTag(run.runId)
      },
      {
        leaderboardKey: LEADERBOARDS.streak,
        score: bestStreak,
        scoreTag: scoreTag(run.runId)
      }
    ];

    if (
      run.completed === true &&
      toSafeInteger(run.correctCountries, 0) >= 195 &&
      toSafeInteger(run.elapsedMs, 0) > 0
    ) {
      submissions.push({
        leaderboardKey: LEADERBOARDS.fastest195,
        score: toSafeInteger(run.elapsedMs, 0),
        scoreTag: scoreTag(run.runId)
      });
    }

    return submissions;
  }

  function dedupePendingRuns(items) {
    const seen = new Set();

    return items.filter(item => {
      if (!item || !item.run || !item.run.runId) {
        return false;
      }

      const runId = String(item.run.runId);

      if (seen.has(runId)) {
        return false;
      }

      seen.add(runId);
      return true;
    });
  }

  function enqueueRun(run, stats, reason) {
    const state = readState();

    if (state.submittedRuns[run.runId]) {
      return {
        queued: false,
        reason: "already_submitted"
      };
    }

    const pendingRuns = dedupePendingRuns([
      ...state.pendingRuns.filter(item => item.run.runId !== run.runId),
      {
        run,
        stats: stats || {},
        reason: reason || "submit_failed",
        attempts: 0,
        createdAt: nowIso(),
        updatedAt: nowIso()
      }
    ]);

    writeState({
      pendingRuns,
      status: "pending",
      lastError: reason || "pending"
    });

    scheduleRetry();

    return {
      queued: true,
      reason: reason || "pending"
    };
  }

  async function submitLeaderboardsForRun(run, stats) {
    if (!supportsLeaderboards()) {
      return {
        ok: false,
        status: "unsupported"
      };
    }

    const auth = await getAuthenticationStatus();

    if (!auth || !auth.authenticated) {
      return {
        ok: false,
        status: "not_authenticated"
      };
    }

    const submissions = buildLeaderboardSubmissions(run, stats);

    for (const submission of submissions) {
      const result =
        await root.FlagGamePlayGames.submitLeaderboardScore(submission);

      if (!result || result.error || result.authenticated === false) {
        return {
          ok: false,
          status: result && result.status ? result.status : "submit_failed",
          result
        };
      }
    }

    return {
      ok: true,
      status: "submitted",
      submissions
    };
  }

  async function recordWorldChallengeRun(context) {
    const run = context && context.run;
    const stats = context && context.stats;

    if (!isValidRun(run)) {
      return {
        ok: false,
        status: "invalid_run"
      };
    }

    syncLocalAchievements();

    const state = readState();

    if (state.submittedRuns[run.runId]) {
      return {
        ok: true,
        status: "already_submitted"
      };
    }

    if (!isEligibleForLeaderboards(run)) {
      return {
        ok: false,
        status: "not_eligible"
      };
    }

    const result = await submitLeaderboardsForRun(run, stats);

    if (!result.ok) {
      enqueueRun(run, stats, result.status);
      return result;
    }

    markRunSubmitted(run.runId);

    return result;
  }

  function markRunSubmitted(runId) {
    const state = readState();
    const pendingRuns = state.pendingRuns.filter(
      item => item.run.runId !== runId
    );

    writeState({
      pendingRuns,
      submittedRuns: {
        ...state.submittedRuns,
        [runId]: nowIso()
      },
      status: pendingRuns.length ? "pending" : "submitted",
      lastSubmittedAt: nowIso(),
      lastError: ""
    });
  }

  async function flushQueue() {
    const auth = await getAuthenticationStatus();

    if (!auth || !auth.authenticated) {
      writeState({
        status: "pending",
        lastError: "not_authenticated"
      });
      return {
        ok: false,
        status: "not_authenticated"
      };
    }

    const state = readState();
    let pendingRuns = state.pendingRuns.slice();
    let submitted = 0;

    for (const item of state.pendingRuns) {
      const result = await submitLeaderboardsForRun(
        item.run,
        item.stats
      );

      if (result.ok) {
        submitted++;
        pendingRuns = pendingRuns.filter(
          pending => pending.run.runId !== item.run.runId
        );
        writeState({
          pendingRuns,
          submittedRuns: {
            ...readState().submittedRuns,
            [item.run.runId]: nowIso()
          },
          status: pendingRuns.length ? "pending" : "submitted",
          lastSubmittedAt: nowIso(),
          lastError: ""
        });
      } else {
        pendingRuns = pendingRuns.map(pending =>
          pending.run.runId === item.run.runId
            ? {
              ...pending,
              attempts: toSafeInteger(pending.attempts, 0) + 1,
              updatedAt: nowIso(),
              reason: result.status
            }
            : pending
        );
        writeState({
          pendingRuns,
          status: "pending",
          lastError: result.status
        });
      }
    }

    return {
      ok: pendingRuns.length === 0,
      status: pendingRuns.length ? "pending" : "submitted",
      submitted
    };
  }

  function getEligibleAchievementsFromLocalData() {
    const achievements = new Set();
    const data = root.FlagGameWorldChallengeStorage
      ? root.FlagGameWorldChallengeStorage.readData()
      : null;
    const stats = data && data.stats ? data.stats : {};
    const history = data && Array.isArray(data.history)
      ? data.history
      : [];
    const bestCorrectCountries = toSafeInteger(
      stats.bestCorrectCountries,
      0
    );
    const bestStreak = toSafeInteger(stats.bestStreak, 0);

    if (toSafeInteger(stats.attempts, 0) >= 1) {
      achievements.add(ACHIEVEMENTS.firstAttempt);
    }

    [
      [25, ACHIEVEMENTS.countries25],
      [50, ACHIEVEMENTS.countries50],
      [100, ACHIEVEMENTS.countries100],
      [150, ACHIEVEMENTS.countries150],
      [195, ACHIEVEMENTS.countries195]
    ].forEach(([threshold, key]) => {
      if (bestCorrectCountries >= threshold) {
        achievements.add(key);
      }
    });

    if (bestStreak >= 50) {
      achievements.add(ACHIEVEMENTS.streak50);
    }

    if (bestStreak >= 100) {
      achievements.add(ACHIEVEMENTS.streak100);
    }

    if (
      history.some(run =>
        run.completed === true &&
        toSafeInteger(run.livesRemaining, 0) === 1
      )
    ) {
      achievements.add(ACHIEVEMENTS.completeOneLife);
    }

    if (
      history.some(run =>
        run.completed === true &&
        run.continued !== true &&
        toSafeInteger(run.wrongAnswers, 0) === 0 &&
        toSafeInteger(run.skips, 0) === 0
      )
    ) {
      achievements.add(ACHIEVEMENTS.completeNoLivesLost);
    }

    return Array.from(achievements);
  }

  async function syncLocalAchievements() {
    if (!supportsAchievements()) {
      return {
        ok: false,
        status: "unsupported"
      };
    }

    const auth = await getAuthenticationStatus();

    if (!auth || !auth.authenticated) {
      writeState({
        status: "pending",
        lastError: "not_authenticated"
      });
      return {
        ok: false,
        status: "not_authenticated"
      };
    }

    const state = readState();
    const pendingAchievements = getEligibleAchievementsFromLocalData()
      .filter(key => !state.submittedAchievements[key]);
    const submittedAchievements = {
      ...state.submittedAchievements
    };

    for (const achievementKey of pendingAchievements) {
      const result = await root.FlagGamePlayGames.unlockAchievement({
        achievementKey
      });

      if (result && !result.error && result.authenticated !== false) {
        submittedAchievements[achievementKey] = nowIso();
      } else {
        writeState({
          submittedAchievements,
          status: "pending",
          lastError: result && result.status
            ? result.status
            : "achievement_unlock_failed"
        });
        return {
          ok: false,
          status: "pending"
        };
      }
    }

    writeState({
      submittedAchievements,
      status: readState().pendingRuns.length ? "pending" : "submitted",
      lastError: ""
    });

    return {
      ok: true,
      status: "achievements_synced",
      submitted: pendingAchievements.length
    };
  }

  function scheduleRetry() {
    if (retryTimer || !isAndroidPlayGamesAvailable()) {
      return;
    }

    retryTimer = setTimeout(() => {
      retryTimer = null;
      syncLocalAchievements().finally(() => {
        flushQueue();
      });
    }, RETRY_DEBOUNCE_MS);
  }

  async function openLeaderboards() {
    if (!supportsLeaderboards()) {
      return {
        ok: false,
        status: "unsupported"
      };
    }

    return root.FlagGamePlayGames.openLeaderboards();
  }

  async function openAchievements() {
    if (!supportsAchievements()) {
      return {
        ok: false,
        status: "unsupported"
      };
    }

    return root.FlagGamePlayGames.openAchievements();
  }

  async function refreshStatus() {
    const auth = await getAuthenticationStatus();
    const state = readState();
    const status = auth && auth.authenticated
      ? state.pendingRuns.length
        ? "pending"
        : "authenticated"
      : "not_authenticated";

    writeState({
      status,
      lastError: auth && auth.error && auth.error.code
        ? auth.error.code
        : state.lastError
    });

    return {
      ...state,
      status,
      authenticated: Boolean(auth && auth.authenticated)
    };
  }

  function start() {
    if (root.addEventListener) {
      root.addEventListener("online", () => {
        scheduleRetry();
      });
    }

    if (isAndroidPlayGamesAvailable()) {
      refreshStatus().then(status => {
        if (status.authenticated) {
          syncLocalAchievements().finally(() => {
            flushQueue();
          });
        }
      });
    }
  }

  return {
    ACHIEVEMENTS,
    LEADERBOARDS,
    STORAGE_KEY,
    buildLeaderboardSubmissions,
    flushQueue,
    getEligibleAchievementsFromLocalData,
    isEligibleForLeaderboards,
    onStatusChange,
    openAchievements,
    openLeaderboards,
    readState,
    recordWorldChallengeRun,
    refreshStatus,
    start,
    syncLocalAchievements
  };
});
