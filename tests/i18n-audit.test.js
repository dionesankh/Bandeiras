const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const ROOT = path.resolve(__dirname, "..");
const LOCALE_DIR = path.join(ROOT, "locales");
const EXPECTED_LANGUAGES = [
  "pt-BR",
  "en",
  "es",
  "fr",
  "de",
  "it",
  "nl",
  "pl",
  "ru",
  "uk",
  "tr",
  "ar",
  "hi",
  "bn",
  "zh-CN",
  "ja",
  "ko",
  "id",
  "vi",
  "th"
];
const RTL_LANGUAGES = new Set(["ar"]);
const MOJIBAKE_PATTERN = /Ã|Ð|Ø|à¤|à¦|æ—|æœ|í•|áº|à¹|ï¿½|�/;
const BAD_TEXT_PATTERN = /undefined|\[object Object\]/i;
const EXTRA_REQUIRED_KEYS = [
  "loginWithGoogle",
  "onboardingLoginTitle",
  "onboardingSkip",
  "onboardingLanguageTitle",
  "onboardingLanguageDesc",
  "onboardingNicknameDesc",
  "createProfileTitle",
  "saveNickname",
  "logout",
  "confirmLogout",
  "loginSuccess",
  "loginError",
  "nameSaved",
  "noResultsRanking",
  "challengeWaitingRankedSubmit",
  "openMenu",
  "close",
  "perfectResult",
  "greatResult",
  "nicknamePlaceholder",
  "accountDeletionTitle",
  "accountDeleteIrreversible",
  "accountDeleteDataRemoved",
  "accountDeleteRecordsRetained",
  "accountDeleteLocalProgressRemoved",
  "accountDeleteUnderstand",
  "accountDeleteConfirmWord"
];
const CRITICAL_TRANSLATION_KEYS = [
  "accountSecurityTitle",
  "accountDeleteProfileHint",
  "deleteMyAccount",
  "accountDeletionTitle",
  "accountDeleteIrreversible",
  "accountDeleteDataRemoved",
  "accountDeleteRecordsRetained",
  "accountDeleteLocalProgressRemoved",
  "accountDeleteUnderstand",
  "accountDeleteTypeWord",
  "accountDeleteConfirmWord",
  "accountDeleteConfirmPlaceholder",
  "accountDeleteReauthenticate",
  "accountDeleteChooseSameGoogle",
  "accountDeleteDeleting",
  "accountDeleted",
  "accountDeleteFailed",
  "accountDeleteSessionExpired",
  "accountDeleteConnectionUnavailable",
  "accountDeleteTryAgain",
  "accountDeleteIncorrectConfirmation",
  "accountDeleteCancelled",
  "accountDeleteTemporaryFailure",
  "accountDeleteUnexpected",
  "accountDeleteInProgress",
  "accountDeleteGoogleUnavailable",
  "accountDeleteBackendReauthRequired",
  "loginWithGoogle",
  "logout",
  "confirmLogout",
  "loginSuccess",
  "loginError",
  "rankingAuthRequired",
  "challengeWaitingRankedSubmit"
];

function read(relativePath) {
  return fs.readFileSync(path.join(ROOT, relativePath), "utf8");
}

function loadJsonLocales(dir = LOCALE_DIR) {
  const locales = {};
  for (const file of fs.readdirSync(dir).filter(name => name.endsWith(".json"))) {
    locales[path.basename(file, ".json")] = JSON.parse(
      fs.readFileSync(path.join(dir, file), "utf8")
    );
  }
  return locales;
}

function loadLocalesData(relativePath = "js/locales-data.js") {
  const sandbox = { window: {} };
  vm.createContext(sandbox);
  vm.runInContext(read(relativePath), sandbox, {
    filename: relativePath
  });
  return sandbox.window.FlagGameLocales;
}

function extractUsedKeys() {
  const html = read("game/index.html");
  const keys = new Set();
  for (const match of html.matchAll(/data-i18n(?:-[a-z-]+)?="([^"]+)"/g)) {
    keys.add(match[1]);
  }

  const jsFiles = [
    "js/app.js",
    "js/auth.js",
    "js/rankings-api.js",
    "js/challenges.js",
    "js/player-challenges.js",
    "js/world-challenge.js",
    "js/play-games-competitive.js"
  ];
  const patterns = [
    /\bt\(\s*["']([^"']+)["']/g,
    /\btFallback\(\s*["']([^"']+)["']/g,
    /\btPlural\(\s*["']([^"']+)["']/g
  ];

  for (const file of jsFiles) {
    if (!fs.existsSync(path.join(ROOT, file))) continue;
    const source = read(file);
    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(source))) {
        keys.add(match[1]);
      }
    }
  }

  EXTRA_REQUIRED_KEYS.forEach(key => keys.add(key));
  return [...keys].sort();
}

function placeholders(value) {
  const names = [];
  String(value).replace(/\{([a-zA-Z0-9_]+)\}/g, (_, name) => {
    names.push(name);
    return "";
  });
  return names.sort();
}

function assertNoBadText(file, content) {
  assert.equal(MOJIBAKE_PATTERN.test(content), false, `${file} contains mojibake markers`);
  assert.equal(BAD_TEXT_PATTERN.test(content), false, `${file} contains invalid visible text`);
}

function assertNoMojibake(file, content) {
  assert.equal(MOJIBAKE_PATTERN.test(content), false, `${file} contains mojibake markers`);
}

