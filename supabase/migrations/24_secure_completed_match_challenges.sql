-- 24. Secure completed-match challenges
--
-- This migration is intentionally local-only until reviewed and applied.
-- It implements Option A for friend challenges:
-- - the backend starts a normal match base session before the result exists;
-- - the backend generates and stores the exact question order and sequence hash;
-- - the completed base match can be promoted to a challenge exactly once;
-- - the creator's completed result is registered immediately;
-- - the opponent receives the same stored question order when starting.

CREATE SCHEMA IF NOT EXISTS private;

ALTER TABLE private.challenge_configs
  ADD COLUMN IF NOT EXISTS sequence_hash TEXT,
  ADD COLUMN IF NOT EXISTS base_match_id UUID;

CREATE TABLE IF NOT EXISTS private.challenge_base_match_sessions (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_nonce_hash TEXT NOT NULL UNIQUE,
    mode TEXT NOT NULL,
    variation TEXT NOT NULL,
    seed TEXT NOT NULL,
    algorithm_version TEXT NOT NULL DEFAULT 'server-sequence-v1',
    question_codes JSONB NOT NULL,
    question_count INTEGER NOT NULL,
    sequence_hash TEXT NOT NULL,
    rules_version INTEGER NOT NULL DEFAULT 1,
    allow_hearts BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'completed', 'expired', 'cancelled')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    result_id UUID REFERENCES public.game_results(id),
    challenge_id UUID REFERENCES public.challenges(id),
    event_id TEXT,
    idempotency_key TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT challenge_base_question_codes_array CHECK (jsonb_typeof(question_codes) = 'array'),
    CONSTRAINT challenge_base_question_count_positive CHECK (question_count > 0)
);

