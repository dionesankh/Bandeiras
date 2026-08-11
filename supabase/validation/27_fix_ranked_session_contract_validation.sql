-- Validation for 27_fix_ranked_session_contract.sql
-- Read-only checks. Do not create sessions, results, or challenges here.

SELECT
  'ranked_game_sessions required columns' AS check_name,
  bool_and(pc.column_name IS NOT NULL) AS ok,
  jsonb_agg(
    jsonb_build_object(
      'column', rc.column_name,
      'expected_type', rc.expected_type,
      'actual_type', pc.data_type,
      'nullable', pc.is_nullable,
      'default', pc.column_default
    )
    ORDER BY rc.column_name
  ) AS details
FROM (
  VALUES
    ('id', 'uuid'),
    ('user_id', 'uuid'),
    ('session_nonce_hash', 'text'),
    ('mode', 'text'),
    ('variation', 'text'),
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
    ('status', NULL)
) AS rc(column_name, expected_type)
LEFT JOIN (
  SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
  WHERE table_schema = 'private'
    AND table_name = 'ranked_game_sessions'
) AS pc USING (column_name);

SELECT
  'ranked_game_sessions typed contract' AS check_name,
  bool_and(rc.expected_type IS NULL OR pc.data_type = rc.expected_type) AS ok,
  jsonb_agg(
    jsonb_build_object(
      'column', rc.column_name,
      'expected_type', rc.expected_type,
      'actual_type', pc.data_type
    )
    ORDER BY rc.column_name
  ) FILTER (
    WHERE rc.expected_type IS NOT NULL
      AND pc.data_type IS DISTINCT FROM rc.expected_type
  ) AS mismatches
FROM (
  VALUES
    ('id', 'uuid'),
    ('user_id', 'uuid'),
    ('session_nonce_hash', 'text'),
    ('mode', 'text'),
    ('variation', 'text'),
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
    ('status', NULL)
) AS rc(column_name, expected_type)
JOIN (
  SELECT column_name, data_type
  FROM information_schema.columns
  WHERE table_schema = 'private'
    AND table_name = 'ranked_game_sessions'
) AS pc USING (column_name);

SELECT
  'ranked session required defaults/not-null' AS check_name,
  bool_and(
    CASE column_name
      WHEN 'rules_version' THEN is_nullable = 'NO' AND column_default IS NOT NULL
      WHEN 'algorithm_version' THEN is_nullable = 'NO' AND column_default IS NOT NULL
      WHEN 'allow_hearts' THEN is_nullable = 'NO' AND column_default IS NOT NULL
      WHEN 'started_at' THEN is_nullable = 'NO' AND column_default IS NOT NULL
      WHEN 'expires_at' THEN is_nullable = 'NO'
      WHEN 'created_at' THEN is_nullable = 'NO' AND column_default IS NOT NULL
      WHEN 'status' THEN is_nullable = 'NO' AND column_default IS NOT NULL
      ELSE TRUE
    END
  ) AS ok
FROM information_schema.columns
WHERE table_schema = 'private'
  AND table_name = 'ranked_game_sessions'
  AND column_name IN (
    'rules_version',
    'algorithm_version',
    'allow_hearts',
    'started_at',
    'expires_at',
    'created_at',
    'status'
  );

SELECT
  'ranked session constraints and indexes' AS check_name,
  EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'private.ranked_game_sessions'::regclass
      AND conname = 'ranked_game_sessions_question_codes_array'
  ) AS has_question_codes_array_check,
  EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'private.ranked_game_sessions'::regclass
      AND conname = 'ranked_game_sessions_question_count_positive'
  ) AS has_question_count_positive_check,
  EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'private.ranked_game_sessions'::regclass
      AND conname = 'ranked_game_sessions_status_valid'
  ) AS has_status_check,
  to_regclass('private.idx_ranked_sessions_challenge_id') IS NOT NULL AS has_challenge_index,
  to_regclass('private.idx_ranked_sessions_promotion_idempotency') IS NOT NULL AS has_promotion_idempotency_index,
  to_regclass('private.idx_ranked_sessions_hash') IS NOT NULL AS has_nonce_hash_index;

SELECT
  'ranked rpc signatures exist' AS check_name,
  to_regprocedure('public.create_ranked_session(text,text)') IS NOT NULL AS create_ranked_session,
  to_regprocedure('public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)') IS NOT NULL AS submit_ranked_result,
  to_regprocedure('public.create_challenge_from_ranked_session(uuid,text)') IS NOT NULL AS create_from_ranked;

SELECT
  'ranked rpc security/search_path' AS check_name,
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  p.prosecdef AS security_definer,
  p.proconfig::TEXT AS config
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'create_ranked_session',
    'submit_ranked_result',
    'create_challenge_from_ranked_session'
  )
ORDER BY p.proname;

SELECT
  'create_ranked_session insert contract' AS check_name,
  p.prosrc LIKE '%INSERT INTO private.ranked_game_sessions%' AS inserts_ranked_session,
  p.prosrc LIKE '%rules_version%' AS uses_rules_version,
  p.prosrc LIKE '%question_codes%' AS returns_question_codes,
  p.prosrc LIKE '%sequence_hash%' AS returns_sequence_hash,
  p.prosrc LIKE '%allow_hearts%' AS uses_allow_hearts
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'create_ranked_session'
  AND pg_get_function_identity_arguments(p.oid) = 'p_mode text, p_variation text';

SELECT
  'authenticated execute grants' AS check_name,
  has_function_privilege('authenticated', 'public.create_ranked_session(text,text)', 'EXECUTE') AS create_ranked_session,
  has_function_privilege('authenticated', 'public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)', 'EXECUTE') AS submit_ranked_result,
  has_function_privilege('authenticated', 'public.create_challenge_from_ranked_session(uuid,text)', 'EXECUTE') AS create_from_ranked;

SELECT
  'anon has no execute on ranked rpcs' AS check_name,
  NOT has_function_privilege('anon', 'public.create_ranked_session(text,text)', 'EXECUTE') AS anon_no_create_ranked,
  NOT has_function_privilege('anon', 'public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)', 'EXECUTE') AS anon_no_submit_ranked,
  NOT has_function_privilege('anon', 'public.create_challenge_from_ranked_session(uuid,text)', 'EXECUTE') AS anon_no_create_from_ranked;

SELECT
  'private ranked table not directly writable by authenticated' AS check_name,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'INSERT') AS auth_no_insert,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'UPDATE') AS auth_no_update,
  NOT has_table_privilege('authenticated', 'private.ranked_game_sessions', 'DELETE') AS auth_no_delete;
