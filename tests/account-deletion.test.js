const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { webcrypto } = require("node:crypto");

const source = fs.readFileSync(
  path.join(__dirname, "..", "js", "auth.js"),
  "utf8"
);

function createLocalStorage(initial = {}) {
  const store = { ...initial };

  return {
    store,
    get length() {
      return Object.keys(store).length;
    },
    key(index) {
      return Object.keys(store)[index] || null;
    },
    getItem(key) {
      return Object.prototype.hasOwnProperty.call(store, key) ? store[key] : null;
    },
    setItem(key, value) {
      store[key] = String(value);
    },
    removeItem(key) {
      delete store[key];
    }
  };
}

function createStorage(localStorage) {
  return {
    remove(key) {
      localStorage.removeItem(key);
      return true;
    }
  };
}

function loadAuth(contextValues = {}) {
  const context = {
    console,
    setTimeout: (fn, ms, ...args) => {
      const timer = setTimeout(fn, ms, ...args);
      if (timer.unref) timer.unref();
      return timer;
    },
    clearTimeout,
    crypto: webcrypto,
    TextEncoder,
    navigator: { onLine: true },
    ...contextValues
  };

  context.globalThis = context;

  vm.runInNewContext(source, context, {
    filename: "auth.js"
  });

  return context.FlagGameAuth;
}

function createSupabaseMock({ originalUserId = "user-a", reauthUserId = "user-a", invokeResult } = {}) {
  let currentSession = {
    access_token: "old-access",
    refresh_token: "old-refresh",
    user: { id: originalUserId, email: "player@example.com", user_metadata: {} }
  };
  const calls = {
    signInWithIdToken: [],
    setSession: [],
    invoke: [],
    signOut: 0
  };

  const client = {
    auth: {
      getSession: async () => ({ data: { session: currentSession }, error: null }),
      signInWithIdToken: async (params) => {
        calls.signInWithIdToken.push(params);
        currentSession = {
          access_token: "fresh-access",
          refresh_token: "fresh-refresh",
          user: { id: reauthUserId, email: "player@example.com", user_metadata: {} }
        };
        return { data: { session: currentSession }, error: null };
      },
      setSession: async (session) => {
        calls.setSession.push(session);
        currentSession = {
          access_token: session.access_token,
          refresh_token: session.refresh_token,
          user: { id: originalUserId, email: "player@example.com", user_metadata: {} }
        };
        return { data: { session: currentSession }, error: null };
      },
      signOut: async () => {
        calls.signOut += 1;
        currentSession = null;
        return { error: null };
      }
    },
    functions: {
      invoke: async (name, options) => {
        calls.invoke.push({ name, options });
        return typeof invokeResult === "function"
          ? invokeResult(name, options)
          : invokeResult;
      }
    }
  };

  return { client, calls };
}

function createContext({ supabaseMock, localStorage }) {
  return {
    localStorage,
    FlagGameStorage: createStorage(localStorage),
    FlagGameSupabase: {
      client: supabaseMock.client,
      config: { googleWebClientId: "web-client-id" }
    },
    Capacitor: {
      Plugins: {
        FlagGameGoogleAuth: {
          signInWithGoogle: async ({ serverClientId, nonce }) => ({
            idToken: `id-token:${serverClientId}:${nonce.slice(0, 8)}`
          })
        }
      }
    }
  };
}

async function assertRejectsWithCode(promise, code) {
  await assert.rejects(
    promise,
    error => error && error.name === "AccountDeletionError" && error.code === code
  );
}

