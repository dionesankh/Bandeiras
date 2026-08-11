-- Validation for migration 23: direct player challenges backend.
-- Run after reviewing and applying supabase/migrations/23_prepare_player_challenges_backend.sql.
-- This file is split into preflight checks, post-migration inspection queries,
-- and commented manual tests.

-- ============================================================
-- Preflight checks
-- Run before applying migration 23. These queries should not change data.
-- ============================================================

-- P1. Existing duplicate challenge codes. Expected before migration: zero rows.
-- If this returns rows, idx_challenges_code_unique would fail and the duplicates
-- must be resolved manually before applying migration 23.
SELECT
  code,
  count(*) AS duplicate_count,
  array_agg(id ORDER BY created_at NULLS LAST) AS challenge_ids
FROM public.challenges
GROUP BY code
HAVING count(*) > 1
ORDER BY duplicate_count DESC, code;

-- P2. Existing invalid challenge codes. Expected: zero rows.
SELECT
  id,
  code
FROM public.challenges
WHERE code IS NULL
   OR code !~ '^FG-[A-Z2-9]{8}$'
LIMIT 20;

-- P3. verification_status_t must support pending. Expected: pending_exists = true.
SELECT EXISTS (
  SELECT 1
  FROM pg_type t
  JOIN pg_enum e ON e.enumtypid = t.oid
  WHERE t.typname = 'verification_status_t'
    AND e.enumlabel = 'pending'
) AS pending_exists;

-- P4. public.game_results RLS state before migration.
-- Migration 23 enables it explicitly; this shows the remote starting point.
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'game_results';

-- P5. anon/authenticated must not have CREATE on public schema.
-- Migration 23 revokes CREATE explicitly; before migration this should ideally
-- already be false.
SELECT
  r.rolname AS grantee,
  has_schema_privilege(r.rolname, 'public', 'CREATE') AS can_create_in_public_schema
FROM pg_roles r
WHERE r.rolname IN ('anon', 'authenticated')
ORDER BY r.rolname;

-- ============================================================
-- Post-migration safe inspection queries
-- Run after applying migration 23. These queries should not change data.
-- ============================================================

-- 1. Expected challenge-related tables.
SELECT
  table_schema,
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema IN ('public', 'private')
  AND table_name IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions',
    'game_results',
    'profiles'
  )
ORDER BY table_schema, table_name;

-- Expected: public.challenges, public.challenge_participants,
-- private.challenge_configs, private.challenge_sessions, public.game_results,
-- public.profiles.

-- 2. Columns and defaults.
SELECT
  table_schema,
  table_name,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema IN ('public', 'private')
  AND table_name IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions',
    'game_results',
    'profiles'
  )
ORDER BY table_schema, table_name, ordinal_position;

-- Expected highlights:
-- public.challenges has config, rules_version, allow_hearts, cancelled_at.
-- public.challenge_participants has role, status, result_id, event_id and result metrics.
-- private.challenge_configs has seed, algorithm_version, question_codes and scoring.
-- private.challenge_sessions has session_nonce_hash, config_snapshot, status and expires_at.
-- public.game_results is used by RPCs only; challenge results must use is_ranked=false.

-- 3. Constraints.
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  con.conname,
  con.contype,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'private')
  AND c.relname IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions'
  )
ORDER BY n.nspname, c.relname, con.conname;

-- Expected: primary keys, FKs to auth.users/game_results/challenges,
-- challenge_participants_unique_user, role/status/math checks,
-- challenge_configs_question_codes_array.

-- 4. Indexes, including partial unique indexes.
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname IN ('public', 'private')
  AND tablename IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions'
  )
ORDER BY schemaname, tablename, indexname;

-- Expected: challenge_participants_one_creator,
-- challenge_participants_one_opponent, idx_challenge_participants_event,
-- idx_challenge_participants_result, idx_challenge_sessions_one_created_per_participant,
-- idx_challenges_creator_idempotency, idx_challenges_code_unique.

WITH expected_indexes(indexname) AS (
  VALUES
    ('challenge_participants_one_creator'),
    ('challenge_participants_one_opponent'),
    ('idx_challenge_participants_event'),
    ('idx_challenge_participants_result'),
    ('idx_challenge_sessions_one_created_per_participant'),
    ('idx_challenges_code_unique'),
    ('idx_challenges_creator_idempotency')
)
SELECT
  e.indexname,
  i.schemaname,
  i.tablename,
  i.indexdef,
  i.indexname IS NOT NULL AS exists
FROM expected_indexes e
LEFT JOIN pg_indexes i ON i.indexname = e.indexname
ORDER BY e.indexname;

-- Expected: every exists column is true.

