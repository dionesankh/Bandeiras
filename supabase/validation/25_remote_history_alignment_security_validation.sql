-- Read-only validation for 25_remote_history_alignment_security.sql
--
-- Run after applying migration 25. These statements are intended for SQL Editor
-- review and do not modify persistent data.

-- 1. Table/view grants expected after migration 25.
SELECT
    table_schema,
    table_name,
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_schema IN ('public', 'private')
  AND table_name IN (
      'profiles',
      'supporter_status',
      'challenges',
      'challenge_participants',
      'game_results',
      'global_rankings',
      'supporter_entitlements',
      'ranked_game_sessions',
      'challenge_configs',
      'challenge_sessions',
      'challenge_base_match_sessions'
  )
  AND grantee IN ('PUBLIC', 'anon', 'authenticated', 'service_role')
ORDER BY table_schema, table_name, grantee, privilege_type;

-- 2. public.profiles RLS policies. Expected:
-- profiles_select_own: SELECT, roles authenticated, qual auth.uid() = id.
-- profiles_update_own: UPDATE, roles authenticated, qual/check auth.uid() = id.
SELECT
    schemaname,
    tablename,
    policyname,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'profiles'
ORDER BY policyname;

-- 3. Confirm no direct anon/authenticated grants remain on public.supporter_status.
SELECT
    COUNT(*) FILTER (WHERE grantee = 'anon') AS anon_grants,
    COUNT(*) FILTER (WHERE grantee = 'authenticated') AS authenticated_grants
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name = 'supporter_status'
  AND grantee IN ('anon', 'authenticated');

-- 4. Function signatures, SECURITY DEFINER flag, and search_path.
SELECT
    n.nspname AS schema,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS args,
    pg_get_function_result(p.oid) AS result_type,
    p.prosecdef AS security_definer,
    p.proconfig AS function_config
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'private')
  AND p.proname IN (
      'get_public_profile',
      'get_supporter_profile_details',
      'submit_ranked_result',
      'create_ranked_session',
      'normalize_challenge_code',
      'create_challenge',
      'get_daily_challenge_quota',
      'get_challenge_preview',
      'accept_challenge',
      'start_challenge_session',
      'submit_challenge_result',
      'cancel_challenge',
      'get_challenge_result',
      'list_my_challenges',
      'start_challenge_base_match',
      'create_challenge_from_completed_match',
      'challenge_country_catalog',
      'challenge_build_question_codes',
      'challenge_sequence_hash',
      'challenge_validate_question_codes'
  )
ORDER BY schema, function_name, args;

-- 5. Function grants expected after migration 25.
SELECT
    routine_schema,
    routine_name,
    grantee,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema IN ('public', 'private')
  AND routine_name IN (
      'get_public_profile',
      'get_supporter_profile_details',
      'submit_ranked_result',
      'create_ranked_session',
      'normalize_challenge_code',
      'create_challenge',
      'get_daily_challenge_quota',
      'get_challenge_preview',
      'accept_challenge',
      'start_challenge_session',
      'submit_challenge_result',
      'cancel_challenge',
      'get_challenge_result',
      'list_my_challenges',
      'start_challenge_base_match',
      'create_challenge_from_completed_match',
      'challenge_country_catalog',
      'challenge_build_question_codes',
      'challenge_sequence_hash',
      'challenge_validate_question_codes'
  )
  AND grantee IN ('PUBLIC', 'anon', 'authenticated', 'service_role')
ORDER BY routine_schema, routine_name, grantee;

-- 6. Static check: submit_ranked_result must not update expired status before raising.
SELECT
    strpos(pg_get_functiondef(p.oid), 'SET status = ''expired''') AS expired_update_position,
    strpos(pg_get_functiondef(p.oid), 'Session expired') AS session_expired_position,
    (
      strpos(pg_get_functiondef(p.oid), 'SET status = ''expired''') = 0
      AND strpos(pg_get_functiondef(p.oid), 'Session expired') > 0
    ) AS expiration_flow_ok
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'submit_ranked_result'
  AND pg_get_function_identity_arguments(p.oid) =
      'p_nonce text, p_event_id text, p_correct integer, p_wrong integer, p_skipped integer, p_total integer, p_time_ms integer, p_streak integer';

-- 7. Static check: SECURITY DEFINER functions must have fixed search_path.
SELECT
    n.nspname AS schema,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS args,
    p.prosecdef AS security_definer,
    p.proconfig AS function_config,
    EXISTS (
        SELECT 1
        FROM unnest(COALESCE(p.proconfig, ARRAY[]::text[])) c
        WHERE c LIKE 'search_path=%'
    ) AS has_fixed_search_path
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'private')
  AND p.prosecdef = true
ORDER BY schema, function_name, args;

-- 8. Read-only smoke check for get_public_profile against an existing profile.
-- Expected: returns NULL if there are no profiles, otherwise a JSON object.
SELECT public.get_public_profile((
    SELECT id
    FROM public.profiles
    ORDER BY created_at NULLS LAST, id
    LIMIT 1
)) AS sample_public_profile;

-- 9. Static check for get_supporter_profile_details because calling it requires
-- an authenticated JWT context. Expected: uses auth.uid() and returns jsonb.
SELECT
    strpos(pg_get_functiondef(p.oid), 'auth.uid()') > 0 AS uses_auth_uid,
    pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'get_supporter_profile_details'
  AND pg_get_function_identity_arguments(p.oid) = 'p_target_user_id uuid';

-- 10. Objects from migrations 23 and 24.
SELECT
    to_regclass('public.challenges') IS NOT NULL AS has_challenges,
    to_regclass('public.challenge_participants') IS NOT NULL AS has_challenge_participants,
    to_regclass('private.challenge_configs') IS NOT NULL AS has_challenge_configs,
    to_regclass('private.challenge_sessions') IS NOT NULL AS has_challenge_sessions,
    to_regclass('private.challenge_base_match_sessions') IS NOT NULL AS has_challenge_base_match_sessions,
    to_regprocedure('public.start_challenge_base_match(text,text)') IS NOT NULL AS has_start_challenge_base_match,
    to_regprocedure('public.create_challenge_from_completed_match(text,text,integer,integer,integer,integer,integer,integer,text)') IS NOT NULL AS has_create_challenge_from_completed_match,
    to_regprocedure('public.start_challenge_session(text)') IS NOT NULL AS has_start_challenge_session;

-- 11. Required challenge sequence columns.
SELECT
    table_schema,
    table_name,
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE (table_schema, table_name, column_name) IN (
    ('private', 'challenge_configs', 'question_codes'),
    ('private', 'challenge_configs', 'sequence_hash'),
    ('private', 'challenge_configs', 'base_match_id'),
    ('private', 'challenge_base_match_sessions', 'question_codes'),
    ('private', 'challenge_base_match_sessions', 'sequence_hash')
)
ORDER BY table_schema, table_name, column_name;

-- 12. Non-read-only functional tests that must be performed separately:
-- - submit_ranked_result, because it inserts into public.game_results and updates
--   private.ranked_game_sessions.
-- - full two-account challenge flow, because it creates/updates challenge data.