CREATE INDEX IF NOT EXISTS idx_challenge_base_user_created
  ON private.challenge_base_match_sessions (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_challenge_base_nonce
  ON private.challenge_base_match_sessions (session_nonce_hash);

CREATE UNIQUE INDEX IF NOT EXISTS idx_challenge_base_event
  ON private.challenge_base_match_sessions (event_id)
  WHERE event_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_challenge_base_idempotency
  ON private.challenge_base_match_sessions (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'challenge_configs_base_match_id_fkey'
          AND conrelid = 'private.challenge_configs'::regclass
    ) THEN
        ALTER TABLE private.challenge_configs
          ADD CONSTRAINT challenge_configs_base_match_id_fkey
          FOREIGN KEY (base_match_id)
          REFERENCES private.challenge_base_match_sessions(id)
          ON DELETE SET NULL;
    END IF;
END;
$$;

REVOKE ALL ON private.challenge_base_match_sessions FROM PUBLIC;
REVOKE ALL ON private.challenge_base_match_sessions FROM anon;
REVOKE ALL ON private.challenge_base_match_sessions FROM authenticated;
ALTER TABLE private.challenge_base_match_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "challenge_base_select_own" ON private.challenge_base_match_sessions;
CREATE POLICY "challenge_base_select_own"
ON private.challenge_base_match_sessions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION private.challenge_country_catalog()
RETURNS TABLE(code TEXT, continent TEXT)
LANGUAGE sql
IMMUTABLE
SET search_path = private
AS $$
  VALUES
    ('AR','south-america'), ('BO','south-america'), ('BR','south-america'), ('CL','south-america'),
    ('CO','south-america'), ('EC','south-america'), ('GY','south-america'), ('PY','south-america'),
    ('PE','south-america'), ('SR','south-america'), ('UY','south-america'), ('VE','south-america'),
    ('AG','north-america'), ('BS','north-america'), ('BB','north-america'), ('BZ','north-america'),
    ('CA','north-america'), ('CR','north-america'), ('CU','north-america'), ('DM','north-america'),
    ('DO','north-america'), ('SV','north-america'), ('GD','north-america'), ('GT','north-america'),
    ('HT','north-america'), ('HN','north-america'), ('JM','north-america'), ('MX','north-america'),
    ('NI','north-america'), ('PA','north-america'), ('KN','north-america'), ('LC','north-america'),
    ('VC','north-america'), ('TT','north-america'), ('US','north-america'),
    ('AL','europe'), ('AD','europe'), ('AT','europe'), ('BY','europe'), ('BE','europe'), ('BA','europe'),
    ('BG','europe'), ('HR','europe'), ('CZ','europe'), ('DK','europe'), ('EE','europe'), ('FI','europe'),
    ('FR','europe'), ('DE','europe'), ('GR','europe'), ('VA','europe'), ('HU','europe'), ('IS','europe'),
    ('IE','europe'), ('IT','europe'), ('LV','europe'), ('LI','europe'), ('LT','europe'), ('LU','europe'),
    ('MT','europe'), ('MD','europe'), ('MC','europe'), ('ME','europe'), ('NL','europe'), ('MK','europe'),
    ('NO','europe'), ('PL','europe'), ('PT','europe'), ('RO','europe'), ('RU','europe'), ('SM','europe'),
    ('RS','europe'), ('SK','europe'), ('SI','europe'), ('ES','europe'), ('SE','europe'), ('CH','europe'),
    ('UA','europe'), ('GB','europe'),
    ('DZ','africa'), ('AO','africa'), ('BJ','africa'), ('BW','africa'), ('BF','africa'), ('BI','africa'),
    ('CV','africa'), ('CM','africa'), ('CF','africa'), ('TD','africa'), ('KM','africa'), ('CG','africa'),
    ('CD','africa'), ('CI','africa'), ('DJ','africa'), ('EG','africa'), ('GQ','africa'), ('ER','africa'),
    ('SZ','africa'), ('ET','africa'), ('GA','africa'), ('GM','africa'), ('GH','africa'), ('GN','africa'),
    ('GW','africa'), ('KE','africa'), ('LS','africa'), ('LR','africa'), ('LY','africa'), ('MG','africa'),
    ('MW','africa'), ('ML','africa'), ('MR','africa'), ('MU','africa'), ('MA','africa'), ('MZ','africa'),
    ('NA','africa'), ('NE','africa'), ('NG','africa'), ('RW','africa'), ('ST','africa'), ('SN','africa'),
    ('SC','africa'), ('SL','africa'), ('SO','africa'), ('ZA','africa'), ('SS','africa'), ('SD','africa'),
    ('TZ','africa'), ('TG','africa'), ('TN','africa'), ('UG','africa'), ('ZM','africa'), ('ZW','africa'),
    ('AF','asia'), ('AM','asia'), ('AZ','asia'), ('BH','asia'), ('BD','asia'), ('BT','asia'),
    ('BN','asia'), ('KH','asia'), ('CN','asia'), ('CY','asia'), ('GE','asia'), ('IN','asia'),
    ('ID','asia'), ('IR','asia'), ('IQ','asia'), ('IL','asia'), ('JP','asia'), ('JO','asia'),
    ('KZ','asia'), ('KW','asia'), ('KG','asia'), ('LA','asia'), ('LB','asia'), ('MY','asia'),
    ('MV','asia'), ('MN','asia'), ('MM','asia'), ('NP','asia'), ('KP','asia'), ('OM','asia'),
    ('PK','asia'), ('PS','asia'), ('PH','asia'), ('QA','asia'), ('SA','asia'), ('SG','asia'),
    ('KR','asia'), ('LK','asia'), ('SY','asia'), ('TJ','asia'), ('TH','asia'), ('TL','asia'),
    ('TR','asia'), ('TM','asia'), ('AE','asia'), ('UZ','asia'), ('VN','asia'), ('YE','asia'),
    ('AU','oceania'), ('FJ','oceania'), ('KI','oceania'), ('MH','oceania'), ('FM','oceania'),
    ('NR','oceania'), ('NZ','oceania'), ('PW','oceania'), ('PG','oceania'), ('WS','oceania'),
    ('SB','oceania'), ('TO','oceania'), ('TV','oceania'), ('VU','oceania')
$$;

CREATE OR REPLACE FUNCTION private.challenge_build_question_codes(
    p_mode TEXT,
    p_variation TEXT,
    p_seed TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = private, public
AS $$
DECLARE
    v_question_count INTEGER;
    v_codes JSONB;
    v_actual_count INTEGER;
BEGIN
    v_question_count := private.challenge_question_count(p_mode, p_variation);

    WITH source AS (
        SELECT code
        FROM private.challenge_country_catalog()
        WHERE p_mode = 'world'
           OR continent = p_variation
    ),
    ordered AS (
        SELECT
            code,
            row_number() OVER (
                ORDER BY encode(extensions.digest(p_seed || ':' || code || ':flags', 'sha256'), 'hex'), code
            ) AS rn
        FROM source
    ),
    selected AS (
        SELECT code, rn
        FROM ordered
        ORDER BY rn
        LIMIT v_question_count
    )
    SELECT jsonb_agg(code ORDER BY rn), count(*)
    INTO v_codes, v_actual_count
    FROM selected;

    IF COALESCE(v_actual_count, 0) <> v_question_count THEN
        RAISE EXCEPTION 'Invalid challenge catalog for mode and variation';
    END IF;

    RETURN v_codes;
END;
$$;

CREATE OR REPLACE FUNCTION private.challenge_sequence_hash(
    p_mode TEXT,
    p_variation TEXT,
    p_question_codes JSONB,
    p_rules_version INTEGER,
    p_algorithm_version TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = private, public
AS $$
DECLARE
    v_joined_codes TEXT;
BEGIN
    SELECT string_agg(value, ',' ORDER BY ord)
    INTO v_joined_codes
    FROM jsonb_array_elements_text(p_question_codes) WITH ORDINALITY AS q(value, ord);

    RETURN encode(
        extensions.digest(
            concat_ws('|', p_mode, p_variation, p_rules_version::TEXT, p_algorithm_version, COALESCE(v_joined_codes, '')),
            'sha256'
        ),
        'hex'
    );
END;
$$;

CREATE OR REPLACE FUNCTION private.challenge_validate_question_codes(
    p_mode TEXT,
    p_variation TEXT,
    p_question_codes JSONB
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = private, public
AS $$
DECLARE
    v_expected_count INTEGER;
    v_total_count INTEGER;
    v_distinct_count INTEGER;
    v_invalid_count INTEGER;
BEGIN
    IF jsonb_typeof(p_question_codes) <> 'array' THEN
        RAISE EXCEPTION 'Invalid question sequence';
    END IF;

    v_expected_count := private.challenge_question_count(p_mode, p_variation);

    SELECT count(*), count(DISTINCT value)
    INTO v_total_count, v_distinct_count
    FROM jsonb_array_elements_text(p_question_codes) AS q(value);

    IF v_total_count <> v_expected_count OR v_distinct_count <> v_total_count THEN
        RAISE EXCEPTION 'Invalid question sequence';
    END IF;

    SELECT count(*)
    INTO v_invalid_count
    FROM jsonb_array_elements_text(p_question_codes) AS q(value)
    LEFT JOIN private.challenge_country_catalog() c
      ON c.code = q.value
     AND (p_mode = 'world' OR c.continent = p_variation)
    WHERE c.code IS NULL;

    IF v_invalid_count <> 0 THEN
        RAISE EXCEPTION 'Invalid question sequence';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.start_challenge_base_match(
    p_mode TEXT,
    p_variation TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_seed TEXT;
    v_nonce TEXT;
    v_nonce_hash TEXT;
    v_session_id UUID;
    v_question_codes JSONB;
    v_question_count INTEGER;
    v_sequence_hash TEXT;
    v_algorithm_version TEXT := 'server-sequence-v1';
    v_rules_version INTEGER := 1;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '45 minutes';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_mode NOT IN ('world', 'continent') THEN
        RAISE EXCEPTION 'Invalid challenge mode';
    END IF;

    v_question_count := private.challenge_question_count(p_mode, p_variation);
    v_seed := encode(extensions.gen_random_bytes(16), 'hex');
    v_question_codes := private.challenge_build_question_codes(p_mode, p_variation, v_seed);
    PERFORM private.challenge_validate_question_codes(p_mode, p_variation, v_question_codes);
    v_sequence_hash := private.challenge_sequence_hash(p_mode, p_variation, v_question_codes, v_rules_version, v_algorithm_version);

    v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
    v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');

    INSERT INTO private.challenge_base_match_sessions (
        user_id,
        session_nonce_hash,
        mode,
        variation,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        sequence_hash,
        rules_version,
        allow_hearts,
        expires_at
    )
    VALUES (
        v_user_id,
        v_nonce_hash,
        p_mode,
        p_variation,
        v_seed,
        v_algorithm_version,
        v_question_codes,
        v_question_count,
        v_sequence_hash,
        v_rules_version,
        FALSE,
        v_expires_at
    )
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'base_match_session_id', v_session_id,
        'session_id', v_session_id,
        'nonce', v_nonce,
        'expires_at', v_expires_at,
        'config', jsonb_build_object(
            'mode', p_mode,
            'variation', p_variation,
            'seed', v_seed,
            'algorithm_version', v_algorithm_version,
            'question_codes', v_question_codes,
            'question_count', v_question_count,
            'sequence_hash', v_sequence_hash,
            'rules_version', v_rules_version,
            'allow_hearts', FALSE
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_challenge_from_completed_match(
    p_base_nonce TEXT,
    p_event_id TEXT,
    p_correct INTEGER,
    p_wrong INTEGER,
    p_skipped INTEGER,
    p_total INTEGER,
    p_time_ms INTEGER,
    p_streak INTEGER,
    p_idemp_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce_hash TEXT;
    v_base RECORD;
    v_is_supporter BOOLEAN;
    v_daily_count INTEGER;
    v_code TEXT;
    v_challenge_id UUID;
    v_result_id UUID;
    v_accuracy NUMERIC(5,2);
    v_score INTEGER;
    v_idemp_key TEXT;
    v_event_id TEXT;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '7 days';
    v_public_config JSONB;
    v_scoring JSONB;
    v_result_payload JSONB;
    v_result_columns TEXT;
    v_result_values TEXT;
    v_result_insert_sql TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_base_nonce IS NULL OR length(trim(p_base_nonce)) < 32 OR length(trim(p_base_nonce)) > 128 THEN
        RAISE EXCEPTION 'Invalid base match session';
    END IF;

    v_event_id := trim(COALESCE(p_event_id, ''));
    v_idemp_key := trim(COALESCE(p_idemp_key, ''));

    IF length(v_event_id) < 8 OR length(v_event_id) > 128 THEN
        RAISE EXCEPTION 'Invalid event id';
    END IF;

    IF length(v_idemp_key) < 8 OR length(v_idemp_key) > 128 THEN
        RAISE EXCEPTION 'Invalid idempotency key';
    END IF;

    v_nonce_hash := encode(extensions.digest(p_base_nonce, 'sha256'), 'hex');

    SELECT *
    INTO v_base
    FROM private.challenge_base_match_sessions
    WHERE session_nonce_hash = v_nonce_hash
      AND user_id = v_user_id
      AND status = 'created'
    FOR UPDATE;

    IF NOT FOUND THEN
        SELECT c.id, c.code, c.expires_at
        INTO v_challenge_id, v_code, v_expires_at
        FROM public.challenges c
        WHERE c.creator_id = v_user_id
          AND c.idempotency_key = v_idemp_key;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'challenge_id', v_challenge_id,
                'code', v_code,
                'expires_at', v_expires_at,
                'restored', TRUE
            );
        END IF;

        RAISE EXCEPTION 'Invalid base match session';
    END IF;

    IF v_base.expires_at < NOW() THEN
        RAISE EXCEPTION 'Base match session expired';
    END IF;

    PERFORM private.challenge_validate_question_codes(v_base.mode, v_base.variation, v_base.question_codes);

    IF p_correct IS NULL
       OR p_wrong IS NULL
       OR p_skipped IS NULL
       OR p_total IS NULL
       OR p_time_ms IS NULL
       OR p_streak IS NULL THEN
        RAISE EXCEPTION 'Invalid result numbers';
    END IF;

    IF p_correct < 0
       OR p_wrong < 0
       OR p_skipped < 0
       OR p_total <= 0
       OR p_time_ms <= 0
       OR p_streak < 0 THEN
        RAISE EXCEPTION 'Invalid result numbers';
    END IF;

    IF p_time_ms > 1800000 THEN
        RAISE EXCEPTION 'Invalid elapsed time';
    END IF;

    IF p_correct > p_total
       OR p_wrong > p_total
       OR p_skipped > p_total
       OR p_streak > p_correct
       OR (p_correct + p_wrong + p_skipped) <> p_total
       OR p_total <> v_base.question_count THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    SELECT c.id, c.code, c.expires_at
    INTO v_challenge_id, v_code, v_expires_at
    FROM public.challenges c
    WHERE c.creator_id = v_user_id
      AND c.idempotency_key = v_idemp_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'challenge_id', v_challenge_id,
            'code', v_code,
            'expires_at', v_expires_at,
            'restored', TRUE
        );
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::TEXT));

    SELECT c.id, c.code, c.expires_at
    INTO v_challenge_id, v_code, v_expires_at
    FROM public.challenges c
    WHERE c.creator_id = v_user_id
      AND c.idempotency_key = v_idemp_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'challenge_id', v_challenge_id,
            'code', v_code,
            'expires_at', v_expires_at,
            'restored', TRUE
        );
    END IF;

    v_is_supporter := COALESCE(public.check_is_supporter(v_user_id), FALSE);

    IF NOT v_is_supporter THEN
        SELECT count(*) INTO v_daily_count
        FROM public.challenges
        WHERE creator_id = v_user_id
          AND (created_at AT TIME ZONE 'UTC')::DATE = (NOW() AT TIME ZONE 'UTC')::DATE;

        IF v_daily_count >= 2 THEN
            RAISE EXCEPTION 'Daily limit reached';
        END IF;
    END IF;

    v_score := p_correct;
    v_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);
    v_code := private.generate_challenge_code();
    v_result_payload := jsonb_build_object(
        'event_id', v_event_id,
        'user_id', v_user_id,
        'mode', v_base.mode,
        'variation', v_base.variation,
        'rules_version', v_base.rules_version,
        'score', v_score,
        'correct_answers', p_correct,
        'wrong_answers', p_wrong,
        'skipped_answers', p_skipped,
        'total_questions', p_total,
        'accuracy', v_accuracy,
        'elapsed_time_ms', p_time_ms,
        'best_streak', p_streak,
        'hearts_used', FALSE,
        'is_ranked', FALSE,
        'verification_status', 'verified',
        'received_at', NOW(),
        'created_at', NOW()
    );

    v_scoring := jsonb_build_object(
        'score', 'correct_answers',
        'tie_breakers', jsonb_build_array(
            'score_desc',
            'correct_answers_desc',
            'elapsed_time_ms_asc',
            'best_streak_desc'
        )
    );

    v_public_config := jsonb_build_object(
        'mode', v_base.mode,
        'variation', v_base.variation,
        'question_count', v_base.question_count,
        'sequence_hash', v_base.sequence_hash,
        'rules_version', v_base.rules_version,
        'allow_hearts', v_base.allow_hearts,
        'source', 'completed_match'
    );

    SELECT
        string_agg(format('%I', a.attname), ', ' ORDER BY a.attnum),
        string_agg(
            format('($1->>%L)::%s', a.attname, format_type(a.atttypid, a.atttypmod)),
            ', ' ORDER BY a.attnum
        )
    INTO v_result_columns, v_result_values
    FROM pg_attribute a
    WHERE a.attrelid = 'public.game_results'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND a.attname IN (
          'event_id',
          'user_id',
          'mode',
          'variation',
          'rules_version',
          'score',
          'correct_answers',
          'wrong_answers',
          'skipped_answers',
          'total_questions',
          'accuracy',
          'elapsed_time_ms',
          'best_streak',
          'hearts_used',
          'is_ranked',
          'verification_status',
          'received_at',
          'created_at'
      );

    IF v_result_columns IS NULL OR v_result_values IS NULL THEN
        RAISE EXCEPTION 'No compatible columns found in public.game_results';
    END IF;

    v_result_insert_sql := format(
        'INSERT INTO public.game_results (%s) VALUES (%s) RETURNING id',
        v_result_columns,
        v_result_values
    );

    EXECUTE v_result_insert_sql USING v_result_payload INTO v_result_id;

    INSERT INTO public.challenges (
        creator_id,
        code,
        mode,
        variation,
        idempotency_key,
        config,
        rules_version,
        allow_hearts,
        status,
        expires_at
    )
    VALUES (
        v_user_id,
        v_code,
        v_base.mode,
        v_base.variation,
        v_idemp_key,
        v_public_config,
        v_base.rules_version,
        v_base.allow_hearts,
        'open',
        v_expires_at
    )
    RETURNING id INTO v_challenge_id;

    INSERT INTO private.challenge_configs (
        challenge_id,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        sequence_hash,
        base_match_id,
        rules_version,
        allow_hearts,
        scoring
    )
    VALUES (
        v_challenge_id,
        v_base.seed,
        v_base.algorithm_version,
        v_base.question_codes,
        v_base.question_count,
        v_base.sequence_hash,
        v_base.id,
        v_base.rules_version,
        v_base.allow_hearts,
        v_scoring
    );

    INSERT INTO public.challenge_participants (
        challenge_id,
        user_id,
        role,
        status,
        accepted_at,
        started_at,
        completed_at,
        result_id,
        event_id,
        score,
        correct_answers,
        wrong_answers,
        skipped_answers,
        total_questions,
        accuracy,
        elapsed_time_ms,
        best_streak
    )
    VALUES (
        v_challenge_id,
        v_user_id,
        'creator',
        'completed',
        v_base.started_at,
        v_base.started_at,
        NOW(),
        v_result_id,
        v_event_id,
        v_score,
        p_correct,
        p_wrong,
        p_skipped,
        p_total,
        v_accuracy,
        p_time_ms,
        p_streak
    );

    UPDATE private.challenge_base_match_sessions
    SET status = 'completed',
        completed_at = NOW(),
        result_id = v_result_id,
        challenge_id = v_challenge_id,
        event_id = v_event_id,
        idempotency_key = v_idemp_key
    WHERE id = v_base.id;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge_id,
        'code', v_code,
        'expires_at', v_expires_at,
        'result_id', v_result_id,
        'sequence_hash', v_base.sequence_hash,
        'challenge_status', private.challenge_public_status(v_challenge_id),
        'remaining_daily', CASE
            WHEN v_is_supporter THEN -1
            ELSE GREATEST(2 - (COALESCE(v_daily_count, 0) + 1), 0)
        END,
        'is_supporter', v_is_supporter
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.start_challenge_session(p_challenge_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_code TEXT;
    v_challenge RECORD;
    v_participant RECORD;
    v_config_snapshot JSONB;
    v_client_config JSONB;
    v_nonce TEXT;
    v_nonce_hash TEXT;
    v_fallback_seed TEXT;
    v_session_id UUID;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '30 minutes';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_code := public.normalize_challenge_code(p_challenge_code);

    IF v_code IS NULL THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT *
    INTO v_challenge
    FROM public.challenges
    WHERE code = v_code
      AND status = 'open'
      AND expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT *
    INTO v_participant
    FROM public.challenge_participants
    WHERE challenge_id = v_challenge.id
      AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge must be accepted before starting';
    END IF;

    IF v_participant.status = 'completed' THEN
        RAISE EXCEPTION 'Challenge participation already completed';
    END IF;

    v_fallback_seed := encode(extensions.gen_random_bytes(16), 'hex');

    UPDATE private.challenge_configs cc
    SET seed = COALESCE(NULLIF(cc.seed, ''), v_fallback_seed),
        algorithm_version = CASE
            WHEN COALESCE(NULLIF(cc.algorithm_version, ''), '') = '' THEN 'server-sequence-v1'
            ELSE cc.algorithm_version
        END,
        question_codes = private.challenge_build_question_codes(
            v_challenge.mode,
            v_challenge.variation,
            COALESCE(NULLIF(cc.seed, ''), v_fallback_seed)
        ),
        sequence_hash = NULL
    WHERE cc.challenge_id = v_challenge.id
      AND COALESCE(
        jsonb_array_length(
            CASE
                WHEN jsonb_typeof(cc.question_codes) = 'array' THEN cc.question_codes
                ELSE '[]'::jsonb
            END
        ),
        0
      ) = 0;

    INSERT INTO private.challenge_configs (
        challenge_id,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        sequence_hash,
        rules_version,
        allow_hearts,
        scoring
    )
    VALUES (
        v_challenge.id,
        v_fallback_seed,
        'server-sequence-v1',
        private.challenge_build_question_codes(
            v_challenge.mode,
            v_challenge.variation,
            v_fallback_seed
        ),
        private.challenge_question_count(v_challenge.mode, v_challenge.variation),
        NULL,
        v_challenge.rules_version,
        v_challenge.allow_hearts,
        jsonb_build_object(
            'score', 'correct_answers',
            'tie_breakers', jsonb_build_array(
                'score_desc',
                'correct_answers_desc',
                'elapsed_time_ms_asc',
                'best_streak_desc'
            )
        )
    )
    ON CONFLICT (challenge_id) DO NOTHING;

    UPDATE private.challenge_configs cc
    SET sequence_hash = private.challenge_sequence_hash(
        v_challenge.mode,
        v_challenge.variation,
        cc.question_codes,
        cc.rules_version,
        cc.algorithm_version
    )
    WHERE cc.challenge_id = v_challenge.id
      AND cc.sequence_hash IS NULL;

    SELECT jsonb_build_object(
        'mode', v_challenge.mode,
        'variation', v_challenge.variation,
        'seed', cc.seed,
        'algorithm_version', cc.algorithm_version,
        'question_codes', cc.question_codes,
        'question_count', cc.question_count,
        'sequence_hash', cc.sequence_hash,
        'rules_version', cc.rules_version,
        'allow_hearts', cc.allow_hearts,
        'scoring', cc.scoring
    )
    INTO v_config_snapshot
    FROM private.challenge_configs cc
    WHERE cc.challenge_id = v_challenge.id;

    PERFORM private.challenge_validate_question_codes(
        v_challenge.mode,
        v_challenge.variation,
        v_config_snapshot->'question_codes'
    );

    v_client_config := v_config_snapshot - 'scoring';

    UPDATE private.challenge_sessions
    SET status = 'cancelled'
    WHERE participant_id = v_participant.id
      AND status = 'created';

    v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
    v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');

    INSERT INTO private.challenge_sessions (
        challenge_id,
        participant_id,
        user_id,
        session_nonce_hash,
        config_snapshot,
        status,
        expires_at
    )
    VALUES (
        v_challenge.id,
        v_participant.id,
        v_user_id,
        v_nonce_hash,
        v_config_snapshot,
        'created',
        v_expires_at
    )
    RETURNING id INTO v_session_id;

    UPDATE public.challenge_participants
    SET status = 'playing',
        started_at = COALESCE(started_at, NOW()),
        updated_at = NOW()
    WHERE id = v_participant.id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'challenge_id', v_challenge.id,
        'participant_id', v_participant.id,
        'nonce', v_nonce,
        'expires_at', v_expires_at,
        'config', v_client_config
    );
END;
$$;

REVOKE ALL ON FUNCTION private.challenge_country_catalog() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.challenge_country_catalog() FROM anon;
REVOKE ALL ON FUNCTION private.challenge_country_catalog() FROM authenticated;
REVOKE ALL ON FUNCTION private.challenge_build_question_codes(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.challenge_build_question_codes(TEXT, TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION private.challenge_build_question_codes(TEXT, TEXT, TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION private.challenge_sequence_hash(TEXT, TEXT, JSONB, INTEGER, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.challenge_sequence_hash(TEXT, TEXT, JSONB, INTEGER, TEXT) FROM anon;
REVOKE ALL ON FUNCTION private.challenge_sequence_hash(TEXT, TEXT, JSONB, INTEGER, TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION private.challenge_validate_question_codes(TEXT, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.challenge_validate_question_codes(TEXT, TEXT, JSONB) FROM anon;
REVOKE ALL ON FUNCTION private.challenge_validate_question_codes(TEXT, TEXT, JSONB) FROM authenticated;

REVOKE ALL ON FUNCTION public.start_challenge_base_match(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.start_challenge_base_match(TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.start_challenge_base_match(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.create_challenge_from_completed_match(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    TEXT
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_challenge_from_completed_match(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    TEXT
) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_challenge_from_completed_match(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    TEXT
) TO authenticated;

REVOKE ALL ON FUNCTION public.start_challenge_session(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.start_challenge_session(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.start_challenge_session(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
