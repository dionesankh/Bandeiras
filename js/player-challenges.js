(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGamePlayerChallenges = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  const CODE_BODY_PATTERN = /^[A-Z2-9]{8}$/;
  const WORLD_VARIATIONS = new Set(["10", "20", "50", "195"]);
  const CONTINENT_VARIATIONS = new Set([
    "south-america",
    "north-america",
    "europe",
    "africa",
    "asia",
    "oceania"
  ]);

  function getSupabase() {
    return root.FlagGameSupabase ? root.FlagGameSupabase.client : null;
  }

  function logChallengeRpc(event, details) {
    console.info("Challenge RPC:", JSON.stringify({
      event,
      ...(details || {})
    }));
  }

  function normalizeCode(rawCode) {
    let body = String(rawCode || "")
      .trim()
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, "");

    if (body.startsWith("FG")) {
      body = body.slice(2);
    }

    return CODE_BODY_PATTERN.test(body) ? `FG-${body}` : "";
  }

  function displayCode(rawCode) {
    return normalizeCode(rawCode) || String(rawCode || "").trim().toUpperCase();
  }

  function hasNetwork() {
    return typeof navigator === "undefined" || navigator.onLine !== false;
  }

  function errorCode(error) {
    const message = String(error && error.message ? error.message : error || "");
    const code = String(error && error.code ? error.code : "");
    const details = String(error && error.details ? error.details : "");
    const hint = String(error && error.hint ? error.hint : "");
    const combined = `${code} ${message} ${details} ${hint}`;

    if (!hasNetwork() || /network|fetch|failed to fetch|internet/i.test(combined)) {
      return "network";
    }

    if (/unauthorized|jwt|auth/i.test(combined)) {
      return "auth";
    }

    if (/expired/i.test(combined)) {
      return "expired";
    }

    if (/protected sequence|sequence integrity|does not contain a protected sequence/i.test(combined)) {
      return "ranked_sequence_missing";
    }

    if (/ranked result is not completed|verified ranked result not found/i.test(combined)) {
      return "ranked_result_missing";
    }

    if (/ranked result metrics are incomplete|metrics complete|metrics.*incomplete/i.test(combined)) {
      return "ranked_result_metrics_incomplete";
    }

    if (/invalid ranked session|ranked session required/i.test(combined)) {
      return "ranked_session_not_found";
    }

    if (/idempotency key already used/i.test(combined)) {
      return "challenge_already_created";
    }

    if (/did not include a code|without code|missing code/i.test(combined)) {
      return "challenge_response_invalid";
    }

    if (/permission denied|42501|row-level security|rls|not allowed/i.test(combined)) {
      return "challenge_permission_denied";
    }

    if (/column .* does not exist|relation .* does not exist|function .* does not exist|schema cache|PGRST202|PGRST204/i.test(combined)) {
      return "server_contract_mismatch";
    }

    if (/daily limit/i.test(combined)) {
      return "daily_limit";
    }

    if (/already completed|already used|completed/i.test(combined)) {
      return "used";
    }

    if (/already has an opponent|unavailable|not found/i.test(combined)) {
      return "unavailable";
    }

    if (/invalid/i.test(combined)) {
      return "invalid";
    }

    return "unknown";
  }

  function readErrorStatus(error) {
    if (!error) return null;

    if (error.status || error.statusCode) {
      return error.status || error.statusCode;
    }

    const context = error.context || error.response || error.originalError || null;
    return context && (context.status || context.statusCode) || null;
  }

  function sanitizeRpcError(error) {
    return {
      code: error && error.code || "",
      message: error && error.message || "",
      details: error && error.details || "",
      hint: error && error.hint || "",
      status: readErrorStatus(error)
    };
  }

  function assertClient() {
    const supabase = getSupabase();

    if (!supabase) {
      const error = new Error("Challenge service unavailable");
      error.challengeCode = "network";
      throw error;
    }

    return supabase;
  }

  async function requireUser() {
    if (!root.FlagGameAuth) {
      const error = new Error("Unauthorized");
      error.challengeCode = "auth";
      throw error;
    }

    if (root.FlagGameAuth.isReady) {
      await root.FlagGameAuth.isReady();
    }

    const user = await root.FlagGameAuth.getCurrentUser();

    if (!user) {
      const error = new Error("Unauthorized");
      error.challengeCode = "auth";
      throw error;
    }

    return user;
  }

  function normalizeRpcResult(data) {
    return Array.isArray(data) ? data[0] : data;
  }

  async function callRpc(name, params) {
    await requireUser();
    logChallengeRpc("call_start", {
      name,
      authenticated: true
    });

    const supabase = assertClient();
    const { data, error } = await supabase.rpc(name, params);

    if (error) {
      error.challengeCode = errorCode(error);
      error.challengeDiagnostic = sanitizeRpcError(error);
      logChallengeRpc("call_error", {
        name,
        code: error.challengeCode,
        rpcError: error.challengeDiagnostic
      });
      throw error;
    }

    const result = normalizeRpcResult(data);
    logChallengeRpc("call_success", {
      name,
      hasData: Boolean(result)
    });
    return result;
  }

  function toLocalConfig(startPayload, code) {
    const config = startPayload && startPayload.config ? startPayload.config : {};
    const mode = String(config.mode || "");
    const variation = String(config.variation || "");
    const seed = String(config.seed || code || "");
    const questionCodes = Array.isArray(config.question_codes)
      ? config.question_codes.map(item => String(item || "").toUpperCase()).filter(Boolean)
      : [];

    if (mode === "world") {
      return {
        mode: "world",
        quantity: Number(config.question_count || variation || 0),
        seed,
        sequenceSeed: seed,
        questionCodes,
        sequenceHash: config.sequence_hash || "",
        code: `FG-W${Number(config.question_count || variation || 0)}-${seed.slice(0, 5).toUpperCase()}`,
        backendChallengeCode: code,
        backendChallenge: startPayload
      };
    }

    if (mode === "continent") {
      return {
        mode: "continent",
        continent: variation,
        quantity: Number(config.question_count || 0),
        seed,
        sequenceSeed: seed,
        questionCodes,
        sequenceHash: config.sequence_hash || "",
        code: `FG-${variation}-${seed.slice(0, 5).toUpperCase()}`,
        backendChallengeCode: code,
        backendChallenge: startPayload
      };
    }

    return null;
  }

  function supportedModeVariation(source) {
    if (!source) return null;

    if (source.mode === "world") {
      const variation = String(source.quantity || source.total || "");
      if (!WORLD_VARIATIONS.has(variation)) return null;

      return {
        mode: "world",
        variation
      };
    }

    if (source.mode === "continent" && source.continent) {
      const variation = String(source.continent);
      if (!CONTINENT_VARIATIONS.has(variation)) return null;

      return {
        mode: "continent",
        variation
      };
    }

    return null;
  }

  async function startBaseMatch(config) {
    const supported = supportedModeVariation(config);

    if (!supported) {
      const error = new Error("Unsupported challenge mode");
      error.challengeCode = "unsupported";
      throw error;
    }

    logChallengeRpc("start_base_match", {
      mode: supported.mode,
      variation: supported.variation
    });

    const payload = await callRpc("start_challenge_base_match", {
      p_mode: supported.mode,
      p_variation: supported.variation
    });
    const localConfig = toLocalConfig(payload, "");
    const baseMatchSessionId = payload && (payload.base_match_session_id || payload.session_id);

    logChallengeRpc("start_base_match_result", {
      mode: supported.mode,
      variation: supported.variation,
      base_match_session_id: baseMatchSessionId || "",
      hasBaseMatchSessionId: Boolean(baseMatchSessionId),
      hasQuestionCodes: Boolean(localConfig && localConfig.questionCodes.length)
    });

    if (!baseMatchSessionId || !localConfig || !localConfig.questionCodes.length) {
      const error = new Error("Invalid base match configuration");
      error.challengeCode = "base_required";
      throw error;
    }

    return {
      ...payload,
      localConfig
    };
  }

  async function createFromMatch(match) {
    const supported = supportedModeVariation(match);
    const baseSession = match && match.challengeBaseSession;

    if (!supported || !baseSession || !baseSession.nonce) {
      const error = new Error("Challenge base match required");
      error.challengeCode = "unsupported";
      throw error;
    }

    logChallengeRpc("create_from_match", {
      mode: supported.mode,
      variation: supported.variation,
      base_match_session_id: baseSession.base_match_session_id || baseSession.session_id || "",
      hasBaseSession: true
    });

    const payload = await callRpc("create_challenge_from_completed_match", {
      p_base_nonce: baseSession.nonce,
      p_event_id: String(match.eventId || ""),
      p_correct: Number(match.correct || 0),
      p_wrong: Number(match.wrong || 0),
      p_skipped: Number(match.skipped || 0),
      p_total: Number(match.total || 0),
      p_time_ms: Number(match.timeMs || 0),
      p_streak: Number(match.bestStreak || 0),
      p_idemp_key: String(match.idempotencyKey || match.eventId || "")
    });

    logChallengeRpc("create_from_match_result", {
      mode: supported.mode,
      variation: supported.variation,
      hasCode: Boolean(payload && payload.code)
    });

    return payload;
  }

  async function createFromRankedMatch(match) {
    const supported = supportedModeVariation(match);
    const rankedSessionId = match && (match.rankedSessionId || match.sessionId);

    if (!supported || !rankedSessionId) {
      const error = new Error("Ranked session required");
      error.challengeCode = "ranked_result_missing";
      throw error;
    }

    if (!match.sequenceHash || !Array.isArray(match.questionCodes) || !match.questionCodes.length) {
      const error = new Error("Ranked protected sequence required");
      error.challengeCode = "ranked_sequence_missing";
      throw error;
    }

    logChallengeRpc("create_from_ranked_match", {
      mode: supported.mode,
      variation: supported.variation,
      ranked_session_id: rankedSessionId,
      hasSequenceHash: Boolean(match.sequenceHash),
      questionCount: match.questionCodes.length
    });

    const payload = await callRpc("create_challenge_from_ranked_session", {
      p_ranked_session_id: rankedSessionId,
      p_idemp_key: String(match.idempotencyKey || match.eventId || "")
    });

    logChallengeRpc("create_from_ranked_match_result", {
      mode: supported.mode,
      variation: supported.variation,
      hasCode: Boolean(payload && payload.code)
    });

    if (!payload || !payload.code) {
      const error = new Error("Challenge RPC response did not include a code");
      error.challengeCode = "challenge_response_invalid";
      throw error;
    }

    return payload;
  }

  async function preview(rawCode) {
    const code = normalizeCode(rawCode);

    if (!code) {
      const error = new Error("Invalid challenge code");
      error.challengeCode = "invalid";
      throw error;
    }

    return callRpc("get_challenge_preview", { p_code: code });
  }

  async function acceptAndStart(rawCode) {
    const code = normalizeCode(rawCode);

    if (!code) {
      const error = new Error("Invalid challenge code");
      error.challengeCode = "invalid";
      throw error;
    }

    await preview(code);
    await callRpc("accept_challenge", { p_challenge_code: code });

    const started = await callRpc("start_challenge_session", {
      p_challenge_code: code
    });
    const config = toLocalConfig(started, code);

    if (!config) {
      const error = new Error("Unsupported challenge mode");
      error.challengeCode = "unsupported";
      throw error;
    }

    return {
      ...started,
      code,
      localConfig: config
    };
  }

  async function submitResult(session, result) {
    if (!session || !session.nonce) return null;

    return callRpc("submit_challenge_result", {
      p_nonce: session.nonce,
      p_event_id: String(result.eventId || ""),
      p_correct: Number(result.correct || 0),
      p_wrong: Number(result.wrong || 0),
      p_skipped: Number(result.skipped || 0),
      p_total: Number(result.total || 0),
      p_time_ms: Number(result.timeMs || 0),
      p_streak: Number(result.bestStreak || 0)
    });
  }

  return {
    acceptAndStart,
    createFromMatch,
    createFromRankedMatch,
    displayCode,
    errorCode,
    normalizeCode,
    preview,
    startBaseMatch,
    submitResult
  };
});
