package app.flaggame.playgames;

import android.app.Activity;
import android.net.Uri;
import android.util.Log;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.android.gms.games.AuthenticationResult;
import com.google.android.gms.games.GamesSignInClient;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import com.google.android.gms.games.Player;

@CapacitorPlugin(name = "FlagGamePlayGames")
public class FlagGamePlayGamesPlugin extends Plugin {
    private static final String TAG = "FlagGamePlayGames";
    private static final String PROJECT_ID_RESOURCE = "game_services_project_id";

    @Override
    public void load() {
        try {
            PlayGamesSdk.initialize(getContext());
            Log.i(TAG, "Play Games SDK initialization requested");
        } catch (Exception error) {
            Log.w(TAG, "Play Games SDK initialization failed", error);
        }
    }

    @PluginMethod
    public void isAvailable(PluginCall call) {
        int status = getPlayServicesStatus();
        boolean playServicesAvailable = status == ConnectionResult.SUCCESS;
        boolean configured = isPlayGamesConfigured();

        JSObject result = baseResult();
        result.put("available", playServicesAvailable && configured);
        result.put("configured", configured);
        result.put("playServicesStatus", status);

        if (!playServicesAvailable) {
            result.put("status", "play_services_unavailable");
            result.put("error", structuredError(
                "play_services_unavailable",
                "Google Play services is not available on this device.",
                null
            ));
        } else if (!configured) {
            result.put("status", "configuration_pending");
            result.put("error", structuredError(
                "configuration_pending",
                "The Play Games Services project ID placeholder must be replaced before native authentication can run.",
                null
            ));
        } else {
            result.put("status", "available");
        }

        call.resolve(result);
    }

    @PluginMethod
    public void getAuthenticationStatus(PluginCall call) {
        Activity activity = getReadyActivityOrResolve(call);

        if (activity == null) {
            return;
        }

        GamesSignInClient signInClient = PlayGames.getGamesSignInClient(activity);
        signInClient
            .isAuthenticated()
            .addOnSuccessListener(result ->
                resolveAuthentication(call, result, "authentication_status")
            )
            .addOnFailureListener(error -> resolveNativeError(
                call,
                "authentication_status_failed",
                "Could not read the Play Games authentication status.",
                error
            ));
    }

    @PluginMethod
    public void requestAuthenticationRetry(PluginCall call) {
        Activity activity = getReadyActivityOrResolve(call);

        if (activity == null) {
            return;
        }

        GamesSignInClient signInClient = PlayGames.getGamesSignInClient(activity);
        signInClient
            .signIn()
            .addOnSuccessListener(result ->
                resolveAuthentication(call, result, "authentication_retry")
            )
            .addOnFailureListener(error -> resolveNativeError(
                call,
                "authentication_retry_failed",
                "Could not retry Play Games authentication.",
                error
            ));
    }

    @PluginMethod
    public void getPlayerSummary(PluginCall call) {
        Activity activity = getReadyActivityOrResolve(call);

        if (activity == null) {
            return;
        }

        GamesSignInClient signInClient = PlayGames.getGamesSignInClient(activity);
        signInClient
            .isAuthenticated()
            .addOnSuccessListener(authentication -> {
                if (authentication == null || !authentication.isAuthenticated()) {
                    resolveNotAuthenticated(call);
                    return;
                }

                PlayGames.getPlayersClient(activity)
                    .getCurrentPlayer()
                    .addOnSuccessListener(player -> resolvePlayer(call, player))
                    .addOnFailureListener(error -> resolveNativeError(
                        call,
                        "player_summary_failed",
                        "Could not read the Play Games player summary.",
                        error
                    ));
            })
            .addOnFailureListener(error -> resolveNativeError(
                call,
                "authentication_status_failed",
                "Could not read the Play Games authentication status.",
                error
            ));
    }

    @PluginMethod
    public void syncSavedGame(PluginCall call) {
        resolveFeatureBlocked(call, "saved_games_not_implemented", "saved_games");
    }

    @PluginMethod
    public void commitSavedGame(PluginCall call) {
        resolveFeatureBlocked(call, "saved_games_not_implemented", "saved_games");
    }

    @PluginMethod
    public void submitLeaderboardScore(PluginCall call) {
        resolveFeatureBlocked(call, "leaderboards_not_implemented", "leaderboards");
    }

    @PluginMethod
    public void unlockAchievement(PluginCall call) {
        resolveFeatureBlocked(call, "achievements_not_implemented", "achievements");
    }

    @PluginMethod
    public void openLeaderboards(PluginCall call) {
        resolveFeatureBlocked(call, "leaderboards_not_implemented", "leaderboards");
    }

    @PluginMethod
    public void openAchievements(PluginCall call) {
        resolveFeatureBlocked(call, "achievements_not_implemented", "achievements");
    }

    @PluginMethod
    public void requestServerSideAccess(PluginCall call) {
        String webClientId = call.getString("webClientId");

        if (webClientId == null || webClientId.isEmpty()) {
            call.reject("A valid Web Client ID is required for server side access.");
            return;
        }

        Activity activity = getReadyActivityOrResolve(call);
        if (activity == null) return;

        boolean forceRefreshToken = call.getBoolean("forceRefreshToken", false);

        PlayGames.getGamesSignInClient(activity)
            .requestServerSideAccess(webClientId, forceRefreshToken)
            .addOnSuccessListener(authCode -> {
                JSObject result = new JSObject();
                result.put("serverAuthCode", authCode);
                call.resolve(result);
            })
            .addOnFailureListener(error -> resolveNativeError(
                call,
                "server_access_failed",
                "Could not obtain server side access code.",
                error
            ));
    }

