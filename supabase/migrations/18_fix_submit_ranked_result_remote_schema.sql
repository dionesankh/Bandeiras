-- 18. Corrigir submissão de resultado ranqueado para schema remoto
-- Não altera JavaScript nem interface. Qualifica funções em extensions e evita
-- inserir colunas que não existem no public.game_results remoto.

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
    v_session RECORD;
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

    -- Localizar sessão com bloqueio de linha para evitar concorrência
    SELECT * INTO v_session
    FROM private.ranked_game_sessions
    WHERE session_nonce_hash = v_nonce_hash
      AND user_id = v_user_id
      AND status = 'created'
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Invalid session or already used'; END IF;
    IF v_session.expires_at < NOW() THEN
        UPDATE private.ranked_game_sessions SET status = 'expired' WHERE id = v_session.id;
        RAISE EXCEPTION 'Session expired';
    END IF;

    -- Validação matemática rigorosa
    IF (p_correct + p_wrong + p_skipped) != p_total OR p_total <= 0 THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    -- Recálculo de score e accuracy no servidor
    v_calculated_score := p_correct;
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    v_payload := jsonb_build_object(
        'event_id', p_event_id,
        'user_id', v_user_id,
        'ranked_session_id', v_session.id,
        'mode', v_session.mode,
        'variation', v_session.variation,
        'rules_version', COALESCE(v_session.rules_version, 1),
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

    -- Concluir sessão atomicamente
    UPDATE private.ranked_game_sessions
    SET status = 'completed', completed_at = NOW(), result_id = v_result_id
    WHERE id = v_session.id;

    RETURN jsonb_build_object('result_id', v_result_id, 'status', 'verified');
END;
$$;

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