-- 5. Enums related to challenges and verification.
SELECT
  t.typname,
  e.enumlabel
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typname IN (
  'challenge_status_t',
  'session_status_t',
  'verification_status_t'
)
ORDER BY t.typname, e.enumsortorder;

-- Expected: existing remote enums are reused; no duplicate challenge enum is created.
-- verification_status_t must include pending because challenge result totals are
-- consistency-checked but not answer-verified.
SELECT EXISTS (
  SELECT 1
  FROM pg_type t
  JOIN pg_enum e ON e.enumtypid = t.oid
  WHERE t.typname = 'verification_status_t'
    AND e.enumlabel = 'pending'
) AS verification_status_pending_exists;

-- Expected: verification_status_pending_exists = true.

-- 5b. Canonical question counts, including continent mode.
SELECT
  private.challenge_question_count('world', '10') AS world_10_count,
  private.challenge_question_count('world', '20') AS world_20_count,
  private.challenge_question_count('world', '50') AS world_50_count,
  private.challenge_question_count('world', '195') AS world_195_count,
  private.challenge_question_count('continent', 'south-america') AS south_america_count,
  private.challenge_question_count('continent', 'north-america') AS north_america_count,
  private.challenge_question_count('continent', 'europe') AS europe_count,
  private.challenge_question_count('continent', 'africa') AS africa_count,
  private.challenge_question_count('continent', 'asia') AS asia_count,
  private.challenge_question_count('continent', 'oceania') AS oceania_count;

-- Expected: 10, 20, 50, 195, 12, 23, 44, 54, 48, 14. No NULL values.

-- 6. RLS state.
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname IN ('public', 'private')
  AND tablename IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions',
    'game_results'
  )
ORDER BY schemaname, tablename;

-- Expected: rowsecurity = true for challenge tables and game_results.

-- 7. Policies.
SELECT
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname IN ('public', 'private')
  AND tablename IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions',
    'game_results'
  )
ORDER BY schemaname, tablename, policyname;

-- Expected: no broad public challenge policies. Direct access is revoked;
-- public.challenge_participants/private.challenge_sessions may only expose own rows if grants exist.

-- 8. Table grants.
SELECT
  grantee,
  table_schema,
  table_name,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_schema IN ('public', 'private')
  AND table_name IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions',
    'game_results'
  )
  AND grantee IN ('anon', 'authenticated', 'service_role')
ORDER BY table_schema, table_name, grantee, privilege_type;

-- Expected: service_role may appear. anon/authenticated should have no direct grants
-- on challenges, challenge_participants, challenge_configs, challenge_sessions,
-- or game_results.

-- 9. Dangerous direct grants. Expected result: zero rows.
SELECT
  grantee,
  table_schema,
  table_name,
  privilege_type
FROM information_schema.role_table_grants
WHERE table_schema IN ('public', 'private')
  AND table_name IN (
    'challenges',
    'challenge_participants',
    'challenge_configs',
    'challenge_sessions',
    'game_results'
  )
  AND grantee IN ('anon', 'authenticated')
  AND privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER');

-- 10. Private schema exposure. Expected: can_use_private_schema = false.
SELECT
  r.rolname AS grantee,
  has_schema_privilege(r.rolname, 'private', 'USAGE') AS can_use_private_schema,
  has_schema_privilege(r.rolname, 'private', 'CREATE') AS can_create_in_private_schema
FROM pg_roles r
WHERE r.rolname IN ('anon', 'authenticated')
ORDER BY r.rolname;

-- 10b. Public schema CREATE privilege. Expected: can_create_in_public_schema = false.
SELECT
  r.rolname AS grantee,
  has_schema_privilege(r.rolname, 'public', 'CREATE') AS can_create_in_public_schema
FROM pg_roles r
WHERE r.rolname IN ('anon', 'authenticated')
ORDER BY r.rolname;

-- 11. RPC signatures, security definer, and search_path.
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  pg_get_function_result(p.oid) AS returns,
  p.prosecdef AS security_definer,
  p.proconfig AS config
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'private')
  AND p.proname IN (
    'normalize_challenge_code',
    'generate_challenge_code',
    'challenge_question_count',
    'challenge_public_status',
    'challenge_winner_payload',
    'get_daily_challenge_quota',
    'create_challenge',
    'get_challenge_preview',
    'accept_challenge',
    'start_challenge_session',
    'submit_challenge_result',
    'cancel_challenge',
    'get_challenge_result',
    'list_my_challenges'
  )
ORDER BY schema_name, function_name, arguments;

-- Expected: public RPCs are SECURITY DEFINER and use a fixed search_path.
-- Private helpers are not executable by anon/authenticated.

-- 12. RPC execute grants.
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  r.rolname AS grantee,
  has_function_privilege(r.rolname, p.oid, 'EXECUTE') AS can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN pg_roles r