async function testSuccessfulDeletionClearsOnlyAccountData() {
  const localStorage = createLocalStorage({
    language: "pt-BR",
    sound: "on",
    onboarding_v1: "done",
    flagGameProfile: "{}",
    flagGameRankingPlayer: "{}",
    flagGameCloudSaveState: "{}",
    flagGameWorldChallengeCheckpoint: "{}",
    "sb-abc123-auth-token": "supabase-session"
  });
  const supabaseMock = createSupabaseMock({
    invokeResult: { data: { ok: true, code: "account_deleted" }, error: null }
  });
  const auth = loadAuth(createContext({ supabaseMock, localStorage }));

  const result = await auth.deleteAccount();

  assert.equal(result.ok, true);
  assert.equal(result.code, "account_deleted");
  assert.equal(supabaseMock.calls.invoke.length, 1);
  assert.equal(supabaseMock.calls.invoke[0].name, "delete-account");
  assert.equal(supabaseMock.calls.invoke[0].options, undefined);
  assert.equal(localStorage.getItem("flagGameProfile"), null);
  assert.equal(localStorage.getItem("flagGameRankingPlayer"), null);
  assert.equal(localStorage.getItem("flagGameCloudSaveState"), null);
  assert.equal(localStorage.getItem("flagGameWorldChallengeCheckpoint"), null);
  assert.equal(localStorage.getItem("sb-abc123-auth-token"), null);
  assert.equal(localStorage.getItem("language"), "pt-BR");
  assert.equal(localStorage.getItem("sound"), "on");
  assert.equal(localStorage.getItem("onboarding_v1"), "done");
}

async function testGoogleAccountMismatchDoesNotInvokeOrClear() {
  const localStorage = createLocalStorage({
    language: "pt-BR",
    flagGameProfile: "{}"
  });
  const supabaseMock = createSupabaseMock({
    reauthUserId: "other-user",
    invokeResult: { data: { ok: true, code: "account_deleted" }, error: null }
  });
  const auth = loadAuth(createContext({ supabaseMock, localStorage }));

  await assertRejectsWithCode(auth.deleteAccount(), "google_account_mismatch");

  assert.equal(supabaseMock.calls.invoke.length, 0);
  assert.equal(supabaseMock.calls.setSession.length, 1);
  assert.equal(localStorage.getItem("flagGameProfile"), "{}");
  assert.equal(localStorage.getItem("language"), "pt-BR");
}

async function testDuplicateDeletionIsBlocked() {
  let resolveInvoke;
  const invokeResult = new Promise(resolve => {
    resolveInvoke = resolve;
  });
  const localStorage = createLocalStorage({ flagGameProfile: "{}" });
  const supabaseMock = createSupabaseMock({
    invokeResult: () => invokeResult
  });
  const auth = loadAuth(createContext({ supabaseMock, localStorage }));

  const first = auth.deleteAccount();
  await assertRejectsWithCode(auth.deleteAccount(), "account_deletion_in_progress");

  resolveInvoke({ data: { ok: true, code: "account_deleted" }, error: null });
  const result = await first;
  assert.equal(result.ok, true);
  assert.equal(supabaseMock.calls.invoke.length, 1);
}

async function testFunctionErrorDoesNotClearLocalData() {
  const localStorage = createLocalStorage({
    language: "pt-BR",
    flagGameProfile: "{}"
  });
  const functionError = {
    context: {
      clone: () => ({
        json: async () => ({ code: "reauthentication_required" })
      })
    }
  };
  const supabaseMock = createSupabaseMock({
    invokeResult: { data: null, error: functionError }
  });
  const auth = loadAuth(createContext({ supabaseMock, localStorage }));

  await assertRejectsWithCode(auth.deleteAccount(), "reauthentication_required");

  assert.equal(supabaseMock.calls.invoke.length, 1);
  assert.equal(localStorage.getItem("flagGameProfile"), "{}");
  assert.equal(localStorage.getItem("language"), "pt-BR");
}

async function run() {
  await testSuccessfulDeletionClearsOnlyAccountData();
  await testGoogleAccountMismatchDoesNotInvokeOrClear();
  await testDuplicateDeletionIsBlocked();
  await testFunctionErrorDoesNotClearLocalData();
  console.log("account-deletion tests passed");
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
