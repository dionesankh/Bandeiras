const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "dist", "android");
const GAME_ENTRY = path.join(ROOT, "game", "index.html");
const STAGING_CONFIG_ENTRY = path.join(ROOT, "js", "supabase-staging.local.js");
const STAGING_GENERATED_FILE = "supabase-staging.generated.js";
const STAGING_HOST = "uzydndoaxpvdxiuiaunz.supabase.co";
const PRODUCTION_URL = "https://kyupoytmphmdbwuvigcu.supabase.co";
const PRODUCTION_GOOGLE_CLIENT_ID = "848159149097-v6gjl2vsaq2meevmtq0lqk6b183r402u.apps.googleusercontent.com";
const REQUIRED_DIRS = ["assets/flags", "assets/images", "css", "js", "locales"];
const FORBIDDEN_TERMS = [
  /pix/i,
  /ko-fi/i,
  /doa[cç][aã]o/i,
  /donation/i,
  /google play billing/i,
  /purchase/i
];
const TEXT_EXTENSIONS = new Set([
  ".css",
  ".html",
  ".js",
  ".json",
  ".svg",
  ".txt",
  ".xml"
]);

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function ensureCleanDir(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
}

function normalizeBuildEnvironment(value) {
  const environment = String(value || "production").trim().toLowerCase();

  if (!environment || environment === "production") return "production";
  if (environment === "staging") return "staging";

  throw new Error(`Unsupported FLAG_GAME_ENV value: ${value}`);
}

function isPlaceholder(value) {
  const text = String(value || "").trim();
  return !text ||
    /COLE_AQUI|PLACEHOLDER|YOUR_|<.*>|PUBLISHABLE_KEY|WEB_CLIENT_ID/i.test(text);
}

function validateStagingConfig(config) {
  if (!config || config.environment !== "staging") {
    throw new Error("Staging config must set environment to \"staging\".");
  }

  if (config.serviceRoleKey || config.clientSecret || config.googleClientSecret) {
    throw new Error("Secret fields are not allowed in frontend staging config.");
  }

  const url = String(config.url || "").trim();
  const anonKey = String(config.anonKey || "").trim();
  const googleWebClientId = String(config.googleWebClientId || "").trim();

  if (isPlaceholder(anonKey)) {
    throw new Error("Staging Supabase publishable key is missing or still a placeholder.");
  }

  if (isPlaceholder(googleWebClientId)) {
    throw new Error("Staging Google Web Client ID is missing or still a placeholder.");
  }

  const parsedUrl = new URL(url);
  if (parsedUrl.hostname !== STAGING_HOST) {
    throw new Error(`Staging Supabase hostname must be exactly ${STAGING_HOST}.`);
  }

  if (url === PRODUCTION_URL) {
    throw new Error("Staging config must not use the production Supabase URL.");
  }

  if (!googleWebClientId.endsWith(".apps.googleusercontent.com")) {
    throw new Error("Staging Google Web Client ID must end with .apps.googleusercontent.com.");
  }

  if (googleWebClientId === PRODUCTION_GOOGLE_CLIENT_ID) {
    throw new Error("Staging config must not use the production Google Web Client ID.");
  }

  return {
    environment: "staging",
    url,
    anonKey,
    googleWebClientId
  };
}

function readLocalStagingConfig(filePath = STAGING_CONFIG_ENTRY) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`FLAG_GAME_ENV=staging requires ${filePath}.`);
  }

  const sandbox = {
    window: {},
    console: { info() {}, warn() {}, error() {} }
  };
  sandbox.globalThis = sandbox.window;

  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(filePath, "utf8"), sandbox, {
    filename: filePath
  });

  return validateStagingConfig(sandbox.window.FlagGameSupabaseStagingConfig);
}

function resolveBuildConfig(options = {}) {
  const environment = normalizeBuildEnvironment(
    Object.prototype.hasOwnProperty.call(options, "env")
      ? options.env
      : process.env.FLAG_GAME_ENV
  );

  if (environment === "production") {
    return { environment, stagingConfig: null };
  }

  return {
    environment,
    stagingConfig: readLocalStagingConfig(options.stagingConfigPath)
  };
}

function shouldSkipCopiedFile(source) {
  const normalized = path.resolve(source);
  return normalized === path.resolve(STAGING_CONFIG_ENTRY) ||
    path.basename(source) === STAGING_GENERATED_FILE;
}

function copyDir(source, destination) {
  if (shouldSkipCopiedFile(source)) {
    return;
  }

  const stats = fs.statSync(source);

  if (stats.isDirectory()) {
    fs.mkdirSync(destination, { recursive: true });

    for (const entry of fs.readdirSync(source)) {
      copyDir(path.join(source, entry), path.join(destination, entry));
    }

    return;
  }

  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
}

function listFiles(dir) {
  const files = [];

  function walk(current) {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const fullPath = path.join(current, entry.name);

      if (entry.isDirectory()) {
        walk(fullPath);
      } else {
        files.push(fullPath);
      }
    }
  }

  walk(dir);
  return files;
}

