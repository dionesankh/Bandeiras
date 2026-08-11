-- Validation for migration 28.
-- Run after applying 28. This file is read-only.

SELECT
  'public.game_results ranked metric columns' AS check_name,
  rc.column_name,
  rc.expected_type,
  c.data_type AS actual_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  c.column_name IS NOT NULL AS column_exists
FROM (
  VALUES
    ('ranked_session_id', 'uuid'),
    ('score', 'integer'),
    ('correct_answers', 'integer'),
    ('wrong_answers', 'integer'),
    ('skipped_answers', 'integer'),
    ('total_questions', 'integer'),
    ('elapsed_time_ms', 'integer'),
    ('best_streak', 'integer'),
    ('is_ranked', 'boolean'),
    ('verification_status', 'USER-DEFINED or text')
) AS rc(column_name, expected_type)
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'public'
 AND c.table_name = 'game_results'
 AND c.column_name = rc.column_name
ORDER BY rc.column_name;

SELECT
  'private.ranked_game_sessions mode source columns' AS check_name,
  rc.column_name,
  rc.expected_type,
  c.data_type AS actual_type,
  c.udt_name,
  c.is_nullable,
  c.column_name IS NOT NULL AS column_exists
FROM (
  VALUES
    ('id', 'uuid'),
    ('user_id', 'uuid'),
    ('mode', 'text'),
    ('variation', 'text'),
    ('question_count', 'integer'),
    ('question_codes', 'jsonb'),
    ('sequence_hash', 'text'),
    ('result_id', 'uuid'),
    ('challenge_id', 'uuid')
) AS rc(column_name, expected_type)
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'private'
 AND c.table_name = 'ranked_game_sessions'
 AND c.column_name = rc.column_name
ORDER BY rc.column_name;

SELECT
  'public.challenge_participants metric columns' AS check_name,
  rc.column_name,
  rc.expected_type,
  c.data_type AS actual_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  c.column_name IS NOT NULL AS column_exists
FROM (
  VALUES
    ('status', 'text'),
    ('correct_answers', 'integer'),
    ('wrong_answers', 'integer'),
    ('skipped_answers', 'integer'),
    ('total_questions', 'integer'),
    ('elapsed_time_ms', 'integer'),
    ('best_streak', 'integer')
) AS rc(column_name, expected_type)
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'public'
 AND c.table_name = 'challenge_participants'
 AND c.column_name = rc.column_name
ORDER BY rc.column_name;

SELECT
  'migration 28 constraints' AS check_name,
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.game_results'::regclass
      AND conname = 'game_results_ranked_metrics_complete'
      AND contype = 'c'
      AND convalidated = FALSE
  ) AS has_game_results_ranked_metrics_not_valid,
  EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.challenge_participants'::regclass
      AND conname = 'challenge_participants_completed_metrics_complete'
      AND contype = 'c'
      AND convalidated = FALSE
  ) AS has_challenge_participants_metrics_not_valid;

SELECT
  'ranked RPC signatures' AS check_name,
  to_regprocedure('public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)') IS NOT NULL AS has_submit_ranked_result,
  to_regprocedure('public.create_challenge_from_ranked_session(uuid,text)') IS NOT NULL AS has_create_challenge_from_ranked_session;

SELECT
  'ranked RPC security and search_path' AS check_name,
  p.proname,
  p.prosecdef AS security_definer,
  p.proconfig::TEXT LIKE '%search_path=%' AS has_fixed_search_path
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('submit_ranked_result', 'create_challenge_from_ranked_session')
ORDER BY p.proname;

SELECT
  'submit_ranked_result persistence safeguards' AS check_name,
  p.prosrc LIKE '%v_required_columns%' AS checks_required_columns,
  p.prosrc LIKE '%wrong_answers%' AS uses_wrong_answers,
  p.prosrc LIKE '%skipped_answers%' AS uses_skipped_answers,
  p.prosrc LIKE '%verify_persisted_result%' AS verifies_persisted_result,
  p.prosrc LIKE '%Ranked result metrics were not persisted%' AS rejects_missing_persistence
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'submit_ranked_result';

SELECT
  'create_challenge_from_ranked_session NULL-safe safeguards' AS check_name,
  p.prosrc LIKE '%Ranked result metrics are incomplete%' AS rejects_incomplete_metrics,
  p.prosrc NOT LIKE '%v_result.mode%' AS does_not_depend_on_result_mode,
  p.prosrc NOT LIKE '%v_result.variation%' AS does_not_depend_on_result_variation,
  p.prosrc LIKE '%v_ranked.mode%' AS uses_ranked_session_mode,
  p.prosrc LIKE '%v_ranked.variation%' AS uses_ranked_session_variation,
  p.prosrc LIKE '%v_result.ranked_session_id IS DISTINCT FROM v_ranked.id%' AS checks_result_session_link,
  p.prosrc LIKE '%v_result.correct_answers IS NULL%' AS checks_correct_null,
  p.prosrc LIKE '%v_result.wrong_answers IS NULL%' AS checks_wrong_null,
  p.prosrc LIKE '%v_result.skipped_answers IS NULL%' AS checks_skipped_null,
  p.prosrc LIKE '%INSERT INTO public.challenge_participants%' AS inserts_participant_after_validation
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'create_challenge_from_ranked_session';

SELECT
  'authenticated grants and anon denial' AS check_name,
  has_function_privilege('authenticated', 'public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)', 'EXECUTE') AS authenticated_can_submit_ranked,
  has_function_privilege('authenticated', 'public.create_challenge_from_ranked_session(uuid,text)', 'EXECUTE') AS authenticated_can_promote_ranked,
  NOT has_function_privilege('anon', 'public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)', 'EXECUTE') AS anon_cannot_submit_ranked,
  NOT has_function_privilege('anon', 'public.create_challenge_from_ranked_session(uuid,text)', 'EXECUTE') AS anon_cannot_promote_ranked;

SELECT
  'historical incomplete ranked results remain visible but ineligible' AS check_name,
  count(*) FILTER (
    WHERE is_ranked IS TRUE
      AND verification_status::TEXT = 'verified'
      AND (
        wrong_answers IS NULL
        OR skipped_answers IS NULL
        OR correct_answers IS NULL
        OR total_questions IS NULL
        OR ranked_session_id IS NULL
      )
  ) AS incomplete_verified_ranked_results,
  count(*) FILTER (
    WHERE is_ranked IS TRUE
      AND verification_status::TEXT = 'verified'
      AND wrong_answers IS NOT NULL
      AND skipped_answers IS NOT NULL
      AND correct_answers IS NOT NULL
      AND total_questions IS NOT NULL
      AND ranked_session_id IS NOT NULL
  ) AS complete_verified_ranked_results
FROM public.game_results;
