# Account Deletion Backend

This document describes the local backend implementation for deleting a Flag Game account. Nothing here has been deployed or applied to the remote Supabase project.

## Schema Findings

| Object | Local evidence | Account deletion treatment |
| --- | --- | --- |
| `auth.users` | App tables reference `auth.users(id)`. Supabase Auth owns Google identity/email metadata. | Deleted through Supabase Auth Admin API. A `BEFORE DELETE` trigger performs app-data cleanup in the same transaction. |
| `public.profiles` | `id uuid` primary key, `REFERENCES auth.users(id) ON DELETE CASCADE`; nickname, country, avatar key, privacy JSON. | Deleted. |
| `private.player_identities` | `user_id uuid not null`, provider/player ids, unique provider/player and user/provider. | Deleted. Removes Play Games/player identity links. |
| `private.supporter_entitlements` | Present in migrations and backups; status/product/source/grant fields; earlier backups use a shorter column set. | Preserved as minimal detached audit data. `user_id` becomes `NULL`, `deleted_user_hash` and `account_deleted_at` are stored, active/pending status is revoked. |
| `private.purchases` | Present in local migration `03_entitlements_purchases.sql`; not found in `pre_28_schema.sql`, so migration guards it as optional. | Preserved if table exists. `user_id`, raw `purchase_token`, `obfuscated_account_id`, and `raw_response` are cleared; token hash, order id, product, states, and dates remain. |
| `public.game_results` | `user_id uuid not null`, event id unique, ranked result metrics. | Deleted for the account. Rankings disappear because `global_rankings` derives from `game_results` joined to `profiles`. |
| `private.ranked_game_sessions` | `user_id uuid not null`; nonces, result refs, promotion/challenge refs. | Deleted after breaking result/session references. |
| `public.challenges` | `creator_id uuid not null` before migration 29, FK to `auth.users` with cascade in local migrations/backups. | `creator_id` becomes nullable and FK is changed to `ON DELETE SET NULL`. Ownerless open challenges are cancelled; challenges with no remaining participant account are deleted. |
| `public.challenge_participants` | `user_id uuid not null` before migration 29; copied challenge metrics; unique `(challenge_id, user_id)` and one creator/opponent indexes. | `user_id` becomes nullable and FK is changed to `ON DELETE SET NULL`. Non-completed rows are deleted. Completed rows are anonymized while copied metrics remain. |
| `private.challenge_sessions` | Private challenge nonces/config snapshots, `user_id` and participant refs. | Deleted for the user or their participant rows. |
| `private.challenge_configs` | Challenge config/sequence data, no direct user column. | Preserved only when its challenge remains. |
| `private.challenge_base_match_sessions` | Private completed-match base sessions, `user_id`, nonce, result/challenge refs. | Deleted for the user after breaking result refs. |
| `public.global_rankings` | View from ranked verified `game_results` joined to `profiles`. | No direct write. Deleting results/profile removes the user from the view. |

No app-owned Supabase Storage bucket, `storage.objects` policy, avatar upload, image upload, or cloud-save table was found in local migrations or Edge Functions. Cloud save in the current codebase is local/Play Games, not Supabase Storage.

## Security Model

The app calls the `delete-account` Edge Function with the current JWT. The function validates the token with Supabase Auth, checks recent Google/OAuth authentication evidence from trusted JWT claims, calls `public.validate_account_deletion_request()` with the user JWT, then calls `auth.admin.deleteUser(user.id, false)` using the service role key stored only in Edge Function environment variables.

The client never supplies the target `user_id`. The non-mutating validation RPC uses only `auth.uid()` and returns a generic request id. The actual cleanup is `private.handle_flag_game_auth_user_delete()`, a `SECURITY DEFINER` `BEFORE DELETE` trigger on `auth.users` with `SET search_path = ''`. If any cleanup statement fails, the Auth deletion transaction aborts.

## Recent Authentication Contract

The Edge Function no longer treats JWT `iat` as proof of recent login. Access tokens can be refreshed without a real Google login.

The function accepts only one of these server-issued evidences:

- `app_metadata.provider` or `app_metadata.providers` confirms Google, and `amr[]` contains method `google`, `oauth`, or `sso` with a recent timestamp.
- `app_metadata.provider` or `app_metadata.providers` confirms Google, and JWT `auth_time` is recent.

The default max age is 900 seconds through `DELETE_ACCOUNT_MAX_SESSION_AGE_SECONDS`. If the current Supabase JWT does not include reliable `amr` timestamps or `auth_time`, the backend returns `reauthentication_required`; the app must create a fresh Google/Supabase session before retrying.

## CORS Origins

Confirmed local configuration:

- `capacitor.config.json` has `server.androidScheme = "https"`, so the Android WebView origin is expected to be `https://localhost`.
- `manifest.json` has homepage URL `https://flaggameapp.github.io/flaggameapp/`, so the production website origin is `https://flaggameapp.github.io`.

Default allowed origins for the Edge Function are therefore:

- `https://localhost`
- `https://flaggameapp.github.io`

Use `DELETE_ACCOUNT_ALLOWED_ORIGINS` for staging or a future support/landing domain. Do not use `*`.

## Purchases And Entitlements

Deletion does not claim that all billing records are erased. The purpose of preserving minimal detached billing records is refund support, restore decisions, audit, and purchase-token reuse prevention.

Removed or detached:

- direct `user_id`;
- raw `purchase_token`;
- `obfuscated_account_id`;
- `raw_response`;
- current active entitlement for the deleted account.

Preserved when tables/columns exist:

- `purchase_token_hash`;
- `order_id`;
- product/package/platform;
- purchase and verification states;
- purchase, verification, revoke, create, and update timestamps;
- pseudonymous `deleted_user_hash`;
- `account_deleted_at`.

Retention length is a product/legal decision that must be confirmed before production.

## Challenge Result Compatibility

`public.get_challenge_result(uuid)` keeps the same function signature and returns `JSONB`. The participants payload still includes `participant_id`, `role`, `status`, `nickname`, `country_code`, `avatar_key`, and score metrics. For deleted participants, `nickname`, `country_code`, and `avatar_key` are `NULL`, and the new boolean `is_deleted_player` lets the app translate "deleted player" in the UI.

No JavaScript consumer of `get_challenge_result()` was found in `js/` or Android copied assets during this audit. Existing challenge flows call create/start/submit/preview/list RPCs instead.

## Validation

After applying the migration to a local or staging database, run:

```sql
\i supabase/validation/29_account_deletion_validation.sql
```

Minimum scenario tests still required:

1. Apply all migrations in a clean local database.
2. Apply migration 29 over a schema at migration 28.
3. Delete a user with no app data.
4. Delete a user with profile and ranked results.
5. Delete a user with an open created challenge.
6. Delete a user with a completed shared challenge.
7. Delete a user with supporter entitlement.
8. Delete a user with purchase data if the table exists.
9. Delete a user with Play Games identity.
10. Try unauthenticated, invalid-token, stale-session, and fresh-Google-session calls.
11. Repeat the call after success.
12. Force a trigger failure and confirm Auth deletion rolls back.
13. Confirm the other participant's challenge history and ranking data remain correct.
