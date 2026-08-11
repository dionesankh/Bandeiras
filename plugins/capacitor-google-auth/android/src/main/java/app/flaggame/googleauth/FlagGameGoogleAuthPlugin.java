package app.flaggame.googleauth;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.credentials.CredentialManager;
import androidx.credentials.GetCredentialRequest;
import androidx.credentials.GetCredentialResponse;
import androidx.credentials.CustomCredential;
import androidx.credentials.CredentialManagerCallback;
import androidx.credentials.exceptions.GetCredentialException;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.android.libraries.identity.googleid.GetGoogleIdOption;
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential;

import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

@CapacitorPlugin(name = "FlagGameGoogleAuth")
public class FlagGameGoogleAuthPlugin extends Plugin {
    private static final String TAG = "FlagGameGoogleAuth";
    private final Executor executor = Executors.newSingleThreadExecutor();

    @PluginMethod
    public void signInWithGoogle(PluginCall call) {
        String serverClientId = call.getString("serverClientId");
        if (serverClientId == null || serverClientId.isEmpty()) {
            call.reject("Server Client ID is required.");
            return;
        }

        String nonce = call.getString("nonce");
        if (nonce == null || nonce.isEmpty()) {
            call.reject("Nonce is required from Javascript.");
            return;
        }

        Activity activity = getActivity();
        if (activity == null) {
            call.reject("Activity is not available.");
            return;
        }

        CredentialManager credentialManager = CredentialManager.create(activity);

        GetGoogleIdOption googleIdOption = new GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(serverClientId)
            .setNonce(nonce)
            .setAutoSelectEnabled(false)
            .build();

        GetCredentialRequest request = new GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build();

        credentialManager.getCredentialAsync(
            activity,
            request,
            null, // cancellation signal
            executor,
            new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                @Override
                public void onResult(GetCredentialResponse result) {
                    if (result.getCredential() instanceof CustomCredential && 
                        result.getCredential().getType().equals(GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL)) {
                        try {
                            GoogleIdTokenCredential credential = GoogleIdTokenCredential.createFrom(result.getCredential().getData());
                            JSObject ret = new JSObject();
                            ret.put("idToken", credential.getIdToken());
                            ret.put("email", credential.getId());
                            call.resolve(ret);
                        } catch (Exception e) {
                            call.reject("Failed to parse Google ID Token: " + e.getMessage());
                        }
                    } else {
                        call.reject("Unexpected credential type: " + result.getCredential().getType());
                    }
                }

                @Override
                public void onError(GetCredentialException e) {
                    Log.e(TAG, "Google Sign-In failed: " + e.getMessage() + " (Type: " + e.getType() + ")");
                    String errorType = e.getType();
                    String userFriendlyMessage = "Google Sign-In failed: " + e.getMessage();
                    
                    if (errorType.contains("TYPE_NO_CREDENTIALS")) {
                        userFriendlyMessage = "No Google accounts available or app configuration mismatch (Check SHA-1).";
                    }
                    
                    call.reject(userFriendlyMessage, errorType);
                }
            }
        );
    }
}
