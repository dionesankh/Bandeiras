-- Validation for 26_promote_ranked_matches_to_challenges.sql
-- Read-only checks intended for SQL Editor after applying the migration.

WITH required_columns AS (
  SELECT unnest(ARRAY[
    'seed',
    'algorithm_version',
    'question_codes',
    'question_count',
    'sequence_hash',
    'challenge_id',
    'promotion_idempotency_key'
  ]) AS column_name
),
present_columns AS (
  SELECT column_name
  FROM information_schema.columns
  WHERE table_schema = 'private'
    AND table_name = 'ranked_game_sessions'
)
SELECT
  'ranked_game_sessions sequence/promotion columns' AS check_name,
  bool_and(pc.column_name IS NOT NULL) AS ok,
  jsonb_agg(rc.column_name ORDER BY rc.column_name) FILTER (WHERE pc.column_name IS NULL) AS missing_columns
FROM required_columns rc
LEFT JOIN present_columns pc USING (column_name);

SELECT
  'ranked promotion rpc exists' AS check_name,
  to_regprocedure('public.create_challenge_from_ranked_session(uuid,text)') IS NOT NULL AS ok;

SELECT
  'dependencies from migrations 24/25 exist' AS check_name,
  to_regclass('private.challenge_base_match_sessions') IS NOT NULL AS challenge_base_sessions,
  to_regclass('private.challenge_configs') IS NOT NULL AS challenge_configs,
  to_regprocedure('private.challenge_question_count(text,text)') IS NOT NULL AS challenge_question_count,
  to_regprocedure('private.challenge_build_question_codes(text,text,text)') IS NOT NULL AS challenge_build_question_codes,
  to_regprocedure('private.challenge_sequence_hash(text,text,jsonb,integer,text)') IS NOT NULL AS challenge_sequence_hash,
  to_regprocedure('private.challenge_validate_question_codes(text,text,jsonb)') IS NOT NULL AS challenge_validate_question_codes,
  to_regprocedure('private.challenge_public_status(uuid)') IS NOT NULL AS challenge_public_status;

SELECT
  'ranked session constraints' AS check_name,
  bool_or(conname = 'ranked_game_sessions_question_codes_array') AS has_question_codes_array_check,
  bool_or(conname = 'ranked_game_sessions_question_count_positive') AS has_question_count_positive_check,
  bool_or(conname = 'ranked_game_sessions_challenge_id_fkey') AS has_challenge_fk
FROM pg_constraint
WHERE conrelid = 'private.ranked_game_sessions'::regclass;

SELECT
  'create_ranked_session returns protected sequence source' AS check_name,
  p.prosecdef AS security_definer,
  p.proconfig::TEXT LIKE '%search_path=private, public, auth%' AS fixed_search_path,
  p.prosrc LIKE '%challenge_build_question_codes%' AS builds_backend_sequence,
  p.prosrc LIKE '%challenge_sequence_hash%' AS stores_sequence_hash,
  p.prosrc LIKE '%question_codes%' AS returns_question_codes
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'create_ranked_session'
  AND pg_get_function_identity_arguments(p.oid) = 'p_mode text, p_variation text';

SELECT
  'ranked promotion rpc validates and reuses ranked result' AS check_name,
  p.prosecdef AS security_definer,
  p.proconfig::TEXT LIKE '%search_path=public, private, auth%' AS fixed_search_path,
  p.prosrc LIKE '%challenge_validate_question_codes%' AS validates_question_codes,
  p.prosrc LIKE '%challenge_sequence_hash%' AS recomputes_sequence_hash,
  p.prosrc LIKE '%verification_status = ''verified''%' AS requires_verified_ranked_result,
  p.prosrc LIKE '%FOR UPDATE%' AS uses_row_locks,
  p.prosrc LIKE '%pg_advisory_xact_lock%' AS uses_advisory_lock,
  p.prosrc LIKE '%source'', ''ranked_match''%' AS marks_ranked_source,
  p.prosrc NOT LIKE '%p_correct%' AS does_not_accept_client_score_numbers
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'create_challenge_from_ranked_session'
  AND pg_get_function_identity_arguments(p.oid) = 'p_ranked_session_id uuid, p_idemp_key text';

SELECT
  'indexes for one promotion per ranked session/idempotency' AS check_name,
  to_regclass('private.idx_ranked_sessions_challenge_id') IS NOT NULL AS has_challenge_index,
  to_regclass('private.idx_ranked_sessions_promotion_idempotency') IS NOT NULL AS has_idempotency_index;

SELECT
  'authenticated execute grants' AS check_name,
  has_function_privilege('authenticated', 'public.create_ranked_session(text,text)', 'EXECUTE') AS create_ranked_session,
  has_function_privilege('authenticated', 'public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)', 'EXECUTE') AS submit_ranked_result,
  has_function_privilege('authenticated', 'public.create_challenge_from_ranked_session(uuid,text)', 'EXECUTE') AS create_from_ranked;

SELECT
  'anon/public do not execute ranked promotion rpcs' AS check_name,
  NOT has_function_privilege('anon', 'public.create_challenge_from_ranked_session(uuid,text)', 'EXECUTE') AS anon_no_create_from_ranked,
  NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) AS acl
    WHERE n.nspname = 'public'
      AND p.proname = 'create_challenge_from_ranked_session'
      AND pg_get_function_identity_arguments(p.oid) = 'p_ranked_session_id uuid, p_idemp_key text'
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ) AS public_no_create_from_ranked;

SELECT
  'private helper functions not executable by app roles' AS check_name,
  NOT has_function_privilege('anon', 'private.challenge_build_question_codes(text,text,text)', 'EXECUTE') AS anon_no_build_sequence,
  NOT has_function_privilege('authenticated', 'private.challenge_build_question_codes(text,text,text)', 'EXECUTE') AS auth_no_build_sequence,
  NOT has_function_privilege('anon', 'private.challenge_sequence_hash(text,text,jsonb,integer,text)', 'EXECUTE') AS anon_no_hash,
  NOT has_function_privilege('authenticated', 'private.challenge_sequence_hash(text,text,jsonb,integer,text)', 'EXECUTE') AS auth_no_hash;

SELECT
  'private tables not directly exposed to authenticated' AS check_name,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'INSERT') AS auth_no_ranked_insert,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'UPDATE') AS auth_no_ranked_update,
  NOT has_table_privilege('authenticated', 'private.challenge_configs', 'SELECT') AS auth_no_challenge_config_select;
