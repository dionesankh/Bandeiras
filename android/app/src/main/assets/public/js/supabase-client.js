(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory(root);
  } else {
    root.FlagGameSupabase = factory(root);
  }
})(typeof globalThis !== "undefined" ? globalThis : window, function (root) {
  "use strict";

  // Production/public configuration remains the default. Staging requires an
  // explicit build/runtime marker generated only for staging validation.
  const PRODUCTION_CONFIG = {
    url: "https://kyupoytmphmdbwuvigcu.supabase.co",
    anonKey: "sb_publishable_q6gHDrt__gDxmuLBPrRqGA_BrnySaiW",
    googleWebClientId: "848159149097-v6gjl2vsaq2meevmtq0lqk6b183r402u.apps.googleusercontent.com",
    environment: "production"
  };

  const STAGING_HOST = "uzydndoaxpvdxiuiaunz.supabase.co";

  function redactedClientId(value) {
    const text = String(value || "");
    const marker = ".apps.googleusercontent.com";
    if (!text.endsWith(marker)) return "invalid";
    return `${text.slice(0, 6)}...${marker}`;
  }

  function validateStagingConfig(config) {
    if (root.FlagGameEnvironment !== "staging") return null;

    if (!config || config.environment !== "staging") {
      throw new Error("Staging was requested but staging Supabase configuration is missing.");
    }

    const url = String(config.url || "").trim();
    const anonKey = String(config.anonKey || "").trim();
    const googleWebClientId = String(config.googleWebClientId || "").trim();

    if (!url || !anonKey || !googleWebClientId) {
      throw new Error("Incomplete staging Supabase configuration.");
    }

    const parsedUrl = new URL(url);
    if (parsedUrl.hostname !== STAGING_HOST) {
      throw new Error("Staging Supabase host does not match the approved project.");
    }

    if (!googleWebClientId.endsWith(".apps.googleusercontent.com")) {
      throw new Error("Invalid staging Google Web Client ID format.");
    }

    if (config.serviceRoleKey || config.clientSecret || config.googleClientSecret) {
      throw new Error("Secret fields are not allowed in frontend staging configuration.");
    }

    return {
      url,
      anonKey,
      googleWebClientId,
      environment: "staging"
    };
  }

  function resolveConfig() {
    const stagingConfig = validateStagingConfig(root.FlagGameSupabaseStagingConfig);
    if (!stagingConfig) return PRODUCTION_CONFIG;

    const capacitor = root.Capacitor || {};
    const location = root.location || {};

    console.info("ENVIRONMENT: STAGING", {
      origin: location.origin || "unknown",
      protocol: location.protocol || "unknown",
      hostname: location.hostname || "unknown",
      isNativePlatform: typeof capacitor.isNativePlatform === "function"
        ? capacitor.isNativePlatform()
        : "unknown",
      supabaseHost: STAGING_HOST,
      googleClient: "staging",
      googleClientId: redactedClientId(stagingConfig.googleWebClientId)
    });

    return stagingConfig;
  }

  const CONFIG = resolveConfig();

  let client = null;

  function getClient() {
    if (!client) {
      if (!root.supabase) {
        throw new Error("Supabase library not loaded. Check index.html script tags.");
      }

      client = root.supabase.createClient(CONFIG.url, CONFIG.anonKey, {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: false // Not needed for Android native flow
        }
      });
    }
    return client;
  }

  return {
    get client() {
      return getClient();
    },
    get config() {
      return { ...CONFIG };
    }
  };
});
