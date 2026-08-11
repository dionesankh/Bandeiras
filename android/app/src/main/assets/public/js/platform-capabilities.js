(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGamePlatform = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  const DEFAULT_CONFIG = {
    googlePlayUrl: ""
  };

  function getConfig() {
    return {
      ...DEFAULT_CONFIG,
      ...(
        root && root.FlagGamePlatformConfig
          ? root.FlagGamePlatformConfig
          : {}
      )
    };
  }

  function getNavigator() {
    return root && root.navigator
      ? root.navigator
      : {};
  }

  function getUserAgent() {
    return String(getNavigator().userAgent || "");
  }

  function getRuntime() {
    const browserRuntime = root && root.browser && root.browser.runtime;
    const chromeRuntime = root && root.chrome && root.chrome.runtime;

    return browserRuntime || chromeRuntime || null;
  }

  function getRuntimeUrl() {
    const runtime = getRuntime();

    if (!runtime || typeof runtime.getURL !== "function") {
      return "";
    }

    try {
      return runtime.getURL("");
    } catch (error) {
      return "";
    }
  }

  function isExtensionProtocol(protocol) {
    return [
      "chrome-extension:",
      "moz-extension:",
      "ms-browser-extension:"
    ].includes(protocol);
  }

  function getLocationProtocol() {
    return root && root.location && root.location.protocol
      ? root.location.protocol
      : "";
  }

  function isAndroidApp() {
    const capacitor = root && root.Capacitor;

    if (
      capacitor &&
      typeof capacitor.getPlatform === "function" &&
      capacitor.getPlatform() === "android"
    ) {
      return true;
    }

    if (
      root &&
      root.FlagGameAndroid &&
      root.FlagGameAndroid.isAndroidApp === true
    ) {
      return true;
    }

    return Boolean(
      root &&
      root.FlagGameNativePlatform === "android"
    );
  }

  function isFirefoxExtension() {
    return getLocationProtocol() === "moz-extension:";
  }

  function isEdgeExtension() {
    const runtimeUrl = getRuntimeUrl();
    const userAgent = getUserAgent();

    return (
      getLocationProtocol() === "ms-browser-extension:" ||
      runtimeUrl.startsWith("ms-browser-extension://") ||
      (
        getLocationProtocol() === "chrome-extension:" &&
        /Edg\//i.test(userAgent)
      )
    );
  }

  function isChromeExtension() {
    if (isEdgeExtension() || isFirefoxExtension()) {
      return false;
    }

    return (
      getLocationProtocol() === "chrome-extension:" ||
      getRuntimeUrl().startsWith("chrome-extension://")
    );
  }

  function isAnyExtension() {
    return (
      isChromeExtension() ||
      isEdgeExtension() ||
      isFirefoxExtension() ||
      isExtensionProtocol(getLocationProtocol())
    );
  }

  function isWeb() {
    return !isAndroidApp() && !isAnyExtension();
  }

  function getPlayGamesAdapter() {
    return root && root.FlagGamePlayGames
      ? root.FlagGamePlayGames
      : null;
  }

  function hasPlayGamesPlugin() {
    const adapter = getPlayGamesAdapter();

    return Boolean(
      isAndroidApp() &&
      adapter &&
      adapter.available === true
    );
  }

  function supportsLocalHistory() {
    return true;
  }

  function supportsPlayGames() {
    return hasPlayGamesPlugin();
  }

  function supportsGlobalLeaderboards() {
    const adapter = getPlayGamesAdapter();

    return Boolean(
      hasPlayGamesPlugin() &&
      adapter.leaderboards === true
    );
  }

  function supportsCloudSave() {
    const adapter = getPlayGamesAdapter();

    return Boolean(
      hasPlayGamesPlugin() &&
      adapter.cloudSave === true
    );
  }

  function supportsOfficialAchievements() {
    const adapter = getPlayGamesAdapter();

    return Boolean(
      hasPlayGamesPlugin() &&
      adapter.achievements === true
    );
  }

  function getCapabilities() {
    return {
      isAndroidApp: isAndroidApp(),
      isWeb: isWeb(),
      isChromeExtension: isChromeExtension(),
      isEdgeExtension: isEdgeExtension(),
      isFirefoxExtension: isFirefoxExtension(),
      supportsLocalHistory: supportsLocalHistory(),
      supportsPlayGames: supportsPlayGames(),
      supportsGlobalLeaderboards: supportsGlobalLeaderboards(),
      supportsCloudSave: supportsCloudSave(),
      supportsOfficialAchievements: supportsOfficialAchievements()
    };
  }

  function shouldShowAndroidDisclosure() {
    return !isAndroidApp();
  }

  function getGooglePlayUrl() {
    return String(getConfig().googlePlayUrl || "").trim();
  }

  return {
    getCapabilities,
    getGooglePlayUrl,
    isAndroidApp,
    isChromeExtension,
    isEdgeExtension,
    isFirefoxExtension,
    isWeb,
    shouldShowAndroidDisclosure,
    supportsCloudSave,
    supportsGlobalLeaderboards,
    supportsLocalHistory,
    supportsOfficialAchievements,
    supportsPlayGames
  };
});
