-- 28. Fix ranked result metrics persistence and ranked promotion safety
--
-- Migration 27 made ranked sessions promotable to friend challenges, but kept a
-- remote-compatible dynamic INSERT into public.game_results. That INSERT could
-- report success even if required metric columns were not part of the remote
-- write contract, allowing verified ranked results with NULL wrong/skipped
-- metrics. Promotion then used NULL-unsafe comparisons and reached the
-- challenge participant insert with incomplete metrics.
--
-- This migration keeps historical rows intact, adds the missing metric columns
-- to public.game_results, blocks new incomplete ranked result rows, requires
-- essential game_results columns for ranked submissions, verifies persisted
-- values after INSERT, and rejects incomplete historical ranked results before
-- any challenge rows are created. Mode and variation remain owned by
-- private.ranked_game_sessions.

ALTER TABLE public.game_results
  ADD COLUMN IF NOT EXISTS wrong_answers INTEGER,
  ADD COLUMN IF NOT EXISTS skipped_answers INTEGER,
  ADD COLUMN IF NOT EXISTS best_streak INTEGER;

DO $$
BEGIN
    IF to_regclass('public.game_results') IS NOT NULL
       AND NOT EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conrelid = 'public.game_results'::regclass
            AND conname = 'game_results_ranked_metrics_complete'
       ) THEN
        ALTER TABLE public.game_results
          ADD CONSTRAINT game_results_ranked_metrics_complete
          CHECK (
            is_ranked IS DISTINCT FROM TRUE
            OR (
              ranked_session_id IS NOT NULL
              AND correct_answers IS NOT NULL
              AND wrong_answers IS NOT NULL
              AND skipped_answers IS NOT NULL
              AND total_questions IS NOT NULL
              AND elapsed_time_ms IS NOT NULL
              AND best_streak IS NOT NULL
              AND correct_answers >= 0
              AND wrong_answers >= 0
              AND skipped_answers >= 0
              AND total_questions > 0
              AND elapsed_time_ms > 0
              AND best_streak >= 0
              AND correct_answers <= total_questions
              AND wrong_answers <= total_questions
              AND skipped_answers <= total_questions
              AND best_streak <= correct_answers
              AND correct_answers + wrong_answers + skipped_answers = total_questions
            )
          ) NOT VALID;
    END IF;

    IF to_regclass('public.challenge_participants') IS NOT NULL
       AND NOT EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conrelid = 'public.challenge_participants'::regclass
            AND conname = 'challenge_participants_completed_metrics_complete'
       ) THEN
        ALTER TABLE public.challenge_participants
          ADD CONSTRAINT challenge_participants_completed_metrics_complete
          CHECK (
            status::TEXT <> 'completed'
            OR (
              correct_answers IS NOT NULL
              AND wrong_answers IS NOT NULL
              AND skipped_answers IS NOT NULL
              AND total_questions IS NOT NULL
              AND elapsed_time_ms IS NOT NULL
              AND best_streak IS NOT NULL
              AND correct_answers >= 0
              AND wrong_answers >= 0
              AND skipped_answers >= 0
              AND total_questions > 0
              AND elapsed_time_ms > 0
              AND best_streak >= 0
              AND correct_answers <= total_questions
              AND wrong_answers <= total_questions
              AND skipped_answers <= total_questions
              AND best_streak <= correct_answers
              AND correct_answers + wrong_answers + skipped_answers = total_questions
            )
          ) NOT VALID;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_ranked_result(
    p_nonce TEXT,
    p_event_id TEXT,
    p_correct INTEGER,
    p_wrong INTEGER,
    p_skipped INTEGER,
    p_total INTEGER,
    p_time_ms INTEGER,
    p_streak INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce_hash TEXT;
    v_session_json JSONB;
    v_session_id UUID;
    v_expected_total INTEGER;
    v_result_id UUID;
    v_calculated_score INTEGER;
    v_calculated_accuracy NUMERIC;
    v_event_id TEXT;
    v_payload JSONB;
    v_columns TEXT;
    v_values TEXT;
    v_insert_sql TEXT;
    v_inserted_result JSONB;
    v_required_columns TEXT[] := ARRAY[
        'event_id',
        'user_id',
        'ranked_session_id',
        'score',
        'correct_answers',
        'wrong_answers',
        'skipped_answers',
        'total_questions',
        'accuracy',
        'elapsed_time_ms',
        'best_streak',
        'is_ranked',
        'verification_status'
    ];
    v_optional_columns TEXT[] := ARRAY[
        'rules_version',
        'hearts_used',
        'created_at',
        'received_at'
    ];
    v_missing_columns TEXT[];
    v_stage TEXT := 'start';
    v_error_state TEXT;
    v_error_message TEXT;
BEGIN
    v_stage := 'auth';
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_event_id := NULLIF(trim(p_event_id), '');
    IF v_event_id IS NULL THEN
        RAISE EXCEPTION 'Missing event_id';
    END IF;

    v_stage := 'validate_numbers';
    IF p_total IS NULL
       OR p_correct IS NULL
       OR p_wrong IS NULL
       OR p_skipped IS NULL
       OR p_time_ms IS NULL
       OR p_streak IS NULL THEN
        RAISE EXCEPTION 'Invalid result numbers';
    END IF;

    IF p_total <= 0
       OR p_correct < 0
       OR p_wrong < 0
       OR p_skipped < 0
       OR p_time_ms <= 0
       OR p_streak < 0 THEN
        RAISE EXCEPTION 'Invalid result numbers';
    END IF;

    IF p_correct > p_total
       OR p_wrong > p_total
       OR p_skipped > p_total
       OR p_streak > p_correct
       OR (p_correct + p_wrong + p_skipped) <> p_total THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    v_stage := 'hash_nonce';
    v_nonce_hash := encode(extensions.digest(p_nonce, 'sha256'), 'hex');

    v_stage := 'load_session';
    SELECT to_jsonb(s)
    INTO v_session_json
    FROM private.ranked_game_sessions s
    WHERE s.session_nonce_hash = v_nonce_hash
      AND s.user_id = v_user_id
      AND s.status::TEXT = 'created'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid session or already used';
    END IF;

    v_session_id := (v_session_json->>'id')::UUID;
    v_expected_total := COALESCE(NULLIF(v_session_json->>'question_count', '')::INTEGER, p_total);

    v_stage := 'check_session_contract';
    IF NULLIF(v_session_json->>'mode', '') IS NULL
       OR NULLIF(v_session_json->>'variation', '') IS NULL THEN
        RAISE EXCEPTION 'Ranked session mode metadata is incomplete';
    END IF;

    IF NULLIF(v_session_json->>'expires_at', '')::TIMESTAMPTZ < NOW() THEN
        UPDATE private.ranked_game_sessions
        SET status = 'expired'
        WHERE id = v_session_id;

        RAISE EXCEPTION 'Session expired';
    END IF;

    IF p_total <> v_expected_total THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    v_stage := 'check_game_results_columns';
    SELECT array_agg(required_column ORDER BY required_column)
    INTO v_missing_columns
    FROM unnest(v_required_columns) AS required(required_column)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_attribute a
        WHERE a.attrelid = 'public.game_results'::regclass
          AND a.attname = required_column
          AND a.attnum > 0
          AND NOT a.attisdropped
    );

    IF COALESCE(array_length(v_missing_columns, 1), 0) > 0 THEN
        RAISE EXCEPTION 'Required public.game_results columns missing: %', array_to_string(v_missing_columns, ', ');
    END IF;

    v_stage := 'calculate_score';
    v_calculated_score := p_correct;
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    v_stage := 'build_payload';
    v_payload := jsonb_build_object(
        'event_id', v_event_id,
        'user_id', v_user_id,
        'ranked_session_id', v_session_id,
        'rules_version', COALESCE(NULLIF(v_session_json->>'rules_version', '')::INTEGER, 1),
        'score', v_calculated_score,
        'correct_answers', p_correct,
        'wrong_answers', p_wrong,
        'skipped_answers', p_skipped,
        'total_questions', p_total,
        'accuracy', v_calculated_accuracy,
        'elapsed_time_ms', p_time_ms,
        'best_streak', p_streak,
        'hearts_used', FALSE,
        'is_ranked', TRUE,
        'verification_status', 'verified',
        'created_at', NOW(),
        'received_at', NOW()
    );

    v_stage := 'resolve_game_results_columns';
    SELECT
        string_agg(format('%I', a.attname), ', ' ORDER BY a.attnum),
        string_agg(
            format('($1->>%L)::%s', a.attname, format_type(a.atttypid, a.atttypmod)),
            ', ' ORDER BY a.attnum
        )
    INTO v_columns, v_values
    FROM pg_attribute a
    WHERE a.attrelid = 'public.game_results'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND a.attname = ANY (v_required_columns || v_optional_columns);

    IF v_columns IS NULL OR v_values IS NULL THEN
        RAISE EXCEPTION 'No compatible columns found in public.game_results';
    END IF;

    v_stage := 'insert_game_results';
    v_insert_sql := format(
        'INSERT INTO public.game_results (%s) VALUES (%s) RETURNING id',
        v_columns,
        v_values
    );

    EXECUTE v_insert_sql USING v_payload INTO v_result_id;

    v_stage := 'verify_persisted_result';
    SELECT to_jsonb(r)
    INTO v_inserted_result
    FROM public.game_results r
    WHERE r.id = v_result_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ranked result was not persisted';
    END IF;

    IF NULLIF(v_inserted_result->>'ranked_session_id', '')::UUID IS DISTINCT FROM v_session_id
       OR NULLIF(v_inserted_result->>'user_id', '')::UUID IS DISTINCT FROM v_user_id
       OR NULLIF(v_inserted_result->>'correct_answers', '')::INTEGER IS DISTINCT FROM p_correct
       OR NULLIF(v_inserted_result->>'wrong_answers', '')::INTEGER IS DISTINCT FROM p_wrong
       OR NULLIF(v_inserted_result->>'skipped_answers', '')::INTEGER IS DISTINCT FROM p_skipped
       OR NULLIF(v_inserted_result->>'total_questions', '')::INTEGER IS DISTINCT FROM p_total
       OR NULLIF(v_inserted_result->>'elapsed_time_ms', '')::INTEGER IS DISTINCT FROM p_time_ms
       OR NULLIF(v_inserted_result->>'best_streak', '')::INTEGER IS DISTINCT FROM p_streak
       OR NULLIF(v_inserted_result->>'is_ranked', '')::BOOLEAN IS DISTINCT FROM TRUE
       OR NULLIF(v_inserted_result->>'verification_status', '') IS DISTINCT FROM 'verified' THEN
        RAISE EXCEPTION 'Ranked result metrics were not persisted';
    END IF;

    v_stage := 'complete_session';
    UPDATE private.ranked_game_sessions
    SET status = 'completed',
        completed_at = NOW(),
        result_id = v_result_id
    WHERE id = v_session_id;

    RETURN jsonb_build_object(
        'result_id', v_result_id,
        'ranked_session_id', v_session_id,
        'status', 'verified'
    );
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
        v_error_state = RETURNED_SQLSTATE,
        v_error_message = MESSAGE_TEXT;

    RAISE EXCEPTION USING
        ERRCODE = v_error_state,
        MESSAGE = format(
            'submit_ranked_result failed at %s [%s]: %s',
            v_stage,
            v_error_state,
            v_error_message
        ),
        DETAIL = NULL,
        HINT = 'Check required game_results metric columns, ranked session metadata, constraints, and enum values.';
