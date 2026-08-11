const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const WorldChallenge = require("../js/world-challenge.js");
const Checkpoint = require("../js/world-challenge-checkpoint.js");

function loadCountries() {
  const context = {};
  const source = fs.readFileSync(
    path.join(__dirname, "..", "js", "countries.js"),
    "utf8"
  );

  vm.runInNewContext(`${source}; this.countries = countries;`, context);

  return context.countries;
}

function createMemoryStorage(initial = {}) {
  const store = { ...initial };
  let writes = 0;

  return {
    store,
    get writes() {
      return writes;
    },
    getJson(key, fallback) {
      if (!Object.prototype.hasOwnProperty.call(store, key)) {
        return fallback;
      }

      return JSON.parse(store[key]);
    },
    setJson(key, value) {
      writes += 1;
      store[key] = JSON.stringify(value);
      return true;
    },
    remove(key) {
      delete store[key];
      return true;
    }
  };
}

function createLifecycleTarget() {
  const handlers = {};

  return {
    handlers,
    visibilityState: "visible",
    addEventListener(type, handler) {
      handlers[type] = handler;
    },
    removeEventListener(type) {
      delete handlers[type];
    },
    dispatch(type) {
      handlers[type]();
    }
  };
}

function getCountryName(code, country) {
  return `${country.name} (${code})`;
}

function createGame(seed = "checkpoint-run") {
  return WorldChallenge.createGame({
    countries: loadCountries(),
    seed,
    now: () => 1_000,
    getCountryName
  });
}

function answerWrong(state) {
  const wrongOption = state.currentQuestion.options
    .find(option => option.id !== state.currentQuestion.correctId);

  return WorldChallenge.answer(state, wrongOption.id, {
    questionId: state.currentQuestion.questionId,
    now: () => 5_000
  }).state;
}

function testVisibilityChangeCreatesCheckpoint() {
  const storage = createMemoryStorage();
  const doc = createLifecycleTarget();
  const win = createLifecycleTarget();
  const state = createGame("visibility-run");

  Checkpoint.bindPageLifecycle({
    document: doc,
    window: win,
    onCheckpoint(reason) {
      Checkpoint.writeCheckpoint(state, {
        storage,
        runId: "run-visible",
        reason,
        now: 2_000,
        force: true
      });
    }
  });

  doc.visibilityState = "hidden";
  doc.dispatch("visibilitychange");

  const checkpoint = storage.getJson(
    Checkpoint.STORAGE_KEY,
    null
  );

  assert.equal(checkpoint.runId, "run-visible");
  assert.equal(checkpoint.mode, "world_challenge");
  assert.equal(checkpoint.currentQuestion.questionId, state.currentQuestion.questionId);
}

function testPageHideCreatesCheckpoint() {
  const storage = createMemoryStorage();
  const doc = createLifecycleTarget();
  const win = createLifecycleTarget();
  const state = createGame("pagehide-run");

  Checkpoint.bindPageLifecycle({
    document: doc,
    window: win,
    onCheckpoint(reason) {
      Checkpoint.writeCheckpoint(state, {
        storage,
        runId: "run-pagehide",
        reason,
        now: 2_500,
        force: true
      });
    }
  });

  win.dispatch("pagehide");

  assert.equal(
    storage.getJson(Checkpoint.STORAGE_KEY, null).runId,
    "run-pagehide"
  );
}

function testConsecutiveEventsAreDeduped() {
  const storage = createMemoryStorage();
  const state = createGame("dedupe-run");

  const first = Checkpoint.writeCheckpoint(state, {
    storage,
    runId: "run-dedupe",
    now: 3_000
  });
  const second = Checkpoint.writeCheckpoint(state, {
    storage,
    runId: "run-dedupe",
    now: 3_100
  });

  assert.equal(first.ok, true);
  assert.equal(second.skipped, true);
  assert.equal(storage.writes, 1);
}

function testRestoreKeepsRunStateAndInvalidatesRanking() {
  const storage = createMemoryStorage();
  let state = createGame("restore-run");
  state = answerWrong(state);
  const retryId = state.retryQueue[0].id;

  Checkpoint.writeCheckpoint(state, {
    storage,
    runId: "run-restore",
    now: 12_000,
    force: true
  });

  const restored = Checkpoint.restoreGame(
    Checkpoint.readCheckpoint({ storage }),
    {
      countries: loadCountries(),
      getCountryName,
      worldChallenge: WorldChallenge,
      now: 20_000
    }
  );

  assert.equal(restored.ok, true);
  assert.equal(restored.runId, "run-restore");
  assert.equal(restored.state.lives, 4);
  assert.equal(restored.state.mistakes, 1);
  assert.equal(restored.state.retryQueue[0].id, retryId);
  assert.equal(restored.state.rankingEligible, false);
  assert.equal(restored.state.currentQuestion.answered, true);

  const duplicate = WorldChallenge.answer(
    restored.state,
    restored.state.currentQuestion.correctId,
    {
      questionId: restored.state.currentQuestion.questionId,
      now: () => 21_000
    }
  );

  assert.equal(duplicate.result.accepted, false);
  assert.equal(duplicate.result.reason, "not_playing");
}

function testElapsedTimeIncludesBackgroundPeriod() {
  const storage = createMemoryStorage();
  const state = createGame("timer-run");

  Checkpoint.writeCheckpoint(state, {
    storage,
    runId: "run-timer",
    now: 11_000,
    force: true
  });

  const restored = Checkpoint.restoreGame(
    Checkpoint.readCheckpoint({ storage }),
    {
      countries: loadCountries(),
      getCountryName,
      worldChallenge: WorldChallenge,
      now: 31_000
    }
  );

  assert.equal(restored.state.elapsedSeconds, 30);
}

function testCheckpointDoesNotWriteProfileHistory() {
  const storage = createMemoryStorage();
  const state = createGame("no-side-effects");

  Checkpoint.writeCheckpoint(state, {
    storage,
    runId: "run-side-effects",
    now: 2_000,
    force: true
  });

  assert.deepEqual(Object.keys(storage.store), [
    Checkpoint.STORAGE_KEY
  ]);
}

function testClearCheckpointOnAbandon() {
  const storage = createMemoryStorage();
  const state = createGame("abandon-run");

  Checkpoint.writeCheckpoint(state, {
    storage,
    runId: "run-abandon",
    now: 2_000,
    force: true
  });

  assert.equal(Boolean(Checkpoint.readCheckpoint({ storage })), true);
  assert.equal(Checkpoint.clearCheckpoint({ storage }), true);
  assert.equal(Checkpoint.readCheckpoint({ storage }), null);
}

const tests = [
  testVisibilityChangeCreatesCheckpoint,
  testPageHideCreatesCheckpoint,
  testConsecutiveEventsAreDeduped,
  testRestoreKeepsRunStateAndInvalidatesRanking,
  testElapsedTimeIncludesBackgroundPeriod,
  testCheckpointDoesNotWriteProfileHistory,
  testClearCheckpointOnAbandon
];

for (const test of tests) {
  test();
}

console.log(`${tests.length} world challenge checkpoint tests passed`);