WHERE n.nspname IN ('public', 'private')
  AND r.rolname IN ('anon', 'authenticated', 'service_role')
  AND p.proname IN (
    'normalize_challenge_code',
    'generate_challenge_code',
    'challenge_question_count',
    'challenge_public_status',
    'challenge_winner_payload',
    'get_daily_challenge_quota',
    'create_challenge',
    'get_challenge_preview',
    'accept_challenge',
    'start_challenge_session',
    'submit_challenge_result',
    'cancel_challenge',
    'get_challenge_result',
    'list_my_challenges'
  )
ORDER BY schema_name, function_name, arguments, grantee;

-- Expected: authenticated can execute public app RPCs. anon cannot execute protected RPCs.
-- Private helpers should be false for anon/authenticated.

-- 13. Active signatures per app RPC.
WITH expected_rpc(function_name) AS (
  VALUES
    ('get_daily_challenge_quota'),
    ('create_challenge'),
    ('get_challenge_preview'),
    ('accept_challenge'),
    ('start_challenge_session'),
    ('submit_challenge_result'),
    ('cancel_challenge'),
    ('get_challenge_result'),
    ('list_my_challenges')
),
actual_rpc AS (
  SELECT
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (SELECT function_name FROM expected_rpc)
)
SELECT
  e.function_name,
  count(a.arguments) AS overload_count,
  COALESCE(jsonb_agg(a.arguments ORDER BY a.arguments) FILTER (WHERE a.arguments IS NOT NULL), '[]'::jsonb) AS signatures
FROM expected_rpc e
LEFT JOIN actual_rpc a ON a.function_name = e.function_name
GROUP BY e.function_name
ORDER BY e.function_name;

-- Expected: overload_count = 1 for every listed RPC.

-- 14. Deprecated submit_challenge_result UUID signature. Expected: false.
SELECT to_regprocedure(
  'public.submit_challenge_result(uuid,text,integer,integer,integer,integer,integer,integer)'
) IS NOT NULL AS deprecated_uuid_signature_exists;

-- 15. Public config must not contain private seed/scoring. Expected: zero rows.
SELECT
  id,
  code
FROM public.challenges
WHERE config ? 'seed'
   OR config ? 'scoring'
   OR config ? 'question_codes'
   OR config ? 'algorithm_version'
LIMIT 20;

-- 16. Challenge code format. Expected: zero rows.
SELECT
  id,
  code
FROM public.challenges
WHERE code !~ '^FG-[A-Z2-9]{8}$'
LIMIT 20;

-- 17. global_rankings still resolves and can be queried.
SELECT to_regclass('public.global_rankings') AS global_rankings_object;

SELECT count(*) AS global_rankings_visible_rows
FROM public.global_rankings;

