(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGameAuth = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  let authChangeListeners = [];
  let supabaseSubscription = null;
  let isAuthenticating = false;
  let accountDeletionPromise = null;
  const ACCOUNT_DELETION_TIMEOUT_MS = 30000;
  const ACCOUNT_LINKED_STORAGE_KEYS = [
    "flagGameAuthState",
    "flagGameProfile",
    "flagGameRankingPlayer",
    "flagGameRankingQueue",
    "flagGameRankingsCache",
    "flagGameCloudSaveState",
    "flagGameInstallationId",
    "flagGamePlayGamesCompetitive",
    "flagGameChallenges",
    "flagGameWorldChallenge",
    "flagGameWorldChallengeBackup",
    "flagGameWorldChallengeTemp",
    "flagGameWorldChallengeRecords",
    "flagGameWorldChallengeCheckpoint",
    "profile_migrated"
  ];

  // Initialization State
  let isReadyPromise = null;
  let resolveReady = null;

  isReadyPromise = new Promise(resolve => {
    resolveReady = resolve;
    // Safety timeout: resolve after 5s regardless
    setTimeout(resolve, 5000);
  });

  // Cloud Profile State
  let currentCloudProfile = null;
  let profileLoadPromise = null;
  let profileLoadError = null;

  function generateSecureNonce() {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
  }

  async function sha256Hex(plain) {
    const encoder = new TextEncoder();
    const data = encoder.encode(plain);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  }

  function sanitizeNickname(name) {
    if (!name) return "";
    // Normalizar Unicode e remover acentos
    let sanitized = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    // Manter apenas A-Z, 0-9, espaços, hifens e underscores
    sanitized = sanitized.replace(/[^a-zA-Z0-9 _-]/g, "");
    // Reduzir espaços consecutivos e trim
    sanitized = sanitized.replace(/\s+/g, " ").trim();
    // Limitar comprimento
    return sanitized.slice(0, 24);
  }

  function validateCountry(code) {
    if (!code || typeof code !== "string") return null;
    const sanitized = code.trim().toUpperCase();
    return sanitized.length === 2 ? sanitized : null;
  }

  function getSupabase() {
    return root.FlagGameSupabase ? root.FlagGameSupabase.client : null;
  }

  function getGoogleAuthPlugin() {
    const capacitor = root.Capacitor;
    if (capacitor && capacitor.Plugins) {
      return capacitor.Plugins.FlagGameGoogleAuth || null;
    }
    return null;
  }

  function getPlayGamesPlugin() {
    const capacitor = root.Capacitor;
    if (capacitor && capacitor.Plugins) {
      return capacitor.Plugins.FlagGamePlayGames || null;
    }
    return null;
  }

  function createAccountDeletionError(code, message, cause) {
    const error = new Error(message || code);
    error.name = "AccountDeletionError";
    error.code = code;
    if (cause) error.cause = cause;
    return error;
  }

  function isSupabaseAuthStorageKey(key) {
    return /^sb-[a-z0-9]+-auth-token$/i.test(String(key || "")) ||
      key === "supabase.auth.token";
  }

  function removeLocalAccountData() {
    const removedKeys = [];
    const storage = root.FlagGameStorage || null;

    ACCOUNT_LINKED_STORAGE_KEYS.forEach(key => {
      if (storage && storage.remove) {
        storage.remove(key);
      } else if (root.localStorage) {
        root.localStorage.removeItem(key);
      }
      removedKeys.push(key);
    });

    if (root.localStorage) {
      for (let index = root.localStorage.length - 1; index >= 0; index--) {
        const key = root.localStorage.key(index);
        if (isSupabaseAuthStorageKey(key)) {
          root.localStorage.removeItem(key);
          removedKeys.push(key);
        }
      }
    }

    return [...new Set(removedKeys)];
  }

  async function getFreshGoogleIdToken() {
    const plugin = getGoogleAuthPlugin();
    const config = root.FlagGameSupabase ? root.FlagGameSupabase.config : {};

    if (!plugin) {
      throw createAccountDeletionError(
        "google_auth_unavailable",
        "Google authentication is not available on this platform."
      );
    }

    const rawNonce = generateSecureNonce();
    const hashedNonce = await sha256Hex(rawNonce);
    const response = await plugin.signInWithGoogle({
      serverClientId: config.googleWebClientId,
      nonce: hashedNonce
    });

    if (!response || !response.idToken) {
      throw createAccountDeletionError(
        "google_reauthentication_cancelled",
        "Google reauthentication was cancelled."
      );
    }

    return {
      idToken: response.idToken,
      rawNonce
    };
  }

  async function signInWithGoogleToken(idToken, rawNonce) {
    const supabase = getSupabase();

    if (!supabase) {
      throw createAccountDeletionError(
        "auth_unavailable",
        "Authentication services are not available."
      );
    }

    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: "google",
      token: idToken,
      nonce: rawNonce
    });

    if (error) throw error;
    return data;
  }

  async function signInWithGoogle() {
    if (isAuthenticating) return;

    const supabase = getSupabase();

    if (!supabase) {
      throw new Error("Authentication services not available on this platform.");
    }

    isAuthenticating = true;

    try {
      const { idToken, rawNonce } = await getFreshGoogleIdToken();
      const data = await signInWithGoogleToken(idToken, rawNonce);

      // 4. Ensure profile exists on backend
      await ensureCloudProfile();

      return data;
    } catch (error) {
      console.error("Login failed:", error);
      throw error;
    } finally {
      isAuthenticating = false;
    }
  }

  async function ensureCloudProfile(forceRefresh) {
    const supabase = getSupabase();
    const user = await getCurrentUser();

    if (!supabase || !user) {
        currentCloudProfile = null;
        profileLoadError = null;
        return null;
    }

    // Se já estiver carregado para o mesmo usuário, retornar cache
    if (!forceRefresh && currentCloudProfile && currentCloudProfile.id === user.id) {
        return currentCloudProfile;
    }

    // Se já houver uma carga em andamento, retornar a mesma promise
    if (profileLoadPromise) return profileLoadPromise;

    profileLoadPromise = (async () => {
        try {
            // 1. Tentar buscar perfil existente
            const { data: profile, error: fetchError } = await supabase
                .from('profiles')
                .select('*')
                .eq('id', user.id)
                .maybeSingle();

            if (fetchError) throw fetchError;

            if (profile) {
                currentCloudProfile = profile;
                profileLoadError = null;
                return profile;
            }

            // 2. Se não existir, criar perfil inicial (ensure_profile RPC)
            const localPlayer = root.FlagGameRanking ? root.FlagGameRanking.getPlayer() : {};

            let initialNickname = sanitizeNickname(localPlayer.nickname);
            if (initialNickname.length < 3) {
                initialNickname = sanitizeNickname(user.user_metadata.full_name);
            }
            if (initialNickname.length < 3) {
                initialNickname = "Player";
            }

            const initialCountry = validateCountry(localPlayer.country);

            const { data: newProfile, error: rpcError } = await supabase.rpc('ensure_profile', {
                p_nickname: initialNickname,
                p_country: initialCountry
            });

            if (rpcError) throw rpcError;

            currentCloudProfile = newProfile;
            profileLoadError = null;
            return newProfile;

        } catch (err) {
            console.error("Cloud Profile Error:", err.code || "unknown", err.message);
            profileLoadError = "Não foi possível carregar seu perfil online.";
            currentCloudProfile = null;
            throw err;
        } finally {
            profileLoadPromise = null;
            // Notificar listeners de mudança de estado (opcional, mas bom para UI)
            notifyAuthChange("PROFILE_UPDATED", null);
        }
    })();

    return profileLoadPromise;
  }

  function getCloudProfile() {
    return currentCloudProfile;
  }

  async function updateCloudProfile(patch) {
    const supabase = getSupabase();
    const user = await getCurrentUser();

    if (!supabase || !user) {
      throw new Error("Unauthorized");
    }

    const { data, error } = await supabase
      .from('profiles')
      .update(patch)
      .eq('id', user.id)
      .select('*')
      .single();

    if (error) throw error;

    currentCloudProfile = data || {
      ...(currentCloudProfile || {}),
      id: user.id,
      ...patch
    };
    profileLoadError = null;
    notifyAuthChange("PROFILE_UPDATED", await getCurrentSession());

    return currentCloudProfile;
  }

  function getProfileError() {
    return profileLoadError;
  }

  function isProfileLoading() {
    return !!profileLoadPromise;
  }

  async function getCurrentSession() {
    const supabase = getSupabase();
    if (!supabase) return null;
    const { data } = await supabase.auth.getSession();
    return data.session;
  }

  async function getCurrentUser() {
    const session = await getCurrentSession();
    return session ? session.user : null;
  }

  function isAuthenticated() {
    return getCurrentUser().then(user => !!user);
  }

  async function signOut() {
    const supabase = getSupabase();
    if (supabase) {
      await supabase.auth.signOut();
      currentCloudProfile = null;
      profileLoadError = null;
      profileLoadPromise = null;
    }
  }

  async function restorePreviousSession(previousSession) {
    const supabase = getSupabase();
    if (!supabase || !previousSession || !previousSession.access_token || !previousSession.refresh_token) {
      return false;
    }

    const { error } = await supabase.auth.setSession({
      access_token: previousSession.access_token,
      refresh_token: previousSession.refresh_token
    });

    return !error;
  }

  async function invokeWithTimeout(promise, timeoutMs) {
    let timeoutId = null;
    const timeout = new Promise((_, reject) => {
      timeoutId = setTimeout(() => {
        reject(createAccountDeletionError("timeout", "Account deletion timed out."));
      }, timeoutMs || ACCOUNT_DELETION_TIMEOUT_MS);
    });

    try {
      return await Promise.race([promise, timeout]);
    } finally {
      if (timeoutId) clearTimeout(timeoutId);
    }
  }

  async function readFunctionErrorCode(error) {
    if (!error) return "";

    if (error.context && typeof error.context.clone === "function") {
      try {
        const payload = await error.context.clone().json();
        return String(payload && payload.code || "");
      } catch (_ignored) {
        return "";
      }
    }

    return String(error.code || "");
  }

  function classifyDeleteAccountFailure(code, error) {
    if (code === "reauthentication_required") return "reauthentication_required";
    if (code === "authentication_required" || code === "invalid_session") return "invalid_session";
    if (code === "google_auth_required") return "google_auth_required";
    if (code === "temporary_delete_failure") return "temporary_delete_failure";
    if (code === "delete_failure") return "delete_failure";
    if (code === "account_deletion_not_allowed") return "delete_failure";

    if (typeof navigator !== "undefined" && navigator.onLine === false) {
      return "network";
    }

    if (error && (error.name === "TypeError" || /fetch|network|connection/i.test(String(error.message || "")))) {
      return "network";
    }

    return "unexpected_response";
  }

  async function deleteAccount(options) {
    if (accountDeletionPromise) {
      throw createAccountDeletionError(
        "account_deletion_in_progress",
        "Account deletion is already in progress."
      );
    }

    accountDeletionPromise = (async () => {
      const supabase = getSupabase();
      const previousSession = await getCurrentSession();
      const originalUser = previousSession && previousSession.user;

      if (!supabase || !originalUser) {
        throw createAccountDeletionError("invalid_session", "A valid session is required.");
      }

      let freshToken = null;

      try {
        freshToken = await getFreshGoogleIdToken();
        const reauthData = await signInWithGoogleToken(freshToken.idToken, freshToken.rawNonce);
        const reauthSession = reauthData && reauthData.session
          ? reauthData.session
          : await getCurrentSession();
        const reauthUser = reauthSession && reauthSession.user;

        if (!reauthUser) {
          await restorePreviousSession(previousSession);
          throw createAccountDeletionError("invalid_session", "Reauthentication did not return a user.");
        }

        if (reauthUser.id !== originalUser.id) {
          const restored = await restorePreviousSession(previousSession);
          throw createAccountDeletionError(
            restored ? "google_account_mismatch" : "google_account_mismatch_restore_failed",
            "Choose the same Google account to delete this account."
          );
        }

        const invokePromise = supabase.functions.invoke("delete-account");
        const { data, error } = await invokeWithTimeout(
          invokePromise,
          options && options.timeoutMs
        );

        if (error) {
          const code = await readFunctionErrorCode(error);
          throw createAccountDeletionError(
            classifyDeleteAccountFailure(code, error),
            "Could not delete the account.",
            error
          );
        }

        if (!data || data.ok !== true || data.code !== "account_deleted") {
          throw createAccountDeletionError(
            classifyDeleteAccountFailure(String(data && data.code || ""), null),
            "Unexpected account deletion response."
          );
        }

        try {
          await supabase.auth.signOut();
        } catch (_ignored) {
          // The Auth user has just been deleted. Local cleanup below is the
          // authoritative client-side state transition after backend success.
        }

        currentCloudProfile = null;
        profileLoadError = null;
        profileLoadPromise = null;
        const removedKeys = removeLocalAccountData();
        notifyAuthChange("ACCOUNT_DELETED", null);

        return {
          ok: true,
          code: "account_deleted",
          removedKeys
        };
      } catch (error) {
        if (error && error.name === "AccountDeletionError") {
          throw error;
        }

        const code =
          error && /cancel|canceled|cancelled|abort/i.test(String(error.message || ""))
            ? "google_reauthentication_cancelled"
            : classifyDeleteAccountFailure("", error);

        throw createAccountDeletionError(code, "Could not delete the account.", error);
      } finally {
        freshToken = null;
      }
    })();

    try {
      return await accountDeletionPromise;
    } finally {
      accountDeletionPromise = null;
    }
  }

  function notifyAuthChange(event, session) {
    authChangeListeners.forEach(callback => {
        try {
            callback(event, session);
        } catch (e) {
            console.error("Auth callback error:", e);
        }
    });
  }

  function subscribeToAuthChanges(callback) {
    authChangeListeners.push(callback);
    const supabase = getSupabase();
    if (supabase && !supabaseSubscription) {
      const { data } = supabase.auth.onAuthStateChange((event, session) => {
        if (event === "SIGNED_IN" || event === "INITIAL_SESSION") {
            if (session) ensureCloudProfile().finally(resolveReady);
            else resolveReady();
        } else if (event === "SIGNED_OUT") {
            currentCloudProfile = null;
            profileLoadError = null;
            profileLoadPromise = null;
        }
        notifyAuthChange(event, session);
      });
      supabaseSubscription = data && data.subscription ? data.subscription : true;

      // Also check if session is already there
      supabase.auth.getSession().then(({data}) => {
          if (data.session) {
            ensureCloudProfile().finally(resolveReady);
          } else {
            resolveReady();
          }
          callback("INITIAL_SESSION", data.session);
      }).catch(() => {
          resolveReady();
          callback("SESSION_ERROR", null);
      });
    } else {
        resolveReady();
        callback("INITIAL_SESSION", null);
    }
    return () => {
      authChangeListeners = authChangeListeners.filter(l => l !== callback);
    };
  }

  async function isReady() {
      return isReadyPromise;
  }

  async function linkPlayGamesIdentity() {
    const pgPlugin = getPlayGamesPlugin();
    const supabase = getSupabase();
    const config = root.FlagGameSupabase ? root.FlagGameSupabase.config : {};

    if (!pgPlugin || !supabase) return;

    const user = await getCurrentUser();
    if (!user) return;

    try {
      const { serverAuthCode } = await pgPlugin.requestServerSideAccess({
        webClientId: config.googleWebClientId
      });

      const { data, error } = await supabase.functions.invoke('link-play-games-identity', {
        body: { serverAuthCode }
      });

      if (error) throw error;
      return data;
    } catch (error) {
      console.error("Play Games linking failed:", error);
      throw error;
    }
  }

  return {
    signInWithGoogle,
    getCurrentSession,
    getCurrentUser,
    isAuthenticated,
    signOut,
    subscribeToAuthChanges,
    ensureCloudProfile,
    getCloudProfile,
    getProfileError,
    isProfileLoading,
    isReady,
    updateCloudProfile,
    linkPlayGamesIdentity,
    deleteAccount,
    removeLocalAccountData
  };
});
