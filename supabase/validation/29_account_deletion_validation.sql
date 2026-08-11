-- Validation for migration 29.
-- Read-only: run after applying 29 to a local/staging database.

SELECT
  'nullable account links after migration 29' AS check_name,
  c.table_schema,
  c.table_name,
  c.column_name,
  c.data_type,
  c.is_nullable
FROM information_schema.columns c
WHERE (c.table_schema, c.table_name, c.column_name) IN (
  ('public', 'challenges', 'creator_id'),
  ('public', 'challenge_participants', 'user_id'),
  ('private', 'supporter_entitlements', 'user_id'),
  ('private', 'purchases', 'user_id'),
  ('private', 'purchases', 'purchase_token')
)
ORDER BY c.table_schema, c.table_name, c.column_name;

SELECT
  'account deletion foreign keys' AS check_name,
  con.conname,
  con.conrelid::regclass AS table_name,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
WHERE con.conname IN (
  'challenges_creator_id_fkey',
  'challenge_participants_user_id_fkey',
  'supporter_entitlements_user_id_fkey',
  'purchases_user_id_fkey'
)
ORDER BY con.conname;

SELECT
  'billing retention columns' AS check_name,
  c.table_schema,
  c.table_name,
  c.column_name,
  c.data_type,
  c.is_nullable
FROM information_schema.columns c
WHERE (c.table_schema, c.table_name, c.column_name) IN (
  ('private', 'supporter_entitlements', 'deleted_user_hash'),
  ('private', 'supporter_entitlements', 'account_deleted_at'),
  ('private', 'supporter_entitlements', 'revocation_reason'),
  ('private', 'supporter_entitlements', 'revoked_at'),
  ('private', 'purchases', 'deleted_user_hash'),
  ('private', 'purchases', 'account_deleted_at')
)
ORDER BY c.table_schema, c.table_name, c.column_name;

SELECT
  'account deletion functions' AS check_name,
  n.nspname AS schema_name,
  p.proname,
  p.prosecdef AS security_definer,
  COALESCE(array_to_string(p.proconfig, ','), '') LIKE '%search_path=%' AS has_controlled_search_path,
  COALESCE(array_to_string(p.proconfig, ','), '') AS function_config
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE (n.nspname, p.proname) IN (
  ('public', 'validate_account_deletion_request'),
  ('public', 'get_challenge_result'),
  ('private', 'handle_flag_game_auth_user_delete')
)
ORDER BY n.nspname, p.proname;

SELECT
  'auth delete trigger' AS check_name,
  t.tgname,
  t.tgenabled,
  t.tgrelid::regclass AS table_name,
  p.proname AS function_name,
  pg_get_triggerdef(t.oid, true) LIKE '%BEFORE DELETE%' AS is_before_delete
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE t.tgname = 'flag_game_before_auth_user_delete';

SELECT
  'account deletion grants' AS check_name,
  has_function_privilege('authenticated', 'public.validate_account_deletion_request()', 'EXECUTE') AS authenticated_can_validate_request,
  NOT has_function_privilege('anon', 'public.validate_account_deletion_request()', 'EXECUTE') AS anon_cannot_validate_request,
  NOT has_function_privilege('authenticated', 'private.handle_flag_game_auth_user_delete()', 'EXECUTE') AS authenticated_cannot_run_trigger_function,
  has_function_privilege('service_role', 'private.handle_flag_game_auth_user_delete()', 'EXECUTE') AS service_role_can_run_trigger_function;

SELECT
  'challenge result anonymized participants support' AS check_name,
  p.prosrc LIKE '%LEFT JOIN public.profiles%' AS uses_left_join_profiles,
  p.prosrc LIKE '%is_deleted_player%' AS has_deleted_player_flag,
  p.prosrc NOT LIKE '%Deleted player%' AS has_no_hardcoded_deleted_player_label,
  p.prosrc NOT LIKE '%user_id''%' AS does_not_return_user_id_key
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'get_challenge_result';

SELECT
  'deleted account absence from ranking view' AS check_name,
  pg_get_viewdef('public.global_rankings'::regclass, true) LIKE '%JOIN public.profiles%' AS ranking_requires_profile_join,
  pg_get_viewdef('public.global_rankings'::regclass, true) LIKE '%public.game_results%' AS ranking_uses_game_results;

SELECT
  'storage references in database' AS check_name,
  to_regclass('storage.objects') IS NOT NULL AS storage_objects_table_exists,
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_depend d
    JOIN pg_catalog.pg_class c ON c.oid = d.objid
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE d.refobjid = COALESCE(to_regclass('storage.objects')::oid, 0::oid)
      AND n.nspname IN ('public', 'private')
  ) AS app_objects_depend_on_storage_objects;
