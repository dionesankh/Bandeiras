import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";

serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response("Unauthorized", { status: 0 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (authError || !user) return new Response("Unauthorized", { status: 0 });

    const { serverAuthCode } = await req.json();
    if (!serverAuthCode) return new Response("Missing code", { status: 400 });

    // 1. Exchange serverAuthCode for Access Token
    const params = new URLSearchParams();
    params.append("grant_type", "authorization_code");
    params.append("code", serverAuthCode);
    params.append("client_id", Deno.env.get("GOOGLE_WEB_CLIENT_ID") ?? "");
    params.append("client_secret", Deno.env.get("GOOGLE_WEB_CLIENT_SECRET") ?? "");

    const tokenRes = await fetch(GOOGLE_TOKEN_URL, {
      method: "POST",
      body: params,
      headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });

    const tokens = await tokenRes.json();
    if (!tokens.access_token) {
        console.error("Token exchange failed", tokens);
        return new Response("Token exchange failed", { status: 400 });
    }

    // 2. Get Player ID from Google Play Games
    const pgRes = await fetch("https://www.googleapis.com/games/v1/players/me", {
      headers: { "Authorization": `Bearer ${tokens.access_token}` }
    });

    const player = await pgRes.json();
    if (!player.playerId) return new Response("Could not verify Player ID", { status: 400 });

    // 3. Link Identity via RPC
    const { error: rpcError } = await supabase.rpc('link_player_identity', {
      p_provider: 'google_play',
      p_player_id: player.playerId,
      p_legacy_id: null // To be handled if needed
    });

    if (rpcError) {
        console.error("RPC Error", rpcError);
        return new Response(rpcError.message, { status: 400 });
    }

    return new Response(JSON.stringify({ ok: true, playerId: player.playerId }), {
      headers: { "Content-Type": "application/json" }
    });

  } catch (err) {
    return new Response(err.message, { status: 500 });
  }
})
