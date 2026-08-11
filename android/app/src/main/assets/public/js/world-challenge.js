/*
 * Pure logic engine for Desafio Mundial - Modo Experiente.
 * This file intentionally does not touch DOM, storage, ranking, or
 * Google Play Games. The legacy expert mode remains identified as "expert".
 */
(function (global) {
  "use strict";

  const MODE_WORLD_CHALLENGE = "world_challenge";
  const MODE_EXPERT_LEGACY = "expert";
  const INITIAL_LIVES = 5;
  const REQUIRED_COUNTRY_COUNT = 195;
  const OPTION_COUNT = 4;
  const REPEAT_DISTANCE = 10;
  const SCHEMA_VERSION = 1;

  function nowMs() {
    return Date.now();
  }

  function hashString(value) {
    let hash = 2166136261;

    for (let index = 0; index < value.length; index += 1) {
      hash ^= value.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }

    return hash >>> 0;
  }

  function createRandom(seed) {
    let state = hashString(String(seed || "world_challenge"));

    return function random() {
      state += 0x6D2B79F5;

      let value = state;
      value = Math.imul(value ^ (value >>> 15), value | 1);
      value ^= value + Math.imul(value ^ (value >>> 7), value | 61);

      return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
    };
  }

  function shuffle(list, random) {
    const copy = list.slice();

    for (let index = copy.length - 1; index > 0; index -= 1) {
      const swapIndex = Math.floor(random() * (index + 1));
      const value = copy[index];
      copy[index] = copy[swapIndex];
      copy[swapIndex] = value;
    }

    return copy;
  }

  function normalizeText(value) {
    return String(value || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/['']/g, "")
      .replace(/[-]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function normalizeId(value) {
    return String(value || "").trim().toUpperCase();
  }

  function getCountryId(country) {
    return normalizeId(country.id || country.code);
  }

  function getVisualGroup(country) {
    return String(
      country.visualGroup ||
      country.flagGroup ||
      country.similarGroup ||
      country.group ||
      ""
    );
  }

  function getRegion(country) {
    return String(country.region || country.subregion || "");
  }

  function normalizeCountry(country) {
    const id = getCountryId(country);

    if (!id) {
      throw new Error("World Challenge country is missing a stable id/code.");
    }

    return {
      ...country,
      id,
      code: normalizeId(country.code || id),
      name: String(country.name || id),
      continent: String(country.continent || ""),
      region: getRegion(country),
      visualGroup: getVisualGroup(country),
      flagFile: String(country.flagFile || "")
    };
  }

  function normalizeCountries(countries, requiredCountryCount) {
    if (!Array.isArray(countries)) {
      throw new Error("World Challenge requires a countries array.");
    }

    const normalized = countries.map(normalizeCountry);
    const ids = new Set(normalized.map(country => country.id));

    if (ids.size !== normalized.length) {
      throw new Error("World Challenge requires distinct country ids.");
    }

    if (normalized.length !== requiredCountryCount) {
      throw new Error(
        `World Challenge requires ${requiredCountryCount} distinct countries.`
      );
    }

    return normalized;
  }

  function defaultGetCountryName(code, country) {
    return country && (country.name || country.code || country.id)
      ? (country.name || country.code || country.id)
      : code;
  }

  function getDisplayName(country, getCountryName) {
    return String(
      getCountryName
        ? getCountryName(country.code, country)
        : defaultGetCountryName(country)
    );
  }

  function createCountryIndex(countries) {
    return countries.reduce((index, country) => {
      index[country.id] = country;
      return index;
    }, {});
  }

  function makeOption(country, getCountryName) {
    return {
      id: country.id,
      code: country.code,
      name: getDisplayName(country, getCountryName),
      flagFile: country.flagFile,
      continent: country.continent,
      region: country.region,
      visualGroup: country.visualGroup
    };
  }

  function addCandidate(result, candidate, correctCountry, seenIds, seenNames, getCountryName) {
    if (!candidate || candidate.id === correctCountry.id || seenIds.has(candidate.id)) {
      return;
    }

    const optionName = getDisplayName(candidate, getCountryName);
    const normalizedName = normalizeText(optionName);

    if (!normalizedName || seenNames.has(normalizedName)) {
      return;
    }

    seenIds.add(candidate.id);
    seenNames.add(normalizedName);
    result.push(candidate);
  }

  function buildDistractorPool(countries, correctCountry, random) {
    const correctGroup = getVisualGroup(correctCountry);
    const correctRegion = getRegion(correctCountry);

    const sameVisualGroup = correctGroup
      ? countries.filter(country =>
        country.id !== correctCountry.id &&
        getVisualGroup(country) === correctGroup
      )
      : [];

    const sameRegion = correctRegion
      ? countries.filter(country =>
        country.id !== correctCountry.id &&
        getRegion(country) === correctRegion
      )
      : [];

    const sameContinent = correctCountry.continent
      ? countries.filter(country =>
        country.id !== correctCountry.id &&
        country.continent === correctCountry.continent
      )
      : [];

    const globalPool = countries.filter(country => country.id !== correctCountry.id);

    return [
      shuffle(sameVisualGroup, random),
      shuffle(sameRegion, random),
      shuffle(sameContinent, random),
      shuffle(globalPool, random)
    ];
  }

  function buildOptions(params) {
    const countries = params.countries;
    const correctCountry = params.correctCountry;
    const getCountryName = params.getCountryName || defaultGetCountryName;
    const random = params.random || Math.random;
    const seenIds = new Set([correctCountry.id]);
    const seenNames = new Set([
      normalizeText(getDisplayName(correctCountry, getCountryName))
    ]);
    const distractors = [];

    buildDistractorPool(countries, correctCountry, random).forEach(pool => {
      pool.forEach(candidate => {
        if (distractors.length < OPTION_COUNT - 1) {
          addCandidate(
            distractors,
            candidate,
            correctCountry,
            seenIds,
            seenNames,
            getCountryName
          );
        }
      });
    });

    if (distractors.length !== OPTION_COUNT - 1) {
      throw new Error("World Challenge could not build four unique options.");
    }

    const options = [
      makeOption(correctCountry, getCountryName),
      ...distractors.map(country => makeOption(country, getCountryName))
    ];

    return shuffle(options, random);
  }

  function createQuestion(state, countryId, random, getCountryName) {
    const country = state.countryIndex[countryId];

    if (!country) {
      throw new Error(`World Challenge missing country ${countryId}.`);
    }

    const nextSequenceNumber = state.questionsServed + 1;

    return {
      questionId: `${state.eventId}:${nextSequenceNumber}:${country.id}`,
      sequenceNumber: nextSequenceNumber,
      countryId: country.id,
      correctId: country.id,
      code: country.code,
      flagFile: country.flagFile,
      options: buildOptions({
        countries: state.countries,
        correctCountry: country,
        random,
        getCountryName
      }),
      answered: false
    };
  }

  function getReadyRetryIndex(state, nextSequenceNumber) {
    return state.retryQueue.findIndex(item =>
      nextSequenceNumber > item.lastAskedSequence + state.repeatDistance
    );
  }

  function drawCountryId(state) {
    const nextSequenceNumber = state.questionsServed + 1;
    const readyRetryIndex = getReadyRetryIndex(state, nextSequenceNumber);
    const retryQueue = state.retryQueue.slice();
    let queue = state.queue.slice();
    let source = "queue";
    let countryId = "";

    if (readyRetryIndex >= 0) {
      countryId = retryQueue.splice(readyRetryIndex, 1)[0].id;
      source = "retry";
    } else if (queue.length > 0) {
      countryId = queue.shift();
    } else if (retryQueue.length > 0) {
      countryId = retryQueue.shift().id;
      source = "retry_forced";
    }

    return {
      countryId,
      queue,
      retryQueue,
      source
    };
  }

  function isTerminal(state) {
    return state.status === "finished" || state.status === "game_over";
  }

  function elapsedSeconds(state, timestamp) {
    const end = timestamp || state.endedAt || state.lastUpdatedAt || state.startedAt;
    return Math.max(0, Math.floor((end - state.startedAt) / 1000));
  }

  function finishState(state, status, timestamp) {
    return {
      ...state,
      status,
      endedAt: timestamp,
      lastUpdatedAt: timestamp,
      elapsedSeconds: elapsedSeconds(state, timestamp),
      currentQuestion: state.currentQuestion
        ? { ...state.currentQuestion, answered: true }
        : null
    };
  }

  function prepareNextQuestion(state, options) {
    const random = options.random || createRandom(`${state.seed}:q:${state.questionsServed + 1}`);
    const getCountryName = options.getCountryName || defaultGetCountryName;
    const draw = drawCountryId(state);

    if (!draw.countryId) {
      if (state.correctCount >= state.countriesTotal) {
        return finishState(state, "finished", options.now());
      }

      return finishState(state, "game_over", options.now());
    }

    const nextState = {
      ...state,
      queue: draw.queue,
      retryQueue: draw.retryQueue,
      currentQuestion: null,
      currentQuestionSource: draw.source
    };
    const question = createQuestion(nextState, draw.countryId, random, getCountryName);

    return {
      ...nextState,
      status: "playing",
      questionsServed: question.sequenceNumber,
      currentQuestion: question,
      feedback: null,
      lastUpdatedAt: options.now()
    };
  }

  function createGame(params) {
    const options = params || {};
    const requiredCountryCount =
      options.requiredCountryCount || REQUIRED_COUNTRY_COUNT;
    const countries = normalizeCountries(
      options.countries || global.countries,
      requiredCountryCount
    );
    const seed = String(options.seed || `wc_${nowMs().toString(36)}`);
    const timestamp = options.now ? options.now() : nowMs();
    const initialRandom = options.random || createRandom(`${seed}:initial`);
    const queue = shuffle(countries.map(country => country.id), initialRandom);
    const baseState = {
      schemaVersion: SCHEMA_VERSION,
      mode: MODE_WORLD_CHALLENGE,
      legacyMode: MODE_EXPERT_LEGACY,
      status: "idle",
      eventId: options.eventId || `wc_${seed}`,
      seed,
      countries,
      countryIndex: createCountryIndex(countries),
      countriesTotal: countries.length,
      initialLives: options.initialLives || INITIAL_LIVES,
      lives: options.initialLives || INITIAL_LIVES,
      repeatDistance: options.repeatDistance === 0
        ? 0
        : (options.repeatDistance || REPEAT_DISTANCE),
      queue,
      retryQueue: [],
      answeredCorrect: [],
      continued: false,
      rankingEligible: true,
      correctCount: 0,
      mistakes: 0,
      skips: 0,
      currentStreak: 0,
      bestStreak: 0,
      questionsServed: 0,
      currentQuestion: null,
      currentQuestionSource: "",
      feedback: null,
      startedAt: timestamp,
      endedAt: null,
      lastUpdatedAt: timestamp,
      elapsedSeconds: 0
    };

    return prepareNextQuestion(baseState, {
      now: () => timestamp,
      random: options.random || createRandom(`${seed}:question:1`),
      getCountryName: options.getCountryName
    });
  }

  function ensurePlaying(state, questionId) {
    if (!state || state.status !== "playing" || !state.currentQuestion) {
      return "not_playing";
    }

    if (
      questionId &&
      state.currentQuestion.questionId &&
      questionId !== state.currentQuestion.questionId
    ) {
      return "stale_question";
    }

    if (state.currentQuestion.answered) {
      return "already_answered";
    }

    return "";
  }

  function enqueueRetry(state, countryId) {
    if (state.answeredCorrect.includes(countryId)) {
      return state.retryQueue.slice();
    }

    const retryQueue = state.retryQueue
      .filter(item => item.id !== countryId)
      .concat({
        id: countryId,
        lastAskedSequence: state.currentQuestion.sequenceNumber
      });

    return retryQueue;
  }

  function answer(state, selectedId, params) {
    const options = params || {};
    const timestamp = options.now ? options.now() : nowMs();
    const lockReason = ensurePlaying(state, options.questionId);

    if (lockReason) {
      return {
        state,
        result: {
          accepted: false,
          reason: lockReason
        }
      };
    }

    const selectedCountryId = normalizeId(selectedId);
    const correctId = state.currentQuestion.correctId;
    const isCorrect = selectedCountryId === correctId;
    let nextState;

    if (isCorrect) {
      const alreadyCorrect = state.answeredCorrect.includes(correctId);
      const answeredCorrect = alreadyCorrect
        ? state.answeredCorrect.slice()
        : state.answeredCorrect.concat(correctId);
      const currentStreak = alreadyCorrect
        ? state.currentStreak
        : state.currentStreak + 1;
      const bestStreak = Math.max(state.bestStreak, currentStreak);

      nextState = {
        ...state,
        answeredCorrect,
        correctCount: answeredCorrect.length,
        currentStreak,
        bestStreak,
        currentQuestion: {
          ...state.currentQuestion,
          answered: true,
          selectedId: selectedCountryId
        },
        feedback: {
          type: "correct",
          correctId,
          selectedId: selectedCountryId,
          lifeLost: false
        },
        lastUpdatedAt: timestamp,
        elapsedSeconds: elapsedSeconds(state, timestamp)
      };

      if (answeredCorrect.length >= state.countriesTotal) {
        nextState = finishState(nextState, "finished", timestamp);
      } else {
        nextState.status = "feedback";
      }
    } else {
      const lives = Math.max(0, state.lives - 1);
      const retryQueue = enqueueRetry(state, correctId);

      nextState = {
        ...state,
        lives,
        retryQueue,
        mistakes: state.mistakes + 1,
        currentStreak: 0,
        currentQuestion: {
          ...state.currentQuestion,
          answered: true,
          selectedId: selectedCountryId
        },
        feedback: {
          type: "incorrect",
          correctId,
          selectedId: selectedCountryId,
          lifeLost: true
        },
        lastUpdatedAt: timestamp,
        elapsedSeconds: elapsedSeconds(state, timestamp)
      };

      nextState = lives === 0
        ? finishState(nextState, "game_over", timestamp)
        : { ...nextState, status: "feedback" };
    }

    return {
      state: nextState,
      result: {
        accepted: true,
        correct: isCorrect,
        selectedId: selectedCountryId,
        correctId,
        status: nextState.status
      }
    };
  }

  function skip(state, params) {
    const options = params || {};
    const timestamp = options.now ? options.now() : nowMs();
    const lockReason = ensurePlaying(state, options.questionId);

    if (lockReason) {
      return {
        state,
        result: {
          accepted: false,
          reason: lockReason
        }
      };
    }

    const correctId = state.currentQuestion.correctId;
    const lives = Math.max(0, state.lives - 1);
    const retryQueue = enqueueRetry(state, correctId);
    let nextState = {
      ...state,
      lives,
      retryQueue,
      skips: state.skips + 1,
      currentStreak: 0,
      currentQuestion: {
        ...state.currentQuestion,
        answered: true,
        selectedId: ""
      },
      feedback: {
        type: "skip",
        correctId,
        selectedId: "",
        lifeLost: true
      },
      lastUpdatedAt: timestamp,
      elapsedSeconds: elapsedSeconds(state, timestamp)
    };

    nextState = lives === 0
      ? finishState(nextState, "game_over", timestamp)
      : { ...nextState, status: "feedback" };

    return {
      state: nextState,
      result: {
        accepted: true,
        correct: false,
        skipped: true,
        correctId,
        status: nextState.status
      }
    };
  }

  function advance(state, params) {
    const options = params || {};

    if (!state || isTerminal(state)) {
      return state;
    }

    if (state.status !== "feedback") {
      return state;
    }

    return prepareNextQuestion(state, {
      now: options.now || nowMs,
      random: options.random || createRandom(`${state.seed}:question:${state.questionsServed + 1}`),
      getCountryName: options.getCountryName
    });
  }

  function continueGame(state, params) {
    const options = params || {};
    const timestamp = options.now ? options.now() : nowMs();

    if (!state || state.status !== "game_over") {
      return {
        state,
        result: {
          accepted: false,
          reason: "not_game_over"
        }
      };
    }

    if (state.continued) {
      return {
        state,
        result: {
          accepted: false,
          reason: "already_continued"
        }
      };
    }

    return {
      state: {
        ...state,
        lives: 1,
        continued: true,
        rankingEligible: false,
        status: "feedback",
        endedAt: null,
        lastUpdatedAt: timestamp,
        elapsedSeconds: elapsedSeconds(state, timestamp)
      },
      result: {
        accepted: true,
        lives: 1,
        continued: true,
        rankingEligible: false,
        status: "feedback"
      }
    };
  }

  function getSummary(state, timestamp) {
    return {
      mode: state.mode,
      status: state.status,
      eventId: state.eventId,
      countriesTotal: state.countriesTotal,
      correctCount: state.correctCount,
      progress: state.correctCount,
      pendingCount: state.countriesTotal - state.correctCount,
      lives: state.lives,
      initialLives: state.initialLives,
      mistakes: state.mistakes,
      skips: state.skips,
      currentStreak: state.currentStreak,
      bestStreak: state.bestStreak,
      questionsServed: state.questionsServed,
      retryPending: state.retryQueue.length,
      elapsedSeconds: elapsedSeconds(state, timestamp),
      completed: state.status === "finished",
      gameOver: state.status === "game_over",
      continued: state.continued === true,
      rankingEligible: state.rankingEligible !== false
    };
  }

  const api = {
    MODE_WORLD_CHALLENGE,
    MODE_EXPERT_LEGACY,
    INITIAL_LIVES,
    REQUIRED_COUNTRY_COUNT,
    OPTION_COUNT,
    REPEAT_DISTANCE,
    advance,
    answer,
    buildOptions,
    continueGame,
    createGame,
    createRandom,
    getSummary,
    normalizeText,
    skip
  };

  global.FlagGameWorldChallenge = api;

  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }
})(typeof globalThis !== "undefined" ? globalThis : window);
