(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGameRankingsAPI = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  const CACHE_KEY = "flagGameRankingsCache";
  const CACHE_TTL = 30000; // 30 segundos
  const RANKINGS_SCHEMA = "public";
  const RANKINGS_OBJECT = "global_rankings";
  const RANKINGS_COLUMNS = [
    "user_id",
    "mode",
    "variation",
    "rules_version",
    "score",
    "correct_answers",
    "elapsed_time_ms",
    "best_streak",
    "achieved_at",
    "nickname",
    "country_code",
    "is_supporter"
  ].join(",");
  const CURRENT_RULES_VERSION = 1;

  function getSupabase() {
    return root.FlagGameSupabase ? root.FlagGameSupabase.client : null;
  }

  function createRankingError(kind, message, cause) {
    const error = new Error(message);
    error.name = "RankingLoadError";
    error.kind = kind;
    error.cause = cause;
    return error;
  }

  function getHttpStatus(error) {
    if (!error) {
      return null;
    }

    if (error.status || error.statusCode) {
      return Number(error.status || error.statusCode);
    }

    return error.code === "42501" ? 403 : null;
  }

  function classifySupabaseError(error) {
    const code = String((error && error.code) || "");
    const message = String((error && error.message) || "");
    const status = getHttpStatus(error);

    if (
      typeof navigator !== "undefined" &&
      navigator.onLine === false
    ) {
      return "offline";
    }

    if (
      error &&
      (error.name === "TypeError" || error.name === "AbortError") &&
      !status &&
      !code
    ) {
      return "offline";
    }

    if (
      status === 401 ||
      code === "PGRST301" ||
      /jwt|token|session/i.test(message)
    ) {
      return "auth";
    }

    if (status === 403 || code === "42501") {
      return "permission";
    }

    if (
      status === 404 ||
      code === "PGRST205" ||
      /schema cache|could not find the table|could not find/i.test(message)
    ) {
      return "missing_object";
    }

    return "unexpected";
  }

  function logSupabaseError(operation, params, error) {
    const sanitizedError = {
      operation,
      object: `${RANKINGS_SCHEMA}.${RANKINGS_OBJECT}`,
      params,
      code: error && error.code,
      message: error && error.message,
      details: error && error.details,
      hint: error && error.hint,
      status: error && (error.status || error.statusCode || null)
    };

    console.error("Supabase ranking error:", JSON.stringify(sanitizedError));
  }

  function toRankingError(operation, params, error) {
    logSupabaseError(operation, params, error);
    const kind = classifySupabaseError(error);
    return createRankingError(kind, "Ranking request failed.", error);
  }

  function getUserMessageKey(error) {
    switch (error && error.kind) {
      case "offline":
        return "noInternet";
      case "auth":
        return "rankingAuthRequired";
      case "permission":
      case "missing_object":
      case "unexpected":
      default:
        return "rankingLoadError";
    }
  }

  /**
   * Busca a lista de ranking filtrada.
   */
  async function getRankings(mode, variation, page = 0, limit = 50, rulesVersion = CURRENT_RULES_VERSION) {
    const supabase = getSupabase();
    if (!supabase) throw new Error("Serviço offline.");

    const from = page * limit;
    const to = from + limit - 1;
    const params = {
      mode,
      variation,
      rules_version: rulesVersion,
      page,
      limit
    };

    try {
      // Nota: global_rankings já contém apenas o melhor resultado por usuário
      const { data, error, count } = await supabase
        .from(RANKINGS_OBJECT)
        .select(RANKINGS_COLUMNS, { count: 'exact' })
        .eq('mode', mode)
        .eq('variation', variation)
        .eq('rules_version', rulesVersion)
        .order('score', { ascending: false })
        .order('correct_answers', { ascending: false })
        .order('elapsed_time_ms', { ascending: true })
        .range(from, to);

      if (error) throw toRankingError("getRankings", params, error);

      return {
        items: data || [],
        total: count,
        page
      };
    } catch (err) {
      if (err && err.name === "RankingLoadError") {
        throw err;
      }

      throw toRankingError("getRankings", params, err);
    }
  }

  /**
   * Obtém a posição absoluta do usuário atual em um ranking específico.
   * Como a view não tem rank fixo, comparamos estatísticas.
   */
  async function getUserPosition(mode, variation, rulesVersion = CURRENT_RULES_VERSION) {
    const supabase = getSupabase();
    const user = root.FlagGameAuth ? await root.FlagGameAuth.getCurrentUser() : null;
    if (!supabase || !user) return null;
    const params = {
      mode,
      variation,
      rules_version: rulesVersion
    };

    try {
        // 1. Obter o melhor resultado do usuário
        const { data: myBest, error: myError } = await supabase
            .from(RANKINGS_OBJECT)
            .select(RANKINGS_COLUMNS)
            .eq('user_id', user.id)
            .eq('mode', mode)
            .eq('variation', variation)
            .eq('rules_version', rulesVersion)
            .maybeSingle();

        if (myError) throw toRankingError("getUserPosition.currentUser", params, myError);
        if (!myBest) return null;

        // 2. Contar quantos estão acima
        // Critério de desempate idêntico à view
        const { count, error: countError } = await supabase
            .from(RANKINGS_OBJECT)
            .select("user_id", { count: 'exact', head: true })
            .eq('mode', mode)
            .eq('variation', variation)
            .eq('rules_version', rulesVersion)
            .or(`score.gt.${myBest.score},and(score.eq.${myBest.score},correct_answers.gt.${myBest.correct_answers}),and(score.eq.${myBest.score},correct_answers.eq.${myBest.correct_answers},elapsed_time_ms.lt.${myBest.elapsed_time_ms})`);

        if (countError) throw toRankingError("getUserPosition.countAbove", params, countError);

        return {
            rank: count + 1,
            stats: myBest
        };
    } catch (err) {
        return null;
    }
  }

  return {
    getRankings,
    getUserPosition,
    getUserMessageKey
  };
});