    private Activity getReadyActivityOrResolve(PluginCall call) {
        if (!resolveIfPlayServicesAvailable(call)) {
            return null;
        }

        if (!resolveIfConfigured(call)) {
            return null;
        }

        Activity activity = getActivity();

        if (activity == null) {
            resolveNativeError(
                call,
                "activity_unavailable",
                "The Android Activity is not available yet.",
                null
            );
            return null;
        }

        return activity;
    }

    private boolean resolveIfPlayServicesAvailable(PluginCall call) {
        int status = getPlayServicesStatus();

        if (status == ConnectionResult.SUCCESS) {
            return true;
        }

        JSObject result = baseResult();
        result.put("available", false);
        result.put("configured", isPlayGamesConfigured());
        result.put("status", "play_services_unavailable");
        result.put("playServicesStatus", status);
        result.put("error", structuredError(
            "play_services_unavailable",
            "Google Play services is not available on this device.",
            null
        ));
        call.resolve(result);
        return false;
    }

    private boolean resolveIfConfigured(PluginCall call) {
        if (isPlayGamesConfigured()) {
            return true;
        }

        JSObject result = baseResult();
        result.put("available", false);
        result.put("configured", false);
        result.put("status", "configuration_pending");
        result.put("error", structuredError(
            "configuration_pending",
            "The Play Games Services project ID placeholder must be replaced before native authentication can run.",
            null
        ));
        call.resolve(result);
        return false;
    }

    private int getPlayServicesStatus() {
        return GoogleApiAvailability
            .getInstance()
            .isGooglePlayServicesAvailable(getContext());
    }

    private boolean isPlayGamesConfigured() {
        String projectId = getStringResource(PROJECT_ID_RESOURCE);

        return !projectId.isEmpty() &&
            !projectId.startsWith("<") &&
            !projectId.endsWith(">") &&
            !projectId.contains("PLAY_GAMES_PROJECT_ID");
    }

    private String getStringResource(String resourceName) {
        int resourceId = getContext()
            .getResources()
            .getIdentifier(resourceName, "string", getContext().getPackageName());

        if (resourceId == 0) {
            return "";
        }

        try {
            return getContext().getString(resourceId).trim();
        } catch (Exception error) {
            return "";
        }
    }

    private void resolveAuthentication(
        PluginCall call,
        AuthenticationResult authentication,
        String authenticatedStatus
    ) {
        boolean authenticated = authentication != null && authentication.isAuthenticated();
        JSObject result = baseResult();
        result.put("available", true);
        result.put("configured", true);
        result.put("authenticated", authenticated);
        result.put("status", authenticated ? authenticatedStatus : "not_authenticated");

        if (!authenticated) {
            result.put("error", structuredError(
                "not_authenticated",
                "The player is not authenticated with Play Games Services.",
                null
            ));
        }

        call.resolve(result);
    }

    private void resolveNotAuthenticated(PluginCall call) {
        JSObject result = baseResult();
        result.put("available", true);
        result.put("configured", true);
        result.put("authenticated", false);
        result.put("status", "not_authenticated");
        result.put("error", structuredError(
            "not_authenticated",
            "The player is not authenticated with Play Games Services.",
            null
        ));
        call.resolve(result);
    }

    private void resolvePlayer(PluginCall call, Player player) {
        JSObject result = baseResult();
        result.put("available", true);
        result.put("configured", true);
        result.put("authenticated", true);
        result.put("status", "player_summary");
        result.put("player", playerSummary(player));
        call.resolve(result);
    }

    private void resolveFeatureBlocked(
        PluginCall call,
        String code,
        String feature
    ) {
        JSObject result = baseResult();
        result.put("available", false);
        result.put("configured", isPlayGamesConfigured());
        result.put("status", "not_configured");
        result.put("feature", feature);
        result.put("error", structuredError(
            code,
            "This Play Games Services feature is intentionally not implemented in this build.",
            null
        ));
        call.resolve(result);
    }

    private void resolveNativeError(
        PluginCall call,
        String code,
        String message,
        Exception error
    ) {
        JSObject result = baseResult();
        result.put("available", true);
        result.put("configured", isPlayGamesConfigured());
        result.put("authenticated", false);
        result.put("status", "error");
        result.put("error", structuredError(code, message, error));
        call.resolve(result);
    }

    private JSObject baseResult() {
        JSObject result = new JSObject();
        result.put("available", false);
        result.put("configured", false);
        result.put("authenticated", false);
        result.put("player", null);
        result.put("error", null);
        return result;
    }

    private JSObject playerSummary(Player player) {
        JSObject summary = new JSObject();

        if (player == null) {
            return summary;
        }

        putStringSafely(summary, "playerId", () -> player.getPlayerId());
        putStringSafely(summary, "displayName", () -> player.getDisplayName());
        putStringSafely(summary, "iconImageUri", () -> uriToString(player.getIconImageUri()));
        putStringSafely(summary, "hiResImageUri", () -> uriToString(player.getHiResImageUri()));

        return summary;
    }

    private void putStringSafely(
        JSObject target,
        String key,
        StringSupplier supplier
    ) {
        try {
            target.put(key, supplier.get());
        } catch (Exception error) {
            target.put(key, null);
        }
    }

    private String uriToString(Uri uri) {
        return uri == null ? null : uri.toString();
    }

    private JSObject structuredError(String code, String message, Exception error) {
        JSObject payload = new JSObject();
        payload.put("code", code);
        payload.put("message", message);

        if (error != null) {
            payload.put("nativeMessage", error.getMessage());
            payload.put("nativeClass", error.getClass().getName());
        }

        return payload;
    }

    private interface StringSupplier {
        String get();
    }
}