-- 18. Migration/function body expectations. Expected: all boolean columns = true.
SELECT
  to_regclass('private.challenge_configs') IS NOT NULL
    AS database_has_private_configs,
  position('ON CONFLICT (creator_id, idempotency_key)' in pg_get_functiondef('public.create_challenge(text,text,text)'::regprocedure)) > 0
    AS create_handles_idempotency_conflict,
  position('length(v_idemp_key) < 8 OR length(v_idemp_key) > 128' in pg_get_functiondef('public.create_challenge(text,text,text)'::regprocedure)) > 0
    AS create_limits_idempotency_key_size,
  position('''seed''' in pg_get_functiondef('public.create_challenge(text,text,text)'::regprocedure)) = 0
    AS create_response_does_not_include_seed_key,
  position('''scoring''' in pg_get_functiondef('public.create_challenge(text,text,text)'::regprocedure)) = 0
    AS create_response_does_not_include_scoring_key,
  position('''seed''' in pg_get_functiondef('public.get_challenge_preview(text)'::regprocedure)) = 0
    AS preview_response_does_not_include_seed_key,
  position('''scoring''' in pg_get_functiondef('public.get_challenge_preview(text)'::regprocedure)) = 0
    AS preview_response_does_not_include_scoring_key,
  position('''seed''' in pg_get_functiondef('public.accept_challenge(text)'::regprocedure)) = 0
    AS accept_response_does_not_include_seed_key,
  position('''scoring''' in pg_get_functiondef('public.accept_challenge(text)'::regprocedure)) = 0
    AS accept_response_does_not_include_scoring_key,
  position('FOR UPDATE' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure)) > 0
    AS start_uses_for_update,
  position('FROM public.challenges' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure)) > 0
    AND position('FROM public.challenges' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure))
      < position('FOR UPDATE' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure))
    AS start_locks_challenge,
  position('FROM public.challenge_participants' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure)) > 0
    AND position('FROM public.challenge_participants' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure))
      < position('UPDATE private.challenge_sessions' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure))
    AS start_locks_participant,
  position('SELECT
        id,
        challenge_id,
        participant_id' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_initial_session_read_only_identifiers,
  position('FROM public.challenges' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AND position('FROM public.challenges' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure))
      < position('FROM public.challenge_participants' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure))
    AS submit_locks_challenge,
  position('FROM public.challenge_participants' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AND position('FROM public.challenge_participants' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure))
      < position('WHERE id = v_session.id' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure))
    AS submit_locks_participant,
  position('WHERE id = v_session.id' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AND position('WHERE id = v_session.id' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure))
      < position('IF v_session.expires_at < NOW()' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure))
    AS submit_locks_session,
  position('SET status = ''expired''' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) = 0
    AS submit_does_not_update_expired_before_exception,
  position('length(v_event_id) < 8 OR length(v_event_id) > 128' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_limits_event_id_size,
  position('p_correct > p_total' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_rejects_correct_above_total,
  position('p_wrong > p_total' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_rejects_wrong_above_total,
  position('p_skipped > p_total' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_rejects_skipped_above_total,
  position('p_streak > p_correct' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_rejects_streak_above_correct,
  position('p_time_ms <= 0' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_rejects_non_positive_time,
  position('p_time_ms > 1800000' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_rejects_over_30_minutes,
  position('v_accuracy < 0 OR v_accuracy > 100' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS submit_bounds_accuracy,
  position('''pending''' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) > 0
    AS challenge_result_uses_pending_verification,
  position('''verified''' in pg_get_functiondef('public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)'::regprocedure)) = 0
    AS challenge_result_does_not_claim_verified,
  position('v_client_config := v_config_snapshot - ''question_codes'' - ''scoring''' in pg_get_functiondef('public.start_challenge_session(text)'::regprocedure)) > 0
    AS start_removes_question_codes_and_scoring_from_response;

-- 19. Public challenge config keys currently present.
-- Expected: no private keys. Public keys may include mode, variation, question_count,
-- rules_version and allow_hearts.
SELECT DISTINCT jsonb_object_keys(config) AS public_config_key
FROM public.challenges
ORDER BY public_config_key;

-- 20. Private challenge configs must always have a positive question_count.
-- Expected result: zero rows.
SELECT
  challenge_id,
  question_count
FROM private.challenge_configs
WHERE question_count IS NULL
   OR question_count <= 0
LIMIT 20;

-- ============================================================
-- Tests that require an authenticated user
-- Do not fake auth.uid() in production.
-- Run these through the app or an authenticated API client.
-- ============================================================

-- A. As authenticated user A:
-- SELECT public.get_daily_challenge_quota();
-- SELECT public.create_challenge('world', '10', 'manual-idempotency-key-user-a-001');
-- Expected: returns code FG-XXXXXXXX, challenge_id, remaining_daily, no seed.

-- B. As authenticated user A:
-- SELECT public.get_challenge_preview('<CODE_FROM_A>');
-- Expected: returns creator public profile, mode/variation/question_count, no seed/scoring.

-- C. As authenticated user B:
-- SELECT public.accept_challenge('<CODE_FROM_A>');
-- SELECT public.start_challenge_session('<CODE_FROM_A>');
-- Expected: accept returns participant_id only; start returns nonce and authorized config.
-- The returned config may include seed for the authorized participant, but not question_codes/scoring.

-- D. As authenticated user B:
-- SELECT public.submit_challenge_result('<NONCE_FROM_START>', 'manual-event-b-001', 7, 3, 0, 10, 45000, 4);
-- Expected: creates public.game_results with is_ranked=false and verification_status='pending',
-- links result_id to public.challenge_participants, and does not affect global_rankings.

-- E. As authenticated creator A before an opponent accepts:
-- SELECT public.cancel_challenge('<CODE_FROM_A>');
-- Expected: status cancelled. After an opponent exists, expected error: Challenge already accepted.

-- ============================================================
-- Transactional tests
-- Use only in a safe authenticated SQL/API context. The SQL Editor as postgres
-- does not provide auth.uid(), so these are intentionally commented.
-- ============================================================

-- BEGIN;
-- SELECT public.create_challenge('world', '10', 'tx-idempotency-key-user-a-001') AS created;
-- SELECT public.get_daily_challenge_quota() AS quota_after_create;
-- ROLLBACK;
-- Expected: challenge creation would succeed for authenticated user,
-- and rollback removes test data.

-- BEGIN;
-- SELECT public.cancel_challenge('<UNACCEPTED_CODE>') AS cancelled;
-- ROLLBACK;
-- Expected: cancel would succeed only for creator and only before opponent acceptance.
