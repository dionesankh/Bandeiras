const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");

const {
  PRODUCTION_GOOGLE_CLIENT_ID,
  PRODUCTION_URL,
  STAGING_HOST,
  prepareAndroidEntryHtml,
  resolveBuildConfig,
  stagingGeneratedSource
} = require("../scripts/build-android.js");

const STAGING_URL = `https://${STAGING_HOST}`;
const STAGING_KEY = "sb_publishable_staging_test_key";
const STAGING_GOOGLE_CLIENT_ID = "123456789012-staging-test.apps.googleusercontent.com";
const SUPABASE_CLIENT_MODULE = path.join("..", "js", "supabase-client.js");

const ANDROID_ENTRY_HTML = [
  "<!doctype html>",
  "<html>",
  "<head>",
  '  <base href="../">',
  "</head>",
  "<body>",
  '  <script src="js/supabase-client.js"></script>',
  "</body>",
  "</html>"
].join("\n");

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "flag-game-build-env-"));
}

function stagingConfig(overrides = {}) {
  return {
    environment: "staging",
    url: STAGING_URL,
    anonKey: STAGING_KEY,
    googleWebClientId: STAGING_GOOGLE_CLIENT_ID,
    ...overrides
  };
}

function writeLocalStagingConfig(config) {
  const filePath = path.join(makeTempDir(), "supabase-staging.local.js");
  fs.writeFileSync(
    filePath,
    `window.FlagGameSupabaseStagingConfig = ${JSON.stringify(config, null, 2)};\n`
  );
  return filePath;
}

function assertProductionBuild(config, html) {
  assert.equal(config.environment, "production");
  assert.equal(config.stagingConfig, null);
  assert(!html.includes("supabase-staging.generated.js"));
  assert(!html.includes(STAGING_GOOGLE_CLIENT_ID));
}

function loadSupabaseClientConfig(rootProps = {}) {
  const previousEnvironment = globalThis.FlagGameEnvironment;
  const previousStagingConfig = globalThis.FlagGameSupabaseStagingConfig;
  const previousSupabase = globalThis.supabase;
  const previousConsoleInfo = console.info;
  const logs = [];

  if (Object.prototype.hasOwnProperty.call(rootProps, "FlagGameEnvironment")) {
    globalThis.FlagGameEnvironment = rootProps.FlagGameEnvironment;
  } else {
    delete globalThis.FlagGameEnvironment;
  }

  if (Object.prototype.hasOwnProperty.call(rootProps, "FlagGameSupabaseStagingConfig")) {
    globalThis.FlagGameSupabaseStagingConfig = rootProps.FlagGameSupabaseStagingConfig;
  } else {
    delete globalThis.FlagGameSupabaseStagingConfig;
  }

  globalThis.supabase = {
    createClient() {
      throw new Error("Supabase client should not be created while reading config.");
    }
  };
  console.info = (...args) => logs.push(args);

  delete require.cache[require.resolve(SUPABASE_CLIENT_MODULE)];

  try {
    return {
      config: require(SUPABASE_CLIENT_MODULE).config,
      logs
    };
  } finally {
    delete require.cache[require.resolve(SUPABASE_CLIENT_MODULE)];
    console.info = previousConsoleInfo;

    if (typeof previousEnvironment === "undefined") {
      delete globalThis.FlagGameEnvironment;
    } else {
      globalThis.FlagGameEnvironment = previousEnvironment;
    }

    if (typeof previousStagingConfig === "undefined") {
      delete globalThis.FlagGameSupabaseStagingConfig;
    } else {
      globalThis.FlagGameSupabaseStagingConfig = previousStagingConfig;
    }

    if (typeof previousSupabase === "undefined") {
      delete globalThis.supabase;
    } else {
      globalThis.supabase = previousSupabase;
    }
  }
}

(function absentStagingFileNormalBuildUsesProduction() {
  const config = resolveBuildConfig({
    env: undefined,
    stagingConfigPath: path.join(makeTempDir(), "missing.js")
  });
  const html = prepareAndroidEntryHtml(ANDROID_ENTRY_HTML, config);

  assertProductionBuild(config, html);
})();

(function presentStagingFileNormalBuildStillUsesProduction() {
  const stagingConfigPath = writeLocalStagingConfig(stagingConfig());
  const config = resolveBuildConfig({
    env: "production",
    stagingConfigPath
  });
  const html = prepareAndroidEntryHtml(ANDROID_ENTRY_HTML, config);

  assertProductionBuild(config, html);
})();

