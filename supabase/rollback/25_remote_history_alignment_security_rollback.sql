-- Rollback for 25_remote_history_alignment_security.sql
--
-- Local-only. Do not execute unless migration 25 has been applied and a
-- rollback is explicitly approved.
--
-- Restores the previous audited remote posture as closely as possible:
-- - broad direct grants on public.profiles and public.supporter_status;
-- - previous public profiles policies;
-- - broad EXECUTE on public.create_ranked_session;
-- - removes profile RPCs that were absent in the audited remote schema;
-- - restores submit_ranked_result to the pre-25 corrective implementation,
--   including the old expired-status update behavior.

REVOKE ALL ON TABLE public.profiles FROM PUBLIC;
REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.profiles FROM authenticated;

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;

DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
DROP POLICY IF EXISTS "Acesso público" ON public.profiles;
DROP POLICY IF EXISTS "Update próprio" ON public.profiles;

CREATE POLICY "Acesso público"
ON public.profiles
FOR SELECT
TO PUBLIC
USING (true);

CREATE POLICY "Update próprio"
ON public.profiles
FOR UPDATE
TO PUBLIC
USING (auth.uid() = id);

REVOKE ALL ON TABLE public.supporter_status FROM PUBLIC;
REVOKE ALL ON TABLE public.supporter_status FROM anon;
REVOKE ALL ON TABLE public.supporter_status FROM authenticated;

GRANT ALL ON TABLE public.supporter_status TO anon;
GRANT ALL ON TABLE public.supporter_status TO authenticated;

REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO authenticated;

DROP FUNCTION IF EXISTS public.get_public_profile(UUID);
DROP FUNCTION IF EXISTS public.get_supporter_profile_details(UUID);

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
    v_result_id UUID;
    v_calculated_score INTEGER;
    v_calculated_accuracy NUMERIC;
    v_payload JSONB;
    v_columns TEXT;
    v_values TEXT;
    v_insert_sql TEXT;
    v_stage TEXT := 'start';
    v_error_state TEXT;
    v_error_message TEXT;
BEGIN
    v_stage := 'auth';
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    v_stage := 'hash_nonce';
    v_nonce_hash := encode(extensions.digest(p_nonce, 'sha256'), 'hex');

    v_stage := 'load_session';
    SELECT to_jsonb(s) INTO v_session_json
    FROM private.ranked_game_sessions s
    WHERE s.session_nonce_hash = v_nonce_hash
      AND s.user_id = v_user_id
      AND s.status = 'created'
    FOR UPDATE;

    IF v_session_json IS NULL THEN RAISE EXCEPTION 'Invalid session or already used'; END IF;

    v_session_id := (v_session_json->>'id')::UUID;

    v_stage := 'check_expiration';
    IF (v_session_json->>'expires_at')::TIMESTAMPTZ < NOW() THEN
        UPDATE private.ranked_game_sessions
        SET status = 'expired'
        WHERE id = v_session_id;
        RAISE EXCEPTION 'Session expired';
    END IF;

    v_stage := 'validate_numbers';
    IF (p_correct + p_wrong + p_skipped) != p_total OR p_total <= 0 THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    v_stage := 'calculate_score';
    v_calculated_score := p_correct;
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    v_stage := 'build_payload';
    v_payload := jsonb_build_object(
        'event_id', p_event_id,
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

    v_stage := 'complete_session_status';
    UPDATE private.ranked_game_sessions
    SET status = 'completed'
    WHERE id = v_session_id;

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.ranked_game_sessions'::regclass
          AND attname = 'completed_at'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_stage := 'complete_session_completed_at';
        EXECUTE 'UPDATE private.ranked_game_sessions SET completed_at = NOW() WHERE id = $1'
        USING v_session_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.ranked_game_sessions'::regclass
          AND attname = 'result_id'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_stage := 'complete_session_result_id';
        EXECUTE 'UPDATE private.ranked_game_sessions SET result_id = $1 WHERE id = $2'
        USING v_result_id, v_session_id;
    END IF;

    RETURN jsonb_build_object('result_id', v_result_id, 'status', 'verified');
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
        HINT = 'Check required columns, constraints, enum values, and session status.';
END;
$$;

REVOKE ALL ON FUNCTION public.submit_ranked_result(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.submit_ranked_result(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER
) FROM anon;

GRANT EXECUTE ON FUNCTION public.submit_ranked_result(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER
) TO authenticated;

NOTIFY pgrst, 'reload schema';
