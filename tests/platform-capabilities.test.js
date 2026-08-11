const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.join(__dirname, "..", "js", "platform-capabilities.js"),
  "utf8"
);

function loadPlatform(contextValues = {}) {
  const context = {
    console,
    ...contextValues
  };

  vm.runInNewContext(source, context, {
    filename: "platform-capabilities.js"
  });

  return context.FlagGamePlatform;
}

function testWebDefaults() {
  const platform = loadPlatform({
    navigator: { userAgent: "Mozilla/5.0" },
    location: { protocol: "https:" }
  });
  const capabilities = platform.getCapabilities();

  assert.equal(capabilities.isWeb, true);
  assert.equal(capabilities.isAndroidApp, false);
  assert.equal(capabilities.supportsLocalHistory, true);
  assert.equal(capabilities.supportsPlayGames, false);
  assert.equal(capabilities.supportsGlobalLeaderboards, false);
  assert.equal(capabilities.supportsCloudSave, false);
  assert.equal(capabilities.supportsOfficialAchievements, false);
  assert.equal(platform.shouldShowAndroidDisclosure(), true);
  assert.equal(platform.getGooglePlayUrl(), "");
}

function testChromeExtension() {
  const platform = loadPlatform({
    navigator: { userAgent: "Chrome/120" },
    location: { protocol: "chrome-extension:" },
    chrome: {
      runtime: {
        getURL: () => "chrome-extension://abc/"
      }
    }
  });
  const capabilities = platform.getCapabilities();

  assert.equal(capabilities.isChromeExtension, true);
  assert.equal(capabilities.isWeb, false);
  assert.equal(capabilities.supportsGlobalLeaderboards, false);
}

function testEdgeExtension() {
  const platform = loadPlatform({
    navigator: { userAgent: "Edg/120" },
    location: { protocol: "chrome-extension:" },
    chrome: {
      runtime: {
        getURL: () => "chrome-extension://edge/"
      }
    }
  });
  const capabilities = platform.getCapabilities();

  assert.equal(capabilities.isEdgeExtension, true);
  assert.equal(capabilities.isChromeExtension, false);
}

function testFirefoxExtension() {
  const platform = loadPlatform({
    navigator: { userAgent: "Firefox/120" },
    location: { protocol: "moz-extension:" },
    browser: {
      runtime: {
        getURL: () => "moz-extension://abc/"
      }
    }
  });
  const capabilities = platform.getCapabilities();

  assert.equal(capabilities.isFirefoxExtension, true);
  assert.equal(capabilities.isWeb, false);
}

function testAndroidWithoutPlugin() {
  const platform = loadPlatform({
    FlagGameNativePlatform: "android",
    navigator: { userAgent: "Android" },
    location: { protocol: "https:" }
  });
  const capabilities = platform.getCapabilities();

  assert.equal(capabilities.isAndroidApp, true);
  assert.equal(capabilities.supportsPlayGames, false);
  assert.equal(capabilities.supportsGlobalLeaderboards, false);
  assert.equal(capabilities.supportsCloudSave, false);
  assert.equal(capabilities.supportsOfficialAchievements, false);
  assert.equal(platform.shouldShowAndroidDisclosure(), false);
}

function testAndroidWithPlugin() {
  const platform = loadPlatform({
    FlagGameNativePlatform: "android",
    FlagGamePlayGames: {
      available: true,
      leaderboards: false,
      cloudSave: false,
      achievements: false
    },
    navigator: { userAgent: "Android" },
    location: { protocol: "https:" }
  });
  const capabilities = platform.getCapabilities();

  assert.equal(capabilities.supportsPlayGames, true);
  assert.equal(capabilities.supportsGlobalLeaderboards, false);
  assert.equal(capabilities.supportsCloudSave, false);
  assert.equal(capabilities.supportsOfficialAchievements, false);
}

function testConfiguredPlayStoreUrl() {
  const platform = loadPlatform({
    FlagGamePlatformConfig: {
      googlePlayUrl: "https://play.google.com/store/apps/details?id=app"
    },
    navigator: { userAgent: "Mozilla/5.0" },
    location: { protocol: "https:" }
  });

  assert.equal(
    platform.getGooglePlayUrl(),
    "https://play.google.com/store/apps/details?id=app"
  );
}

[
  testWebDefaults,
  testChromeExtension,
  testEdgeExtension,
  testFirefoxExtension,
  testAndroidWithoutPlugin,
  testAndroidWithPlugin,
  testConfiguredPlayStoreUrl
].forEach(test => {
  test();
  console.log(`ok - ${test.name}`);
});
