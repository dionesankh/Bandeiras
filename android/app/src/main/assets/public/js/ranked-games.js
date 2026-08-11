(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGameRanked = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  let activeSession = null;
  const RPC_TIMEOUT_MS = 15000;

  function getSupabase() {
    return root.FlagGameSupabase ? root.FlagGameSupabase.client : null;
  }

  function logRankedError(operation, err) {
    console.error("Ranked RPC Error:", JSON.stringify({
      operation,
      code: err && err.code,
      message: err && err.message,
      details: err && err.details,
      hint: err && err.hint,
      status: err && (err.status || err.statusCode || null)
    }));
  }

  function createTimeoutError(operation) {
    const error = new Error(`Tempo esgotado ao executar ${operation}.`);
    error.code = "RANKED_RPC_TIMEOUT";
    return error;
  }

  function withTimeout(operation, promise) {
    let timeoutId = null;
    const timeout = new Promise((_, reject) => {
      timeoutId = setTimeout(
        () => reject(createTimeoutError(operation)),
        RPC_TIMEOUT_MS
      );
    });

    return Promise.race([promise, timeout]).finally(() => {
      if (timeoutId !== null) {
        clearTimeout(timeoutId);
      }
    });
  }

  function toRankedLocalConfig(payload, mode, variation) {
    const config = payload && payload.config ? payload.config : {};
    const questionCodes = Array.isArray(config.question_codes)
      ? config.question_codes.map(item => String(item || "").toUpperCase()).filter(Boolean)
      : [];
    const questionCount = Number(config.question_count || (mode === "world" ? variation : 0) || 0);
    const seed = String(config.seed || "");

    if (!questionCodes.length || !config.sequence_hash) {
      return null;
    }

    if (mode === "world") {
      return {
        mode: "world",
        quantity: questionCount,
        seed,
        sequenceSeed: seed,
        questionCodes,
        sequenceHash: String(config.sequence_hash || ""),
        code: `FG-W${questionCount}-${seed.slice(0, 5).toUpperCase()}`,
        backendRankedSession: payload
      };
    }

    if (mode === "continent") {
      return {
        mode: "continent",
        continent: String(config.variation || variation || ""),
        quantity: questionCount,
        seed,
        sequenceSeed: seed,
        questionCodes,
        sequenceHash: String(config.sequence_hash || ""),
        code: `FG-${String(config.variation || variation || "")}-${seed.slice(0, 5).toUpperCase()}`,
        backendRankedSession: payload
      };
    }

    return null;
  }

  /**
   * Inicia uma nova sessão ranqueada no servidor.
   * @param {string} mode - 'world' ou 'continent'
   * @param {string} variation - Ex: '10', '20', 'europe', etc.
   */
  async function createSession(mode, variation) {
    const supabase = getSupabase();
    if (!supabase) throw new Error("Serviço de ranking indisponível.");

    try {
      console.info("Ranked RPC start:", JSON.stringify({
        operation: "create_ranked_session",
        mode,
        variation
      }));

      const { data, error } = await withTimeout(
        "create_ranked_session",
        supabase.rpc('create_ranked_session', {
          p_mode: mode,
          p_variation: variation
        })
      );

      if (error) throw error;

      const rankedSessionId = data.ranked_session_id || data.session_id;
      const localConfig = toRankedLocalConfig(data, mode, variation);

      activeSession = {
        sessionId: data.session_id,
        rankedSessionId,
        nonce: data.nonce,
        expiresAt: new Date(data.expires_at).getTime(),
        mode,
        variation,
        localConfig,
        hasProtectedSequence: Boolean(localConfig && localConfig.questionCodes.length && localConfig.sequenceHash)
      };

      console.info("Ranked RPC success:", JSON.stringify({
        operation: "create_ranked_session",
        mode,
        variation,
        ranked_session_id: rankedSessionId || "",
        hasProtectedSequence: activeSession.hasProtectedSequence
      }));

      return activeSession;
    } catch (err) {
      logRankedError("create_ranked_session", err);
      activeSession = null;
      throw err;
    }
  }

  /**
   * Envia o resultado da partida para validação.
   */
  async function submitResult(gameResult) {
    const supabase = getSupabase();
    if (!supabase || !activeSession) {
        throw new Error("Sessão ranqueada inválida ou expirada.");
    }

    if (Date.now() > activeSession.expiresAt) {
        activeSession = null;
        throw new Error("Sessão expirada.");
    }

    try {
      console.info("Ranked RPC start:", JSON.stringify({
        operation: "submit_ranked_result",
        eventId: gameResult.eventId,
        params: {
          correct: gameResult.correct,
          wrong: gameResult.wrongAnswers || 0,
          skipped: gameResult.skips || 0,
          total: gameResult.total,
          time_ms: gameResult.durationSeconds * 1000,
          best_streak: gameResult.bestStreak
        }
      }));

      const { data, error } = await withTimeout(
        "submit_ranked_result",
        supabase.rpc('submit_ranked_result', {
          p_nonce: activeSession.nonce,
          p_event_id: gameResult.eventId,
          p_correct: gameResult.correct,
          p_wrong: gameResult.wrongAnswers || 0,
          p_skipped: gameResult.skips || 0,
          p_total: gameResult.total,
          p_time_ms: gameResult.durationSeconds * 1000,
          p_streak: gameResult.bestStreak
        })
      );

      if (error) throw error;

      // Limpar sessão após envio (nonce de uso único)
      activeSession = null;
      console.info("Ranked RPC success:", JSON.stringify({
        operation: "submit_ranked_result",
        eventId: gameResult.eventId,
        ranked_session_id: data && (data.ranked_session_id || gameResult.rankedSessionId || "")
      }));
      return data; // { result_id, status: 'verified' }
    } catch (err) {
      logRankedError("submit_ranked_result", err);
      activeSession = null;
      throw err;
    }
  }

  function getActiveSession() {
    if (!activeSession) return null;
    if (Date.now() > activeSession.expiresAt) {
        activeSession = null;
        return null;
    }
    return activeSession;
  }

  function cancelSession() {
    activeSession = null;
  }

  function isRankedMatchActive() {
    return !!getActiveSession();
  }

  return {
    createSession,
    submitResult,
    getActiveSession,
    cancelSession,
    isRankedMatchActive
  };
});
