const FlagGameAuth = (() => {
  const AUTH_KEY = "flagGameAuthState";
  const SCHEMA_VERSION = 1;

  let adapter = createAdapter();
  let initialized = false;
  let initPromise = null;
  let status = {
    provider: "offline",
    state: "idle",
    authenticated: false,
    playerId: "",
    uid: "",
    isAnonymous: true,
    lastAuthAt: "",
    lastError: ""
  };

  function now() {
    return new Date().toISOString();
  }

  function getPlayer() {
    if (typeof FlagGameRanking === "undefined") {
      return {
        playerId: "",
        nickname: "",
        country: ""
      };
    }

    return FlagGameRanking.getPlayer();
  }

  function readState() {
    return FlagGameStorage.getJson(AUTH_KEY, null);
  }

  function normalizeState(state) {
    const timestamp = now();

    return {
      schemaVersion: SCHEMA_VERSION,
      playerId: "",
      firebaseUid: "",
      isAnonymous: true,
      providerIds: [],
      createdAt: timestamp,
      updatedAt: timestamp,
      lastAuthAt: "",
      lastError: "",
      ...(state || {})
    };
  }

  function saveState(nextState) {
    const previousState = normalizeState(readState());
    const normalizedState = normalizeState({
      ...previousState,
      ...nextState,
      schemaVersion: SCHEMA_VERSION,
      updatedAt: now()
    });

    FlagGameStorage.setJson(AUTH_KEY, normalizedState);

    status = {
      ...status,
      authenticated: Boolean(normalizedState.firebaseUid),
      playerId: normalizedState.playerId,
      uid: normalizedState.firebaseUid,
      isAnonymous: normalizedState.isAnonymous,
      lastAuthAt: normalizedState.lastAuthAt || status.lastAuthAt,
      lastError: normalizedState.lastError || ""
    };

    return normalizedState;
  }

  function getFirebaseConfig() {
    return window.FlagGameFirebaseConfig || null;
  }

  function hasFirebaseCompat() {
    return (
      typeof firebase !== "undefined" &&
      firebase &&
      typeof firebase.initializeApp === "function" &&
      typeof firebase.auth === "function"
    );
  }

  function getFirebaseApp(config) {
    if (!firebase.apps || !firebase.apps.length) {
      return firebase.initializeApp(config);
    }

    return firebase.app();
  }

  function mapUser(user) {
    if (!user) {
      return null;
    }

    return {
      uid: user.uid,
      isAnonymous: Boolean(user.isAnonymous),
      providerIds: user.providerData
        ? user.providerData
          .map(provider => provider.providerId)
          .filter(Boolean)
        : []
    };
  }

  function createOfflineAuthAdapter(reason) {
    return {
      name: "offline",
      reason: reason || "firebase-unavailable",
      async signInAnonymously(player) {
        return {
          ok: false,
          status: "offline",
          reason: this.reason,
          player
        };
      },
      async getCurrentUser() {
        return null;
      },
      async linkWithCredential() {
        return {
          ok: false,
          status: "offline",
          reason: this.reason
        };
      }
    };
  }

  function createFirebaseCompatAuthAdapter(config) {
    const app = getFirebaseApp(config);
    const auth = app.auth();

    return {
      name: "firebase",
      async signInAnonymously() {
        const currentUser = auth.currentUser;
        const credential = currentUser
          ? { user: currentUser }
          : await auth.signInAnonymously();

        return {
          ok: true,
          status: "authenticated",
          user: mapUser(credential.user)
        };
      },
      async getCurrentUser() {
        return mapUser(auth.currentUser);
      },
      async linkWithCredential(credential) {
        if (!auth.currentUser || !credential) {
          return {
            ok: false,
            status: "missing-current-user"
          };
        }

        const linkedUser =
          await auth.currentUser.linkWithCredential(credential);

        return {
          ok: true,
          status: "linked",
          user: mapUser(linkedUser.user)
        };
      }
    };
  }

  function createAdapter() {
    const config = getFirebaseConfig();

    if (!config) {
      return createOfflineAuthAdapter("missing-config");
    }

    if (!hasFirebaseCompat()) {
      return createOfflineAuthAdapter("missing-firebase-sdk");
    }

    try {
      return createFirebaseCompatAuthAdapter(config);

    } catch (error) {
      console.warn("Firebase Auth unavailable:", error);
      return createOfflineAuthAdapter("firebase-init-failed");
    }
  }

  function getStatus() {
    return { ...status };
  }

  function getState() {
    return normalizeState(readState());
  }

  function setAdapter(nextAdapter) {
    adapter = nextAdapter || createOfflineAuthAdapter();
    status = {
      ...status,
      provider: adapter.name || "custom"
    };
  }

  function getAdapter() {
    return adapter;
  }

  async function signInAnonymously() {
    const player = getPlayer();

    status = {
      ...status,
      provider: adapter.name || "custom",
      state: "authenticating",
      playerId: player.playerId,
      lastError: ""
    };

    try {
      const result = await adapter.signInAnonymously(player);

      if (!result || !result.ok || !result.user) {
        saveState({
          playerId: player.playerId,
          lastError: result && result.reason
            ? result.reason
            : ""
        });

        status = {
          ...status,
          state: "offline",
          authenticated: false,
          provider: adapter.name || "offline"
        };

        return {
          ok: false,
          status: "offline",
          player,
          result
        };
      }

      const authState = saveState({
        playerId: player.playerId,
        firebaseUid: result.user.uid,
        isAnonymous: result.user.isAnonymous,
        providerIds: result.user.providerIds,
        lastAuthAt: now(),
        lastError: ""
      });

      status = {
        ...status,
        state: "authenticated",
        authenticated: true,
        provider: adapter.name || "firebase",
        uid: result.user.uid,
        isAnonymous: result.user.isAnonymous,
        lastAuthAt: authState.lastAuthAt,
        lastError: ""
      };

      return {
        ok: true,
        status: "authenticated",
        player,
        authState
      };

    } catch (error) {
      const message = error && error.message
        ? error.message
        : String(error);

      saveState({
        playerId: player.playerId,
        lastError: message
      });

      status = {
        ...status,
        state: "offline",
        authenticated: false,
        lastError: message
      };

      return {
        ok: false,
        status: "offline",
        player,
        error
      };
    }
  }

  async function linkWithCredential(credential) {
    try {
      const result = await adapter.linkWithCredential(credential);

      if (!result || !result.ok || !result.user) {
        return result;
      }

      const player = getPlayer();
      const authState = saveState({
        playerId: player.playerId,
        firebaseUid: result.user.uid,
        isAnonymous: result.user.isAnonymous,
        providerIds: result.user.providerIds,
        lastAuthAt: now(),
        lastError: ""
      });

      return {
        ok: true,
        status: "linked",
        authState
      };

    } catch (error) {
      const message = error && error.message
        ? error.message
        : String(error);

      status = {
        ...status,
        state: "error",
        lastError: message
      };

      return {
        ok: false,
        status: "error",
        error
      };
    }
  }

  async function init() {
    if (initPromise) {
      return initPromise;
    }

    initPromise = (async () => {
      if (initialized) {
        return getStatus();
      }

      initialized = true;
      adapter = createAdapter();
      status = {
        ...status,
        provider: adapter.name || "offline"
      };

      await signInAnonymously();

      return getStatus();
    })();

    return initPromise;
  }

  return {
    getAdapter,
    getState,
    getStatus,
    init,
    linkWithCredential,
    setAdapter,
    signInAnonymously
  };
})();

window.FlagGameAuth = FlagGameAuth;

FlagGameAuth.init();
