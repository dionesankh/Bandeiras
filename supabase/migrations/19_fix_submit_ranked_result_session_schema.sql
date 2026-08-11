-- 19. Corrigir submissao ranqueada para schemas remotos sem colunas opcionais
-- Mantem a assinatura da RPC, SECURITY DEFINER, search_path seguro, auth.uid(),
-- validacoes, nonce, expiracao e grants. Nao reinstala extensoes.

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
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    v_nonce_hash := encode(extensions.digest(p_nonce, 'sha256'), 'hex');

    -- Localizar sessao com bloqueio de linha para evitar concorrencia.
    -- to_jsonb evita falha runtime quando o remoto nao tem colunas opcionais.
    SELECT to_jsonb(s) INTO v_session_json
    FROM private.ranked_game_sessions s
    WHERE s.session_nonce_hash = v_nonce_hash
      AND s.user_id = v_user_id
      AND s.status = 'created'
    FOR UPDATE;

    IF v_session_json IS NULL THEN RAISE EXCEPTION 'Invalid session or already used'; END IF;

    v_session_id := (v_session_json->>'id')::UUID;

    IF (v_session_json->>'expires_at')::TIMESTAMPTZ < NOW() THEN
        UPDATE private.ranked_game_sessions
        SET status = 'expired'
        WHERE id = v_session_id;
        RAISE EXCEPTION 'Session expired';
    END IF;

    -- Validacao matematica rigorosa
    IF (p_correct + p_wrong + p_skipped) != p_total OR p_total <= 0 THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    -- Recalculo de score e accuracy no servidor
    v_calculated_score := p_correct;
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

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

    v_insert_sql := format(
        'INSERT INTO public.game_results (%s) VALUES (%s) RETURNING id',
        v_columns,
        v_values
    );

    EXECUTE v_insert_sql USING v_payload INTO v_result_id;

    -- Concluir sessao. completed_at e result_id sao opcionais no remoto.
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
        EXECUTE 'UPDATE private.ranked_game_sessions SET result_id = $1 WHERE id = $2'
        USING v_result_id, v_session_id;
    END IF;

    RETURN jsonb_build_object('result_id', v_result_id, 'status', 'verified');
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
