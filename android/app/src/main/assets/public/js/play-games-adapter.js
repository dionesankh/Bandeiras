(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGamePlayGames = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  const PLUGIN_NAMES = [
    "FlagGamePlayGames",
    "FlagGamePlayGamesPlugin"
  ];

  function structuredError(code, message, details) {
    const payload = {
      code,
      message
    };

    if (details) {
      payload.details = String(details);
    }

    return payload;
  }

  function getCapacitor() {
    return root && root.Capacitor
      ? root.Capacitor
      : null;
  }

  function getCapacitorPlatform() {
    const capacitor = getCapacitor();

    if (capacitor && typeof capacitor.getPlatform === "function") {
      try {
        return String(capacitor.getPlatform() || "");
      } catch (error) {
        return "";
      }
    }

    return "";
  }

  function isAndroidPlatform() {
    return (
      getCapacitorPlatform() === "android" ||
      Boolean(root && root.FlagGameNativePlatform === "android") ||
      Boolean(root && root.FlagGameAndroid && root.FlagGameAndroid.isAndroidApp === true)
    );
  }

  function getNativePlugin() {
    const capacitor = getCapacitor();
    const plugins = capacitor && capacitor.Plugins
      ? capacitor.Plugins
      : {};

    return PLUGIN_NAMES
      .map(name => plugins[name])
      .find(plugin => plugin && typeof plugin === "object") || null;
  }

  function unavailableResult(method) {
    return {
      available: false,
      authenticated: false,
      status: isAndroidPlatform() ? "native_plugin_unavailable" : "unsupported_platform",
      method,
      player: null,
      error: structuredError(
        isAndroidPlatform() ? "native_plugin_unavailable" : "unsupported_platform",
        "Google Play Games Services is not available on this platform."
      )
    };
  }

  function normalizeNativeResult(method, value) {
    const source = value && typeof value === "object"
      ? value
      : {};

    return {
      available: source.available === true,
      configured: source.configured === true,
      authenticated: source.authenticated === true,
      status: String(source.status || (source.available === true ? "available" : "unavailable")),
      playServicesStatus: source.playServicesStatus,
      player: source.player || null,
      payload: source.payload || null,
      conflictingPayload: source.conflictingPayload || null,
      conflict: source.conflict === true,
      metadata: source.metadata || null,
      leaderboardKey: source.leaderboardKey || null,
      achievementKey: source.achievementKey || null,
      score: source.score,
      resourceKey: source.resourceKey || null,
      feature: source.feature || null,
      method,
      error: source.error || null
    };
  }

  async function callNative(method) {
    const nativePlugin = getNativePlugin();

    if (
      !isAndroidPlatform() ||
      !nativePlugin ||
      typeof nativePlugin[method] !== "function"
    ) {
      return unavailableResult(method);
    }

    try {
      return normalizeNativeResult(method, await nativePlugin[method]({}));
    } catch (error) {
      return {
        available: false,
        authenticated: false,
        status: "error",
        method,
        player: null,
        error: structuredError(
          "native_call_failed",
          "Google Play Games Services call failed.",
          error && error.message ? error.message : error
        )
      };
    }
  }

  return {
    get available() {
      return Boolean(isAndroidPlatform() && getNativePlugin());
    },
    get leaderboards() {
      return false;
    },
    get cloudSave() {
      return false;
    },
    get achievements() {
      return false;
    },
    isAvailable() {
      return callNative("isAvailable");
    },
    getAuthenticationStatus() {
      return callNative("getAuthenticationStatus");
    },
    requestAuthenticationRetry() {
      return callNative("requestAuthenticationRetry");
    },
    getPlayerSummary() {
      return callNative("getPlayerSummary");
    },
    syncSavedGame(payload) {
      return callNativeWithPayload("syncSavedGame", payload);
    },
    commitSavedGame(payload) {
      return callNativeWithPayload("commitSavedGame", payload);
    },
    submitLeaderboardScore(payload) {
      return callNativeWithPayload("submitLeaderboardScore", payload);
    },
    unlockAchievement(payload) {
      return callNativeWithPayload("unlockAchievement", payload);
    },
    openLeaderboards() {
      return callNative("openLeaderboards");
    },
    openAchievements() {
      return callNative("openAchievements");
    }
  };

  async function callNativeWithPayload(method, payload) {
    const nativePlugin = getNativePlugin();

    if (
      !isAndroidPlatform() ||
      !nativePlugin ||
      typeof nativePlugin[method] !== "function"
    ) {
      return unavailableResult(method);
    }

    try {
      return normalizeNativeResult(
        method,
        await nativePlugin[method](payload || {})
      );
    } catch (error) {
      return {
        available: false,
        authenticated: false,
        status: "error",
        method,
        player: null,
        payload: null,
        error: structuredError(
          "native_call_failed",
          "Google Play Games Services call failed.",
          error && error.message ? error.message : error
        )
      };
    }
  }
});
