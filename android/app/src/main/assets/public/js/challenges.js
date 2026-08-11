const FlagGameChallenge = (() => {
  const STORAGE_KEY = "flagGameChallenges";
  const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const CONTINENT_CODES = {
    "south-america": "SA",
    "north-america": "NA",
    europe: "EU",
    africa: "AF",
    asia: "AS",
    oceania: "OC"
  };
  const CODE_CONTINENTS = Object.entries(CONTINENT_CODES)
    .reduce((map, entry) => {
      map[entry[1]] = entry[0];
      return map;
    }, {});

  function createSeed() {
    let seed = "";

    for (let i = 0; i < 5; i++) {
      seed += ALPHABET[
        Math.floor(Math.random() * ALPHABET.length)
      ];
    }

    return seed;
  }

  function hashString(value) {
    let hash = 2166136261;

    for (let i = 0; i < value.length; i++) {
      hash ^= value.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }

    return hash >>> 0;
  }

  function createRandom(seed) {
    let state = hashString(seed);

    return () => {
      state += 0x6D2B79F5;

      let value = state;
      value = Math.imul(value ^ (value >>> 15), value | 1);
      value ^= value + Math.imul(
        value ^ (value >>> 7),
        value | 61
      );

      return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
    };
  }

  function deterministicShuffle(list, seed) {
    const random = createRandom(seed);

    for (let i = list.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));

      [list[i], list[j]] =
        [list[j], list[i]];
    }

    return list;
  }

  function createCode(config) {
    if (config.mode === "world") {
      return `FG-W${config.quantity}-${config.seed}`;
    }

    return `FG-${CONTINENT_CODES[config.continent]}-${config.seed}`;
  }

  function createConfig(options) {
    const config = {
      mode: options.mode,
      continent: options.continent || "",
      quantity: Number(options.quantity || 0),
      seed: options.seed || createSeed()
    };

    config.code = createCode(config);

    return config;
  }

  function parseCode(rawCode) {
    const code = rawCode
      .trim()
      .toUpperCase()
      .replace(/\s+/g, "");

    const worldMatch =
      code.match(/^FG-W(10|20|50|195)-([A-Z2-9]{5})$/);

    if (worldMatch) {
      return createConfig({
        mode: "world",
        quantity: Number(worldMatch[1]),
        seed: worldMatch[2]
      });
    }

    const shortMatch =
      code.match(/^FG-([A-Z2-9]{5})$/);

    if (shortMatch) {
      return createConfig({
        mode: "world",
        quantity: 20,
        seed: shortMatch[1]
      });
    }

    const continentMatch =
      code.match(/^FG-(SA|NA|EU|AF|AS|OC)-([A-Z2-9]{5})$/);

    if (continentMatch) {
      return createConfig({
        mode: "continent",
        continent: CODE_CONTINENTS[continentMatch[1]],
        seed: continentMatch[2]
      });
    }

    return null;
  }

  function buildQuestions(allCountries, config) {
    if (Array.isArray(config.questionCodes) && config.questionCodes.length) {
      const countriesByCode = new Map(
        allCountries.map(country => [country.code, country])
      );

      return config.questionCodes
        .map(code => countriesByCode.get(String(code || "").toUpperCase()))
        .filter(Boolean);
    }

    const source = config.mode === "world"
      ? allCountries
      : allCountries.filter(
        country => country.continent === config.continent
      );

    const sequenceSeed = config.sequenceSeed || config.seed || config.code;
    const questions = deterministicShuffle(
      [...source],
      `${sequenceSeed}:flags`
    );

    return config.mode === "world"
      ? questions.slice(0, config.quantity)
      : questions;
  }

  function readStore() {
    try {
      return FlagGameStorage.getJson(STORAGE_KEY, {});
    } catch (error) {
      console.warn("Desafios locais inválidos:", error);
      return {};
    }
  }

  function saveStore(store) {
    FlagGameStorage.setJson(STORAGE_KEY, store);
  }

  function isBetterResult(candidate, current) {
    if (!current) {
      return true;
    }

    if (candidate.correct !== current.correct) {
      return candidate.correct > current.correct;
    }

    if (candidate.bestStreak !== current.bestStreak) {
      return candidate.bestStreak > current.bestStreak;
    }

    return candidate.durationSeconds < current.durationSeconds;
  }

  function saveLocalResult(result) {
    const store = readStore();
    const eventId =
      result.eventId || FlagGameStorage.createEventId();
    const normalizedResult = {
      ...result,
      eventId
    };
    const entry = store[result.code] || {
      code: result.code,
      attempts: [],
      bestResult: null
    };

    if (
      !entry.attempts.some(attempt =>
        attempt.eventId && attempt.eventId === eventId
      )
    ) {
      entry.attempts.push(normalizedResult);
    }

    if (isBetterResult(normalizedResult, entry.bestResult)) {
      entry.bestResult = normalizedResult;
    }

    store[result.code] = entry;
    saveStore(store);

    return entry;
  }

  function getLocalResult(code) {
    return readStore()[code] || null;
  }

  function getOnlinePayload(code) {
    const entry = getLocalResult(code);

    return {
      source: "localStorage",
      exportedAt: new Date().toISOString(),
      challengeCode: code,
      eventIds: entry && entry.attempts
        ? entry.attempts
          .map(attempt => attempt.eventId)
          .filter(Boolean)
        : [],
      localResult: entry
    };
  }

  return {
    buildQuestions,
    createConfig,
    getLocalResult,
    getOnlinePayload,
    parseCode,
    saveLocalResult
  };
})();

window.FlagGameChallenge = FlagGameChallenge;
