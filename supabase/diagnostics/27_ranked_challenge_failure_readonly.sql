-- Read-only diagnostic for ranked match -> friend challenge failures.
-- Run in Supabase SQL Editor after reproducing the issue.
-- This script intentionally performs only SELECT statements.
-- It does not expose JWTs, nonces, access keys, or raw question_codes.

SELECT
  'migration 27 ranked session contract columns' AS check_name,
  rc.column_name,
  rc.expected_type,
  c.data_type AS actual_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  c.column_name IS NOT NULL AS column_exists
FROM (
  VALUES
    ('rules_version', 'integer'),
    ('seed', 'text'),
    ('algorithm_version', 'text'),
    ('question_codes', 'jsonb'),
    ('question_count', 'integer'),
    ('sequence_hash', 'text'),
    ('allow_hearts', 'boolean'),
    ('challenge_id', 'uuid'),
    ('promotion_idempotency_key', 'text'),
    ('started_at', 'timestamp with time zone'),
    ('expires_at', 'timestamp with time zone'),
    ('completed_at', 'timestamp with time zone'),
    ('result_id', 'uuid'),
    ('created_at', 'timestamp with time zone'),
    ('status', 'USER-DEFINED or text')
) AS rc(column_name, expected_type)
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'private'
 AND c.table_name = 'ranked_game_sessions'
 AND c.column_name = rc.column_name
ORDER BY rc.column_name;

WITH rpc_contract AS (
  SELECT
    to_regprocedure('public.create_ranked_session(text,text)') AS create_ranked_session,
    to_regprocedure('public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)') AS submit_ranked_result,
    to_regprocedure('public.create_challenge_from_ranked_session(uuid,text)') AS create_challenge_from_ranked_session
)
SELECT
  'ranked challenge RPC contract' AS check_name,
  create_ranked_session IS NOT NULL AS has_create_ranked_session,
  submit_ranked_result IS NOT NULL AS has_submit_ranked_result,
  create_challenge_from_ranked_session IS NOT NULL AS has_create_challenge_from_ranked_session,
  COALESCE(has_function_privilege('authenticated', create_challenge_from_ranked_session, 'EXECUTE'), FALSE) AS authenticated_can_execute_promote,
  NOT COALESCE(has_function_privilege('anon', create_challenge_from_ranked_session, 'EXECUTE'), FALSE) AS anon_cannot_execute_promote
FROM rpc_contract;

WITH recent_sessions AS (
  SELECT
    s.id,
    s.user_id,
    to_jsonb(s) AS row_data
  FROM private.ranked_game_sessions s
  ORDER BY
    COALESCE(
      NULLIF(to_jsonb(s)->>'created_at', '')::timestamptz,
      NULLIF(to_jsonb(s)->>'started_at', '')::timestamptz,
      NULLIF(to_jsonb(s)->>'completed_at', '')::timestamptz
    ) DESC NULLS LAST
  LIMIT 10
),
recent_results AS (
  SELECT
    r.id,
    r.user_id,
    to_jsonb(r) AS row_data
  FROM public.game_results r
  WHERE COALESCE(to_jsonb(r)->>'ranked_session_id', '') <> ''
  ORDER BY
    COALESCE(
      NULLIF(to_jsonb(r)->>'created_at', '')::timestamptz,
      NULLIF(to_jsonb(r)->>'received_at', '')::timestamptz
    ) DESC NULLS LAST
  LIMIT 50
)
SELECT
  'recent ranked session state' AS check_name,
  rs.id AS ranked_session_id,
  rs.user_id AS session_user_id,
  rs.row_data->>'mode' AS mode,
  rs.row_data->>'variation' AS variation,
  rs.row_data->>'status' AS session_status,
  rs.row_data->>'rules_version' AS rules_version,
  rs.row_data->>'question_count' AS session_question_count,
  CASE
    WHEN jsonb_typeof(rs.row_data->'question_codes') = 'array'
      THEN jsonb_array_length(rs.row_data->'question_codes')
    ELSE NULL
  END AS question_codes_count,
  rs.row_data ? 'question_codes' AS has_question_codes_column_value,
  NULLIF(rs.row_data->>'sequence_hash', '') IS NOT NULL AS has_sequence_hash,
  NULLIF(rs.row_data->>'seed', '') IS NOT NULL AS has_seed,
  NULLIF(rs.row_data->>'result_id', '') IS NOT NULL AS has_session_result_id,
  rs.row_data->>'result_id' AS session_result_id,
  NULLIF(rs.row_data->>'challenge_id', '') IS NOT NULL AS has_challenge_id,
  rs.row_data->>'challenge_id' AS challenge_id,
  rs.row_data->>'promotion_idempotency_key' AS promotion_idempotency_key,
  rs.row_data->>'started_at' AS started_at,
  rs.row_data->>'completed_at' AS completed_at,
  rr.id AS result_id,
  rr.user_id AS result_user_id,
  rr.row_data->>'ranked_session_id' AS result_ranked_session_id,
  rr.row_data->>'is_ranked' AS result_is_ranked,
  rr.row_data->>'verification_status' AS result_verification_status,
  rr.row_data->>'total_questions' AS result_total_questions,
  rr.row_data->>'correct_answers' AS result_correct_answers,
  rr.row_data->>'wrong_answers' AS result_wrong_answers,
  rr.row_data->>'skipped_answers' AS result_skipped_answers,
  rr.row_data->>'event_id' AS result_event_id,
  rr.row_data->>'created_at' AS result_created_at,
  (
    rr.id IS NOT NULL
    AND rr.user_id = rs.user_id
    AND rr.row_data->>'ranked_session_id' = rs.id::text
  ) AS result_linked_to_same_session_and_user
FROM recent_sessions rs
LEFT JOIN recent_results rr
  ON rr.row_data->>'ranked_session_id' = rs.id::text
  OR rr.id::text = rs.row_data->>'result_id'
ORDER BY
  COALESCE(
    NULLIF(rs.row_data->>'created_at', '')::timestamptz,
    NULLIF(rs.row_data->>'started_at', '')::timestamptz,
    NULLIF(rs.row_data->>'completed_at', '')::timestamptz
  ) DESC NULLS LAST;

SELECT
  'private table direct access remains blocked' AS check_name,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'INSERT') AS auth_no_insert,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'UPDATE') AS auth_no_update,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'DELETE') AS auth_no_delete,
  NOT has_table_privilege('anon', 'private.ranked_game_sessions', 'SELECT') AS anon_no_select;
