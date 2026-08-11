/*
 * Local checkpoint support for Desafio Mundial.
 * This stores only resumable run state. It does not write profile history,
 * submit ranking data, or touch Google Play Games.
 */
(function (global) {
  "use strict";

  const STORAGE_KEY = "flagGameWorldChallengeCheckpoint";
  const SCHEMA_VERSION = 1;
  const MIN_WRITE_INTERVAL_MS = 750;
  const ALLOWED_STATUSES = ["playing", "feedback", "game_over"];

  let lastWriteSignature = "";
  let lastWriteAt = 0;

  function nowMs() {
    return Date.now();
  }

  function getStorage(options) {
    return options && options.storage
      ? options.storage
      : global.FlagGameStorage;
  }

  function toSafeInteger(value, fallback) {
    const number = Number(value);

    if (!Number.isFinite(number)) {
      return fallback;
    }

    return Math.max(0, Math.floor(number));
  }

  function toSafeTimestamp(value, fallback) {
    const number = Number(value);

    if (!Number.isFinite(number) || number < 0) {
      return fallback;
    }

    return Math.floor(number);
  }

  function cloneJson(value, fallback) {
    try {
      return JSON.parse(JSON.stringify(value));
    } catch (error) {
      return fallback;
    }
  }

  function uniqueIds(values) {
    const seen = new Set();
    const result = [];

    (Array.isArray(values) ? values : []).forEach(value => {
      const id = String(value || "").trim().toUpperCase();

      if (id && !seen.has(id)) {
        seen.add(id);
        result.push(id);
      }
    });

    return result;
  }

  function serializeQuestion(question) {
    if (!question || typeof question !== "object") {
      return null;
    }

    return {
      questionId: String(question.questionId || ""),
      sequenceNumber: toSafeInteger(question.sequenceNumber, 0),
      countryId: String(question.countryId || "").trim().toUpperCase(),
      correctId: String(question.correctId || "").trim().toUpperCase(),
      code: String(question.code || ""),
      flagFile: String(question.flagFile || ""),
      options: (Array.isArray(question.options) ? question.options : [])
        .map(option => ({
          id: String(option.id || "").trim().toUpperCase(),
          code: String(option.code || ""),
          name: String(option.name || ""),
          flagFile: String(option.flagFile || ""),
          continent: String(option.continent || ""),
          region: String(option.region || ""),
          visualGroup: String(option.visualGroup || "")
        }))
        .filter(option => option.id),
      answered: question.answered === true,
      selectedId: String(question.selectedId || "").trim().toUpperCase()
    };
  }

  function serializeFeedback(feedback) {
    if (!feedback || typeof feedback !== "object") {
      return null;
    }

    return {
      type: String(feedback.type || ""),
      correctId: String(feedback.correctId || "").trim().toUpperCase(),
      selectedId: String(feedback.selectedId || "").trim().toUpperCase(),
      lifeLost: feedback.lifeLost === true
    };
  }

  function createCheckpoint(state, options) {
    const params = options || {};
    const timestamp = params.now || nowMs();

    if (
      !state ||
      state.mode !== "world_challenge" ||
      !ALLOWED_STATUSES.includes(state.status)
    ) {
      return null;
    }

    const startedAt = toSafeTimestamp(state.startedAt, timestamp);
    const elapsedSeconds = Math.max(
      toSafeInteger(state.elapsedSeconds, 0),
      Math.floor(Math.max(0, timestamp - startedAt) / 1000)
    );

    return {
      schemaVersion: SCHEMA_VERSION,
      mode: "world_challenge",
      runId: String(params.runId || state.eventId || ""),
      eventId: String(state.eventId || ""),
      seed: String(state.seed || params.runId || ""),
      status: state.status,
      queue: uniqueIds(state.queue),
      retryQueue: (Array.isArray(state.retryQueue) ? state.retryQueue : [])
        .map(item => ({
          id: String(item.id || "").trim().toUpperCase(),
          lastAskedSequence: toSafeInteger(item.lastAskedSequence, 0)
        }))
        .filter(item => item.id),
      answeredCorrect: uniqueIds(state.answeredCorrect),
      currentQuestion: serializeQuestion(state.currentQuestion),
      feedback: serializeFeedback(state.feedback),
      initialLives: toSafeInteger(state.initialLives, 5),
      lives: toSafeInteger(state.lives, 0),
      repeatDistance: toSafeInteger(state.repeatDistance, 10),
      correctCount: toSafeInteger(state.correctCount, 0),
      mistakes: toSafeInteger(state.mistakes, 0),
      skips: toSafeInteger(state.skips, 0),
      currentStreak: toSafeInteger(state.currentStreak, 0),
      bestStreak: toSafeInteger(state.bestStreak, 0),
      questionsServed: toSafeInteger(state.questionsServed, 0),
      currentQuestionSource: String(state.currentQuestionSource || ""),
      continued: state.continued === true,
      rankingEligible: state.rankingEligible !== false,
      startedAt,
      endedAt: state.endedAt === null || state.endedAt === undefined
        ? null
        : toSafeTimestamp(state.endedAt, timestamp),
      lastUpdatedAt: toSafeTimestamp(state.lastUpdatedAt, timestamp),
      elapsedSeconds,
      checkpointedAt: timestamp
    };
  }

  function checkpointSignature(checkpoint) {
    const questionId = checkpoint.currentQuestion
      ? checkpoint.currentQuestion.questionId
      : "";

    return [
      checkpoint.runId,
      checkpoint.status,
      questionId,
      checkpoint.lives,
      checkpoint.correctCount,
      checkpoint.mistakes,
      checkpoint.skips,
      checkpoint.currentStreak,
      checkpoint.retryQueue.length,
      checkpoint.lastUpdatedAt
    ].join("|");
  }

  function writeCheckpoint(state, options) {
    const params = options || {};
    const storage = getStorage(params);
    const checkpoint = createCheckpoint(state, params);

    if (!checkpoint || !storage || typeof storage.setJson !== "function") {
      return {
        ok: false,
        reason: checkpoint ? "storage_unavailable" : "not_checkpointable"
      };
    }

    const signature = checkpointSignature(checkpoint);

    if (
      params.force !== true &&
      signature === lastWriteSignature &&
      checkpoint.checkpointedAt - lastWriteAt < MIN_WRITE_INTERVAL_MS
    ) {
      return {
        ok: true,
        skipped: true,
        reason: "duplicate_checkpoint",
        checkpoint
      };
    }

    const written = storage.setJson(STORAGE_KEY, checkpoint) !== false;

    if (written) {
      lastWriteSignature = signature;
      lastWriteAt = checkpoint.checkpointedAt;
    }

    return {
      ok: written,
      reason: written ? "checkpoint_saved" : "write_failed",
      checkpoint
    };
  }

  function readCheckpoint(options) {
    const storage = getStorage(options || {});

    if (!storage || typeof storage.getJson !== "function") {
      return null;
    }

    const checkpoint = storage.getJson(STORAGE_KEY, null);

    if (
      !checkpoint ||
      checkpoint.schemaVersion !== SCHEMA_VERSION ||
      checkpoint.mode !== "world_challenge"
    ) {
      return null;
    }

    return checkpoint;
  }

  function clearCheckpoint(options) {
    const storage = getStorage(options || {});

    lastWriteSignature = "";
    lastWriteAt = 0;

    if (!storage || typeof storage.remove !== "function") {
      return false;
    }

    return storage.remove(STORAGE_KEY) !== false;
  }

  function filterKnownIds(ids, countryIndex) {
    return uniqueIds(ids).filter(id => countryIndex[id]);
  }

  function restoreQuestion(question, state, getCountryName) {
    const serialized = serializeQuestion(question);

    if (!serialized || !state.countryIndex[serialized.correctId]) {
      return state.currentQuestion;
    }

    return {
      ...serialized,
      options: serialized.options
        .filter(option => state.countryIndex[option.id])
        .map(option => {
          const country = state.countryIndex[option.id];

          return {
            ...option,
            code: country.code,
            name: getCountryName
              ? getCountryName(country.code, country)
              : option.name,
            flagFile: country.flagFile,
            continent: country.continent,
            region: country.region,
            visualGroup: country.visualGroup
          };
        })
    };
  }

  function restoreGame(checkpoint, options) {
    const params = options || {};
    const worldChallenge =
      params.worldChallenge || global.FlagGameWorldChallenge;
    const timestamp = params.now || nowMs();

    if (
      !checkpoint ||
      checkpoint.schemaVersion !== SCHEMA_VERSION ||
      checkpoint.mode !== "world_challenge" ||
      !worldChallenge ||
      typeof worldChallenge.createGame !== "function"
    ) {
      return {
        ok: false,
        reason: "invalid_checkpoint"
      };
    }

    const startedAt = toSafeTimestamp(checkpoint.startedAt, timestamp);
    const baseState = worldChallenge.createGame({
      countries: params.countries,
      seed: checkpoint.seed || checkpoint.runId,
      eventId: checkpoint.eventId,
      now: () => startedAt,
      getCountryName: params.getCountryName,
      initialLives: checkpoint.initialLives,
      repeatDistance: checkpoint.repeatDistance
    });

    const answeredCorrect = filterKnownIds(
      checkpoint.answeredCorrect,
      baseState.countryIndex
    );
    const queue = filterKnownIds(checkpoint.queue, baseState.countryIndex);
    const retryQueue = (Array.isArray(checkpoint.retryQueue)
      ? checkpoint.retryQueue
      : [])
      .map(item => ({
        id: String(item.id || "").trim().toUpperCase(),
        lastAskedSequence: toSafeInteger(item.lastAskedSequence, 0)
      }))
      .filter(item => item.id && baseState.countryIndex[item.id]);
    const currentQuestion = restoreQuestion(
      checkpoint.currentQuestion,
      baseState,
      params.getCountryName
    );
    let status = ALLOWED_STATUSES.includes(checkpoint.status)
      ? checkpoint.status
      : "playing";

    if (currentQuestion && currentQuestion.answered && status === "playing") {
      status = "feedback";
    }

    const elapsedSeconds = Math.max(
      toSafeInteger(checkpoint.elapsedSeconds, 0),
      Math.floor(Math.max(0, timestamp - startedAt) / 1000)
    );

    const state = {
      ...baseState,
      status,
      eventId: String(checkpoint.eventId || baseState.eventId),
      seed: String(checkpoint.seed || baseState.seed),
      lives: Math.min(
        toSafeInteger(checkpoint.initialLives, baseState.initialLives),
        toSafeInteger(checkpoint.lives, baseState.lives)
      ),
      queue,
      retryQueue,
      answeredCorrect,
      continued: checkpoint.continued === true,
      rankingEligible: false,
      correctCount: Math.min(
        baseState.countriesTotal,
        Math.max(
          answeredCorrect.length,
          toSafeInteger(checkpoint.correctCount, answeredCorrect.length)
        )
      ),
      mistakes: toSafeInteger(checkpoint.mistakes, 0),
      skips: toSafeInteger(checkpoint.skips, 0),
      currentStreak: toSafeInteger(checkpoint.currentStreak, 0),
      bestStreak: toSafeInteger(checkpoint.bestStreak, 0),
      questionsServed: toSafeInteger(checkpoint.questionsServed, 1),
      currentQuestion,
      currentQuestionSource: String(checkpoint.currentQuestionSource || ""),
      feedback: serializeFeedback(checkpoint.feedback),
      startedAt,
      endedAt: checkpoint.endedAt === null || checkpoint.endedAt === undefined
        ? null
        : toSafeTimestamp(checkpoint.endedAt, timestamp),
      lastUpdatedAt: toSafeTimestamp(checkpoint.lastUpdatedAt, timestamp),
      elapsedSeconds,
      restoredFromCheckpoint: true
    };

    return {
      ok: true,
      runId: String(checkpoint.runId || checkpoint.eventId || state.eventId),
      state
    };
  }

  function bindPageLifecycle(options) {
    const params = options || {};
    const doc = params.document || global.document;
    const win = params.window || global;
    const onCheckpoint = params.onCheckpoint;

    if (typeof onCheckpoint !== "function") {
      return {
        dispose() {}
      };
    }

    function checkpoint(reason) {
      onCheckpoint(reason);
    }

    function handleVisibilityChange() {
      if (!doc || doc.visibilityState === "hidden") {
        checkpoint("visibilitychange");
      }
    }

    function handlePageHide() {
      checkpoint("pagehide");
    }

    if (doc && typeof doc.addEventListener === "function") {
      doc.addEventListener("visibilitychange", handleVisibilityChange);
    }

    if (win && typeof win.addEventListener === "function") {
      win.addEventListener("pagehide", handlePageHide);
    }

    return {
      dispose() {
        if (doc && typeof doc.removeEventListener === "function") {
          doc.removeEventListener("visibilitychange", handleVisibilityChange);
        }

        if (win && typeof win.removeEventListener === "function") {
          win.removeEventListener("pagehide", handlePageHide);
        }
      }
    };
  }

  const api = {
    SCHEMA_VERSION,
    STORAGE_KEY,
    bindPageLifecycle,
    clearCheckpoint,
    createCheckpoint,
    readCheckpoint,
    restoreGame,
    writeCheckpoint
  };

  global.FlagGameWorldChallengeCheckpoint = api;

  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : window);