END;
$$;

CREATE OR REPLACE FUNCTION public.create_challenge_from_ranked_session(
    p_ranked_session_id UUID,
    p_idemp_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_ranked RECORD;
    v_result RECORD;
    v_is_supporter BOOLEAN;
    v_daily_count INTEGER;
    v_code TEXT;
    v_challenge_id UUID;
    v_idemp_key TEXT;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '7 days';
    v_public_config JSONB;
    v_scoring JSONB;
    v_expected_hash TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_ranked_session_id IS NULL THEN
        RAISE EXCEPTION 'Invalid ranked session';
    END IF;

    v_idemp_key := trim(COALESCE(p_idemp_key, ''));
    IF length(v_idemp_key) < 8 OR length(v_idemp_key) > 128 THEN
        RAISE EXCEPTION 'Invalid idempotency key';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::TEXT));

    SELECT *
    INTO v_ranked
    FROM private.ranked_game_sessions
    WHERE id = p_ranked_session_id
      AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid ranked session';
    END IF;

    IF v_ranked.challenge_id IS NOT NULL THEN
        SELECT c.id, c.code, c.expires_at
        INTO v_challenge_id, v_code, v_expires_at
        FROM public.challenges c
        WHERE c.id = v_ranked.challenge_id
          AND c.creator_id = v_user_id;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'challenge_id', v_challenge_id,
                'code', v_code,
                'expires_at', v_expires_at,
                'restored', TRUE
            );
        END IF;
    END IF;

    SELECT c.id, c.code, c.expires_at
    INTO v_challenge_id, v_code, v_expires_at
    FROM public.challenges c
    WHERE c.creator_id = v_user_id
      AND c.idempotency_key = v_idemp_key;

    IF FOUND THEN
        RAISE EXCEPTION 'Idempotency key already used';
    END IF;

    IF v_ranked.status::TEXT <> 'completed' OR v_ranked.result_id IS NULL THEN
        RAISE EXCEPTION 'Ranked result is not completed';
    END IF;

    IF v_ranked.question_codes IS NULL
       OR v_ranked.question_count IS NULL
       OR v_ranked.sequence_hash IS NULL
       OR v_ranked.seed IS NULL THEN
        RAISE EXCEPTION 'Ranked session does not contain a protected sequence';
    END IF;

    PERFORM private.challenge_validate_question_codes(
        v_ranked.mode,
        v_ranked.variation,
        v_ranked.question_codes
    );

    v_expected_hash := private.challenge_sequence_hash(
        v_ranked.mode,
        v_ranked.variation,
        v_ranked.question_codes,
        v_ranked.rules_version,
        COALESCE(v_ranked.algorithm_version, 'server-sequence-v1')
    );

    IF v_expected_hash <> v_ranked.sequence_hash THEN
        RAISE EXCEPTION 'Ranked sequence integrity check failed';
    END IF;

    SELECT *
    INTO v_result
    FROM public.game_results r
    WHERE r.id = v_ranked.result_id
      AND r.user_id = v_user_id
      AND r.ranked_session_id = v_ranked.id
      AND r.is_ranked = TRUE
      AND r.verification_status = 'verified'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Verified ranked result not found';
    END IF;

    IF v_ranked.mode IS NULL OR v_ranked.variation IS NULL THEN
        RAISE EXCEPTION 'Ranked session mode metadata is incomplete';
    END IF;

    IF v_result.correct_answers IS NULL
       OR v_result.wrong_answers IS NULL
       OR v_result.skipped_answers IS NULL
       OR v_result.total_questions IS NULL
       OR v_result.elapsed_time_ms IS NULL
       OR v_result.best_streak IS NULL THEN
        RAISE EXCEPTION 'Ranked result metrics are incomplete';
    END IF;

    IF v_result.correct_answers < 0
       OR v_result.wrong_answers < 0
       OR v_result.skipped_answers < 0
       OR v_result.total_questions <= 0
       OR v_result.elapsed_time_ms <= 0
       OR v_result.best_streak < 0
       OR v_result.correct_answers > v_result.total_questions
       OR v_result.wrong_answers > v_result.total_questions
       OR v_result.skipped_answers > v_result.total_questions
       OR v_result.best_streak > v_result.correct_answers THEN
        RAISE EXCEPTION 'Ranked result metrics are invalid';
    END IF;

    IF v_result.correct_answers + v_result.wrong_answers + v_result.skipped_answers <> v_result.total_questions THEN
        RAISE EXCEPTION 'Ranked result metrics do not match total questions';
    END IF;

    IF v_result.user_id IS DISTINCT FROM v_user_id
       OR v_result.ranked_session_id IS DISTINCT FROM v_ranked.id
       OR v_result.total_questions IS DISTINCT FROM v_ranked.question_count THEN
        RAISE EXCEPTION 'Ranked result does not match ranked session';
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

    v_code := private.generate_challenge_code();
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
        'mode', v_ranked.mode,
        'variation', v_ranked.variation,
        'question_count', v_ranked.question_count,
        'sequence_hash', v_ranked.sequence_hash,
        'rules_version', v_ranked.rules_version,
        'allow_hearts', COALESCE(v_ranked.allow_hearts, FALSE),
        'source', 'ranked_match'
    );

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
        v_ranked.mode,
        v_ranked.variation,
        v_idemp_key,
        v_public_config,
        v_ranked.rules_version,
        COALESCE(v_ranked.allow_hearts, FALSE),
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
        v_ranked.seed,
        COALESCE(v_ranked.algorithm_version, 'server-sequence-v1'),
        v_ranked.question_codes,
        v_ranked.question_count,
        v_ranked.sequence_hash,
        NULL,
        v_ranked.rules_version,
        COALESCE(v_ranked.allow_hearts, FALSE),
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
        v_ranked.started_at,
        v_ranked.started_at,
        COALESCE(v_ranked.completed_at, NOW()),
        v_result.id,
        v_result.event_id,
        v_result.score,
        v_result.correct_answers,
        v_result.wrong_answers,
        v_result.skipped_answers,
        v_result.total_questions,
        v_result.accuracy,
        v_result.elapsed_time_ms,
        v_result.best_streak
    );

    UPDATE private.ranked_game_sessions
    SET challenge_id = v_challenge_id,
        promotion_idempotency_key = v_idemp_key
    WHERE id = v_ranked.id;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge_id,
        'code', v_code,
        'expires_at', v_expires_at,
        'result_id', v_result.id,
        'sequence_hash', v_ranked.sequence_hash,
        'challenge_status', private.challenge_public_status(v_challenge_id),
        'remaining_daily', CASE
            WHEN v_is_supporter THEN -1
            ELSE GREATEST(2 - (COALESCE(v_daily_count, 0) + 1), 0)
        END,
        'is_supporter', v_is_supporter,
        'source', 'ranked_match'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) FROM anon;
REVOKE ALL ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) TO authenticated;

REVOKE ALL ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
