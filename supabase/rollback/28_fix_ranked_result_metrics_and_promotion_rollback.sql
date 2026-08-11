-- Rollback for 28_fix_ranked_result_metrics_and_promotion.
-- Restores the ranked submit/promotion RPCs to the migration 27 contract and
-- removes the NOT VALID constraints introduced by migration 28.

ALTER TABLE IF EXISTS public.challenge_participants
  DROP CONSTRAINT IF EXISTS challenge_participants_completed_metrics_complete;

ALTER TABLE IF EXISTS public.game_results
  DROP CONSTRAINT IF EXISTS game_results_ranked_metrics_complete;

ALTER TABLE IF EXISTS public.game_results
  DROP COLUMN IF EXISTS best_streak,
  DROP COLUMN IF EXISTS skipped_answers,
  DROP COLUMN IF EXISTS wrong_answers;

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
       OR p_total <= 0
       OR p_correct IS NULL
       OR p_wrong IS NULL
       OR p_skipped IS NULL
       OR p_correct < 0
       OR p_wrong < 0
       OR p_skipped < 0
       OR (p_correct + p_wrong + p_skipped) <> p_total
       OR p_correct > p_total THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    IF p_time_ms IS NULL OR p_time_ms <= 0 THEN
        RAISE EXCEPTION 'Invalid elapsed time';
    END IF;

    IF p_streak IS NULL OR p_streak < 0 OR p_streak > p_correct THEN
        RAISE EXCEPTION 'Invalid streak';
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

    v_stage := 'check_expiration';
    IF (v_session_json->>'expires_at')::TIMESTAMPTZ < NOW() THEN
        RAISE EXCEPTION 'Session expired';
    END IF;

    IF p_total <> v_expected_total THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    v_stage := 'calculate_score';
    v_calculated_score := p_correct;
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    v_stage := 'build_payload';
    v_payload := jsonb_build_object(
        'event_id', v_event_id,
        'user_id', v_user_id,
        'ranked_session_id', v_session_id,
        'mode', v_session_json->>'mode',
        'variation', v_session_json->>'variation',
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
      AND a.attname IN (
          'event_id',
          'user_id',
          'ranked_session_id',
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
          'created_at',
          'received_at'
      );

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
        HINT = 'Check required columns, constraints, enum values, session status, and ranked sequence metadata.';
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

    IF v_result.mode <> v_ranked.mode
       OR v_result.variation <> v_ranked.variation
       OR v_result.total_questions <> v_ranked.question_count
       OR v_result.correct_answers + v_result.wrong_answers + v_result.skipped_answers <> v_result.total_questions THEN
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

REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) FROM anon;
REVOKE ALL ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.submit_ranked_result(TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) TO authenticated;

REVOKE ALL ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_challenge_from_ranked_session(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';