(function webRuntimeIgnoresStagingConfigWithoutExplicitMarker() {
  const result = loadSupabaseClientConfig({
    FlagGameSupabaseStagingConfig: stagingConfig()
  });

  assert.equal(result.config.environment, "production");
  assert.equal(result.config.url, PRODUCTION_URL);
  assert.equal(result.config.googleWebClientId, PRODUCTION_GOOGLE_CLIENT_ID);
  assert.equal(result.logs.length, 0);
})();

(function explicitStagingBuildUsesStaging() {
  const stagingConfigPath = writeLocalStagingConfig(stagingConfig());
  const config = resolveBuildConfig({
    env: "staging",
    stagingConfigPath
  });
  const html = prepareAndroidEntryHtml(ANDROID_ENTRY_HTML, config);
  const generated = stagingGeneratedSource(config.stagingConfig);

  assert.equal(config.environment, "staging");
  assert.equal(config.stagingConfig.url, STAGING_URL);
  assert.equal(config.stagingConfig.googleWebClientId, STAGING_GOOGLE_CLIENT_ID);
  assert(html.includes("supabase-staging.generated.js"));
  assert(generated.includes('window.FlagGameEnvironment = "staging";'));
  assert(generated.includes(STAGING_URL));
  assert(generated.includes(STAGING_GOOGLE_CLIENT_ID));
})();

(function webRuntimeUsesStagingOnlyWithExplicitMarker() {
  const result = loadSupabaseClientConfig({
    FlagGameEnvironment: "staging",
    FlagGameSupabaseStagingConfig: stagingConfig()
  });
  const serializedLogs = JSON.stringify(result.logs);

  assert.equal(result.config.environment, "staging");
  assert.equal(result.config.url, STAGING_URL);
  assert.equal(result.config.googleWebClientId, STAGING_GOOGLE_CLIENT_ID);
  assert(serializedLogs.includes("ENVIRONMENT: STAGING"));
  assert(!serializedLogs.includes(STAGING_KEY));
})();

(function explicitStagingBuildFailsWithoutLocalConfig() {
  assert.throws(
    () => resolveBuildConfig({
      env: "staging",
      stagingConfigPath: path.join(makeTempDir(), "missing.js")
    }),
    /FLAG_GAME_ENV=staging requires/
  );
})();

(function explicitStagingBuildFailsWithPlaceholder() {
  const stagingConfigPath = writeLocalStagingConfig(stagingConfig({
    anonKey: "COLE_AQUI_A_PUBLISHABLE_KEY_DO_SUPABASE_STAGING"
  }));

  assert.throws(
    () => resolveBuildConfig({ env: "staging", stagingConfigPath }),
    /publishable key is missing or still a placeholder/
  );
})();

(function explicitStagingBuildFailsWithWrongHostname() {
  const stagingConfigPath = writeLocalStagingConfig(stagingConfig({
    url: "https://wrong-project.supabase.co"
  }));

  assert.throws(
    () => resolveBuildConfig({ env: "staging", stagingConfigPath }),
    new RegExp(`hostname must be exactly ${STAGING_HOST.replace(/\./g, "\\.")}`)
  );
})();

(function productionNeverReceivesStagingGoogleClientId() {
  const stagingConfigPath = writeLocalStagingConfig(stagingConfig());
  const config = resolveBuildConfig({
    env: "production",
    stagingConfigPath
  });
  const html = prepareAndroidEntryHtml(ANDROID_ENTRY_HTML, config);
  const serializedConfig = JSON.stringify(config);

  assert(!html.includes(STAGING_GOOGLE_CLIENT_ID));
  assert(!serializedConfig.includes(STAGING_GOOGLE_CLIENT_ID));
  assert.equal(PRODUCTION_GOOGLE_CLIENT_ID.endsWith(".apps.googleusercontent.com"), true);
})();

(function stagingNeverReceivesProductionSupabaseUrl() {
  const stagingConfigPath = writeLocalStagingConfig(stagingConfig());
  const config = resolveBuildConfig({
    env: "staging",
    stagingConfigPath
  });
  const generated = stagingGeneratedSource(config.stagingConfig);

  assert(!generated.includes(PRODUCTION_URL));
  assert.notEqual(config.stagingConfig.url, PRODUCTION_URL);
})();

console.log("build-android env tests passed");
