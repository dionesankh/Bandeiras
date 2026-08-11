const FlagGameRanking = (() => {
  const PLAYER_KEY = "flagGameRankingPlayer";
  const QUEUE_KEY = "flagGameRankingQueue";
  const SCHEMA_VERSION = 1;

  function now() {
    return new Date().toISOString();
  }

  function createPlayerId() {
    if (typeof crypto !== "undefined" && crypto.randomUUID) {
      return `fgp_${crypto.randomUUID()}`;
    }

    return `fgp_${Date.now().toString(36)}_${Math.random()
      .toString(36)
      .slice(2, 10)}`;
  }

  function detectCountry() {
    const language = navigator.language || "";
    const parts = language.split("-");

    return parts[1] ? parts[1].toUpperCase() : "";
  }

  function sanitizeNickname(nickname) {
    return String(nickname || "")
      .replace(/[\u0000-\u001f\u007f]/g, "")
      .trim()
      .slice(0, 24);
  }

  function sanitizeCountry(country) {
    return String(country || "")
      .replace(/[^a-zA-Z]/g, "")
      .toUpperCase()
      .slice(0, 2);
  }

  function createPlayer() {
    const timestamp = now();

    return {
      schemaVersion: SCHEMA_VERSION,
      playerId: createPlayerId(),
      nickname: "",
      country: detectCountry(),
      createdAt: timestamp,
      updatedAt: timestamp
    };
  }

  function getPlayer() {
    try {
      const player =
        FlagGameStorage.getJson(PLAYER_KEY, null);

      if (player && player.playerId) {
        return {
          ...createPlayer(),
          ...player,
          schemaVersion: SCHEMA_VERSION
        };
      }

    } catch (error) {
      console.warn("Player local invalido:", error);
    }

    const player = createPlayer();
    savePlayer(player);

    return player;
  }

  function savePlayer(player) {
    const normalizedPlayer = {
      ...player,
      schemaVersion: SCHEMA_VERSION,
      nickname: sanitizeNickname(player.nickname),
      country: sanitizeCountry(player.country),
      updatedAt: now()
    };

    FlagGameStorage.setJson(PLAYER_KEY, normalizedPlayer);

    return normalizedPlayer;
  }

  function updatePlayer(changes) {
    return savePlayer({
      ...getPlayer(),
      ...changes
    });
  }

  function readQueue() {
    try {
      return FlagGameStorage.getJson(QUEUE_KEY, []);
    } catch (error) {
      console.warn("Fila de ranking invalida:", error);
      return [];
    }
  }

  function saveQueue(queue) {
    FlagGameStorage.setJson(QUEUE_KEY, queue);
  }

  function enqueueScore(payload) {
    const queue = readQueue();
    const queuedPayload = {
      id: payload.eventId ||
        FlagGameStorage.createEventId(),
      status: "pending",
      createdAt: now(),
      payload
    };

    queue.push(queuedPayload);
    saveQueue(queue);

    return queuedPayload;
  }

  function getPendingScores() {
    return readQueue().filter(item => item.status === "pending");
  }

  function markScoreSubmitted(id) {
    const queue = readQueue().map(item => {
      if (item.id !== id) {
        return item;
      }

      return {
        ...item,
        status: "submitted",
        submittedAt: now()
      };
    });

    saveQueue(queue);
  }

  function buildScorePayload(gameResult, profileSummary, achievementSummary) {
    const player = getPlayer();
    const eventId =
      gameResult.eventId || FlagGameStorage.createEventId();

    return {
      schemaVersion: SCHEMA_VERSION,
      type: "ranking-score",
      eventId,
      createdAt: now(),
      player: {
        playerId: player.playerId,
        nickname: player.nickname,
        country: player.country
      },
      score: {
        mode: gameResult.mode,
        continent: gameResult.continent || "",
        score: gameResult.correct,
        total: gameResult.total,
        percent: gameResult.percent,
        durationSeconds: gameResult.durationSeconds,
        bestStreak: gameResult.bestStreak,
        challengeCode: gameResult.challengeCode || "",
        eventId
      },
      achievements: {
        points: achievementSummary.points,
        unlocked: achievementSummary.unlocked,
        total: achievementSummary.total
      },
      profile: {
        gamesPlayed: profileSummary.gamesPlayed,
        totalCorrect: profileSummary.totalCorrect,
        averagePercent: profileSummary.averagePercent
      },
      privacy: {
        personalDataIncluded: false,
        loginRequired: false
      }
    };
  }

  function createBackendClient(adapter) {
    return {
      submitScore(payload) {
        return adapter.submitScore(payload);
      },
      fetchLeaderboard(query) {
        return adapter.fetchLeaderboard(query);
      },
      syncPlayer(player) {
        return adapter.syncPlayer(player);
      }
    };
  }

  function createOfflineAdapter() {
    return {
      submitScore(payload) {
        return Promise.resolve({
          ok: false,
          status: "offline",
          payload
        });
      },
      fetchLeaderboard(query) {
        return Promise.resolve({
          ok: false,
          status: "offline",
          query,
          items: []
        });
      },
      syncPlayer(player) {
        return Promise.resolve({
          ok: false,
          status: "offline",
          player
        });
      }
    };
  }

  return {
    buildScorePayload,
    createBackendClient,
    createOfflineAdapter,
    enqueueScore,
    getPendingScores,
    getPlayer,
    markScoreSubmitted,
    updatePlayer
  };
})();