function testLocaleFilesAreValidAndComplete() {
  const locales = loadJsonLocales();
  assert.deepEqual(Object.keys(locales).sort(), [...EXPECTED_LANGUAGES].sort());

  const usedKeys = extractUsedKeys();
  const base = locales.en;
  const baseKeys = new Set(Object.keys(base));

  for (const lang of EXPECTED_LANGUAGES) {
    const locale = locales[lang];
    assert(locale, `${lang} locale is missing`);

    const missingUsed = usedKeys.filter(key => !(key in locale));
    assert.deepEqual(missingUsed, [], `${lang} is missing used keys`);

    for (const [key, value] of Object.entries(locale)) {
      assert.notEqual(value, null, `${lang}.${key} is null`);
      assert.notEqual(String(value).trim(), "", `${lang}.${key} is empty`);
      assertNoBadText(`${lang}.${key}`, String(value));
      if (/[A-Z_]/.test(key) || key.startsWith("accountDelete")) {
        assert.notEqual(String(value), key, `${lang}.${key} displays the technical key`);
      }
    }

    for (const key of Object.keys(locale)) {
      if (!baseKeys.has(key)) continue;
      assert.deepEqual(
        placeholders(locale[key]),
        placeholders(base[key]),
        `${lang}.${key} placeholder mismatch`
      );
    }
  }
}

function testLocalesDataMatchesJsonFiles() {
  const jsonLocales = loadJsonLocales();
  const bundledLocales = loadLocalesData();
  assert.deepEqual(Object.keys(bundledLocales).sort(), [...EXPECTED_LANGUAGES].sort());

  for (const lang of EXPECTED_LANGUAGES) {
    for (const key of extractUsedKeys()) {
      assert.equal(
        bundledLocales[lang][key],
        jsonLocales[lang][key],
        `js/locales-data.js diverges from locales/${lang}.json at ${key}`
      );
    }
  }
}

function testI18nRuntimeConfiguration() {
  const source = read("js/i18n.js");
  assertNoMojibake("js/i18n.js", source);
  assert(source.includes('language === "ar" ? "rtl" : "ltr"'), "Arabic RTL handling is missing");

  const labelChecks = [
    "Português",
    "Español",
    "Français",
    "Русский",
    "Українська",
    "Türkçe",
    "العربية",
    "हिन्दी",
    "বাংলা",
    "中文",
    "日本語",
    "한국어",
    "Tiếng Việt",
    "ไทย"
  ];
  for (const label of labelChecks) {
    assert(source.includes(label), `Language label missing or corrupted: ${label}`);
  }
}

function testConfirmationWords() {
  const locales = loadJsonLocales();
  for (const lang of EXPECTED_LANGUAGES) {
    const word = String(locales[lang].accountDeleteConfirmWord || "");
    assert.equal(word.trim().length > 0, true, `${lang} confirmation word is empty`);
    assert.equal(word, word.trim(), `${lang} confirmation word has external spaces`);
    if (lang !== "en") {
      assert.notEqual(word, "DELETE", `${lang} confirmation word must be localized`);
    }
  }

  const appSource = read("js/app.js");
  assert(appSource.includes('tFallback("accountDeleteConfirmWord"'), "confirmation word must come from i18n");
  assert(appSource.includes(".toLocaleUpperCase()"), "confirmation comparison must normalize case");
}

function testCriticalTranslationsAreLocalized() {
  const locales = loadJsonLocales();
  const base = locales.en;

  for (const lang of EXPECTED_LANGUAGES.filter(item => item !== "en")) {
    for (const key of CRITICAL_TRANSLATION_KEYS) {
      assert(key in locales[lang], `${lang}.${key} is missing`);
      assert.notEqual(
        locales[lang][key],
        base[key],
        `${lang}.${key} must not fall back to English`
      );
    }
  }
}

function testPortugueseVaticanOverride() {
  const source = read("js/i18n.js");
  assert(source.includes('code === "VA" && currentLanguage === "pt-BR"'));
  assert(source.includes('return "Vaticano"'));
}

function testVisibleHardcodedTextIsCovered() {
  const html = read("game/index.html");
  assert(html.includes('id="btn-onboarding-login" data-i18n="loginWithGoogle"'));
  assert(html.includes('id="btn-menu" class="menu-trigger" aria-label="Abrir menu" data-i18n-aria-label="openMenu"'));
  assert(html.includes('id="bandeira-atual" src="" alt="Bandeira" data-i18n-alt="flagImageAlt"'));

  const appSource = read("js/app.js");
  assert(!appSource.includes('textContent = pct === 100 ? "Perfeito!" : "Muito Bem!"'));
  assert(appSource.includes('tFallback("perfectResult"'));
  assert(appSource.includes('tFallback("greatResult"'));
}

function testAndroidDistContainsUpdatedLocalesWhenPresent() {
  const distDir = path.join(ROOT, "dist", "android");
  if (!fs.existsSync(distDir)) return;

  const distLocales = loadJsonLocales(path.join(distDir, "locales"));
  assert.deepEqual(Object.keys(distLocales).sort(), [...EXPECTED_LANGUAGES].sort());

  const distIndex = fs.readFileSync(path.join(distDir, "index.html"), "utf8");
  assert(distIndex.includes('data-i18n="deleteMyAccount"'));
  assert(distIndex.includes('data-i18n-aria-label="openMenu"'));
}

testLocaleFilesAreValidAndComplete();
testLocalesDataMatchesJsonFiles();
testI18nRuntimeConfiguration();
testConfirmationWords();
testCriticalTranslationsAreLocalized();
testPortugueseVaticanOverride();
testVisibleHardcodedTextIsCovered();
testAndroidDistContainsUpdatedLocalesWhenPresent();

console.log("i18n audit tests passed");
