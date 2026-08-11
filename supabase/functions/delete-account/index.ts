import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, type User } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const DEFAULT_ALLOWED_ORIGINS = [
  "https://localhost",
  "https://flaggameapp.github.io",
];

type JsonBody = Record<string, unknown>;
type AmrEntry = {
  method?: unknown;
  timestamp?: unknown;
};
type RecentAuthCheck =
  | { ok: true }
  | { ok: false; code: "google_auth_required" | "reauthentication_required" };

function allowedOrigins(): string[] {
  const configured = Deno.env.get("DELETE_ACCOUNT_ALLOWED_ORIGINS");
  if (!configured) return DEFAULT_ALLOWED_ORIGINS;

  return configured
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function corsHeaders(origin: string | null): HeadersInit {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };

  if (origin && allowedOrigins().includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }

  return headers;
}

function originAllowed(origin: string | null): boolean {
  return !origin || allowedOrigins().includes(origin);
}

function jsonResponse(status: number, body: JsonBody, origin: string | null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function bearerToken(req: Request): string {
  const authHeader = req.headers.get("Authorization") || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : "";
}

function decodeJwtPayload(token: string): JsonBody | null {
  const payload = token.split(".")[1];
  if (!payload) return null;

  try {
    const base64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), "=");
    return JSON.parse(atob(padded));
  } catch (_error) {
    return null;
  }
}

function maxRecentAuthAgeSeconds(): number {
  const configured = Number(Deno.env.get("DELETE_ACCOUNT_MAX_SESSION_AGE_SECONDS") || "900");
  return Number.isFinite(configured) && configured > 0 ? configured : 900;
}

function unixSeconds(value: unknown): number {
  const numeric = Number(value || 0);
  if (!Number.isFinite(numeric) || numeric <= 0) return 0;
  return numeric > 10_000_000_000 ? Math.floor(numeric / 1000) : Math.floor(numeric);
}

function timestampIsRecent(timestamp: number, maxAgeSeconds: number): boolean {
  if (!timestamp) return false;

  const nowSeconds = Math.floor(Date.now() / 1000);
  const ageSeconds = nowSeconds - timestamp;
  return ageSeconds >= -60 && ageSeconds <= maxAgeSeconds;
}

function hasGoogleProvider(user: User): boolean {
  const metadata = user.app_metadata || {};
  const provider = String(metadata.provider || "").toLowerCase();
  const providers = Array.isArray(metadata.providers)
    ? metadata.providers.map((item) => String(item).toLowerCase())
    : [];

  return provider === "google" || providers.includes("google");
}

function hasRecentGoogleAuthEvidence(token: string, user: User): RecentAuthCheck {
  if (!hasGoogleProvider(user)) {
    return { ok: false, code: "google_auth_required" };
  }

  const payload = decodeJwtPayload(token);
  if (!payload) {
    return { ok: false, code: "reauthentication_required" };
  }

  const maxAgeSeconds = maxRecentAuthAgeSeconds();
  const amr = Array.isArray(payload.amr) ? payload.amr as AmrEntry[] : [];
  const hasRecentOAuthMethod = amr.some((entry) => {
    const method = String(entry?.method || "").toLowerCase();
    const timestamp = unixSeconds(entry?.timestamp);

    return ["google", "oauth", "sso"].includes(method) &&
      timestampIsRecent(timestamp, maxAgeSeconds);
  });

  if (hasRecentOAuthMethod) {
    return { ok: true };
  }

  const authTime = unixSeconds(payload.auth_time);
  if (timestampIsRecent(authTime, maxAgeSeconds)) {
    return { ok: true };
  }

  return { ok: false, code: "reauthentication_required" };
}

function isTemporaryDeleteError(error: unknown): boolean {
  const status = Number((error as { status?: number; statusCode?: number })?.status ||
    (error as { status?: number; statusCode?: number })?.statusCode || 0);
  const message = String((error as { message?: string })?.message || "");

  return status === 408 ||
    status === 409 ||
    status === 425 ||
    status === 429 ||
    status >= 500 ||
    /timeout|temporar|network|fetch|connection/i.test(message);
}

serve(async (req) => {
  const origin = req.headers.get("Origin");

  if (!originAllowed(origin)) {
    return jsonResponse(403, { ok: false, code: "origin_not_allowed" }, origin);
  }

  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(origin),
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, code: "method_not_allowed" }, origin);
  }

  const token = bearerToken(req);
  if (!token) {
    return jsonResponse(401, { ok: false, code: "authentication_required" }, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    console.error("delete-account configuration missing");
    return jsonResponse(500, { ok: false, code: "server_configuration_error" }, origin);
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
  });

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  const user = userData?.user;

  if (userError || !user) {
    return jsonResponse(401, { ok: false, code: "invalid_session" }, origin);
  }

  const recentAuth = hasRecentGoogleAuthEvidence(token, user);
  if (!recentAuth.ok) {
    return jsonResponse(401, { ok: false, code: recentAuth.code }, origin);
  }

  const { error: preflightError } = await userClient.rpc("validate_account_deletion_request");

  if (preflightError) {
    const preflightStatus = Number((preflightError as { status?: number }).status || 0);

    console.error("delete-account preflight failed", {
      code: preflightError.code,
      status: preflightStatus || null,
    });

    return jsonResponse(403, { ok: false, code: "account_deletion_not_allowed" }, origin);
  }

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id, false);

  if (deleteError) {
    const temporary = isTemporaryDeleteError(deleteError);

    console.error("delete-account auth deletion failed", {
      temporary,
      status: deleteError.status || null,
      name: deleteError.name || "AuthAdminError",
    });

    return jsonResponse(
      temporary ? 503 : 500,
      {
        ok: false,
        code: temporary ? "temporary_delete_failure" : "delete_failure",
        retryable: temporary,
      },
      origin,
    );
  }

  return jsonResponse(200, { ok: true, code: "account_deleted" }, origin);
});