function prepareAndroidEntryHtml(html, buildConfig) {
  let prepared = html;

  prepared = prepared.replace(
    /<base\s+href=["']\.\.\/["']\s*>/i,
    '<base href="./">'
  );

  assert(
    /<base\s+href=["']\.\/["']\s*>/i.test(prepared),
    "Android index.html must use a local base href."
  );

  if (buildConfig.environment === "staging") {
    const before = prepared;
    prepared = prepared.replace(
      '<script src="js/supabase-client.js"></script>',
      `<script src="js/${STAGING_GENERATED_FILE}"></script>\n  <script src="js/supabase-client.js"></script>`
    );
    assert(
      before !== prepared,
      "Android index.html must load js/supabase-client.js so staging config can be injected explicitly."
    );
  }

  return prepared;
}

function writeAndroidEntry(buildConfig) {
  fs.writeFileSync(
    path.join(OUT_DIR, "index.html"),
    prepareAndroidEntryHtml(fs.readFileSync(GAME_ENTRY, "utf8"), buildConfig)
  );
}

function stagingGeneratedSource(config) {
  return `// Generated by scripts/build-android.js for local staging validation.\n` +
    `// This file contains public staging config only. Do not commit generated assets.\n` +
    `window.FlagGameEnvironment = "staging";\n` +
    `window.FlagGameSupabaseStagingConfig = ${JSON.stringify(config, null, 2)};\n`;
}

function writeStagingGeneratedConfig(buildConfig) {
  if (buildConfig.environment !== "staging") return;

  const dest = path.join(OUT_DIR, "js", STAGING_GENERATED_FILE);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, stagingGeneratedSource(buildConfig.stagingConfig));
}

function validateEntryPoint() {
  const indexPath = path.join(OUT_DIR, "index.html");

  assert(fs.existsSync(indexPath), "Android webDir is missing index.html.");
  assert(
    !fs.existsSync(path.join(OUT_DIR, "homepage")),
    "Android webDir must not contain homepage/."
  );
  assert(
    !fs.existsSync(path.join(OUT_DIR, "game", "index.html")),
    "Android webDir must not contain a second game entry."
  );
  assert(
    !fs.existsSync(path.join(OUT_DIR, "manifest.json")),
    "Android webDir must not contain the browser extension manifest."
  );
}

function validateLocales() {
  const localeDir = path.join(OUT_DIR, "locales");
  const localeFiles = fs.readdirSync(localeDir).filter(name => name.endsWith(".json"));

  assert(localeFiles.length === 20, `Expected 20 locale files, found ${localeFiles.length}.`);

  for (const file of localeFiles) {
    JSON.parse(fs.readFileSync(path.join(localeDir, file), "utf8"));
  }
}

function validateForbiddenContent() {
  const matches = [];

  for (const file of listFiles(OUT_DIR)) {
    const relative = path.relative(OUT_DIR, file).replace(/\\/g, "/");

    for (const term of FORBIDDEN_TERMS) {
      if (term.test(relative)) {
        matches.push(relative);
        break;
      }
    }

    if (!TEXT_EXTENSIONS.has(path.extname(file).toLowerCase())) {
      continue;
    }

    const content = fs.readFileSync(file, "utf8");

    for (const term of FORBIDDEN_TERMS) {
      if (term.test(content)) {
        matches.push(relative);
        break;
      }
    }
  }

  assert(
    matches.length === 0,
    `Forbidden Android package references found: ${matches.join(", ")}`
  );
}

function copySupabaseBundle() {
  const src = path.join(ROOT, "node_modules", "@supabase", "supabase-js", "dist", "umd", "supabase.js");
  const dest = path.join(OUT_DIR, "js", "libs", "supabase.js");

  if (!fs.existsSync(src)) {
    throw new Error(`Supabase UMD bundle not found at ${src}. Run 'npm install' first.`);
  }

  console.log(`Copying real Supabase bundle to ${dest}`);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
}

function main(options = {}) {
  const buildConfig = resolveBuildConfig(options);

  ensureCleanDir(OUT_DIR);
  writeAndroidEntry(buildConfig);

  for (const dir of REQUIRED_DIRS) {
    copyDir(path.join(ROOT, dir), path.join(OUT_DIR, dir));
  }

  writeStagingGeneratedConfig(buildConfig);
  copySupabaseBundle();

  validateEntryPoint();
  validateLocales();
  validateForbiddenContent();

  console.log(`Built Flag Game Android web assets in dist/android (${buildConfig.environment})`);
}

if (require.main === module) {
  main();
}

module.exports = {
  PRODUCTION_GOOGLE_CLIENT_ID,
  PRODUCTION_URL,
  STAGING_HOST,
  normalizeBuildEnvironment,
  prepareAndroidEntryHtml,
  readLocalStagingConfig,
  resolveBuildConfig,
  stagingGeneratedSource,
  validateStagingConfig
};
