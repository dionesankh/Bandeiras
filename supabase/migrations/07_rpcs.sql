-- 7. Funções RPC (Lógica Atômica)

-- 7.1 Garantir Perfil
CREATE OR REPLACE FUNCTION public.ensure_profile(p_nickname TEXT, p_country CHAR(2))
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    INSERT INTO public.profiles (id, nickname, country_code)
    VALUES (v_user_id, p_nickname, p_country)
    ON CONFLICT (id) DO UPDATE SET
        updated_at = NOW()
    WHERE profiles.id = v_user_id;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'id', v_profile.id,
        'nickname', v_profile.nickname,
        'country_code', v_profile.country_code
    );
END;
$$;

-- 7.2 Criar Sessão Ranqueada
CREATE OR REPLACE FUNCTION public.create_ranked_session(p_mode TEXT, p_variation TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce TEXT;
    v_nonce_hash TEXT;
    v_session_id UUID;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '30 minutes';
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    -- Gerar nonce aleatório (32 bytes)
    v_nonce := encode(gen_random_bytes(32), 'hex');
    v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');

    INSERT INTO private.ranked_game_sessions (user_id, session_nonce_hash, mode, variation, expires_at)
    VALUES (v_user_id, v_nonce_hash, p_mode, p_variation, v_expires_at)
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'nonce', v_nonce,
        'expires_at', v_expires_at
    );
END;
$$;

-- 7.3 Submeter Resultado Ranqueado
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

    -- Validação Matemática Rigorosa
    IF (p_correct + p_wrong + p_skipped) != p_total OR p_total <= 0 THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    -- Recálculo de Score e Accuracy no Servidor (Prevenção de alteração no cliente)
    v_calculated_score := p_correct; -- Lógica básica: 1 ponto por acerto
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    -- Registrar Resultado
    INSERT INTO public.game_results (
        event_id, user_id, ranked_session_id, mode, variation,
        score, correct_answers, wrong_answers, skipped_answers, total_questions,
        accuracy, elapsed_time_ms, best_streak, is_ranked, verification_status
    )
    VALUES (
        p_event_id, v_user_id, v_session.id, v_session.mode, v_session.variation,
        v_calculated_score, p_correct, p_wrong, p_skipped, p_total,
        v_calculated_accuracy, p_time_ms, p_streak, TRUE, 'verified'
    )
    RETURNING id INTO v_result_id;

    -- Concluir Sessão Atômicamente
    UPDATE private.ranked_game_sessions
    SET status = 'completed', completed_at = NOW(), result_id = v_result_id
    WHERE id = v_session.id;

    RETURN jsonb_build_object('result_id', v_result_id, 'status', 'verified');
END;
$$;

-- 7.4 Criar Desafio (Com Idempotency Key e Lock por Usuário)
CREATE OR REPLACE FUNCTION public.create_challenge(
    p_mode TEXT,
    p_variation TEXT,
    p_config JSONB,
    p_idempotency_key TEXT,
    p_allow_hearts BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_supporter BOOLEAN;
    v_daily_count INTEGER;
    v_code TEXT;
    v_challenge_id UUID;
    v_today DATE := (NOW() AT TIME ZONE 'UTC')::DATE;
    v_existing_id UUID;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    -- 1. Verificar Idempotência (Evita duplicados por cliques rápidos)
    SELECT id, code INTO v_challenge_id, v_code FROM public.challenges WHERE idempotency_key = p_idempotency_key AND creator_id = v_user_id;
    IF FOUND THEN
        RETURN jsonb_build_object('challenge_id', v_challenge_id, 'code', v_code, 'restored', true);
    END IF;

    -- 2. Lock Consultivo por Usuário (Evita race condition na cota diária)
    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

    -- 3. Verificar Status de Apoiador
    SELECT is_supporter INTO v_is_supporter FROM public.supporter_status WHERE user_id = v_user_id;

    -- 4. Validar Cota para Gratuitos
    IF NOT v_is_supporter THEN
        SELECT count(*) INTO v_daily_count
        FROM public.challenges
        WHERE creator_id = v_user_id
          AND created_at::DATE = v_today;

        IF v_daily_count >= 2 THEN
            RAISE EXCEPTION 'Daily limit of 2 challenges reached';
        END IF;
    END IF;

    -- 5. Gerar Código Único
    v_code := 'FG-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' || upper(substring(md5(random()::text) from 5 for 4));

    -- 6. Inserir Desafio
    INSERT INTO public.challenges (creator_id, code, mode, variation, config, allow_hearts, idempotency_key, expires_at)
    VALUES (v_user_id, v_code, p_mode, p_variation, p_config, p_allow_hearts, p_idempotency_key, NOW() + INTERVAL '7 days')
    RETURNING id INTO v_challenge_id;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge_id,
        'code', v_code,
        'remaining_daily', CASE WHEN v_is_supporter THEN -1 ELSE 2 - (v_daily_count + 1) END
    );
END;
$$;

-- 7.5 Consultar Cota Diária
CREATE OR REPLACE FUNCTION public.get_daily_challenge_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_supporter BOOLEAN;
    v_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN RETURN jsonb_build_object('error', 'unauthorized'); END IF;

    SELECT is_supporter INTO v_is_supporter FROM public.supporter_status WHERE user_id = v_user_id;

    SELECT count(*) INTO v_count
    FROM public.challenges
    WHERE creator_id = v_user_id
      AND created_at::DATE = (NOW() AT TIME ZONE 'UTC')::DATE;

    RETURN jsonb_build_object(
        'is_supporter', v_is_supporter,
        'used_today', v_count,
        'limit', CASE WHEN v_is_supporter THEN -1 ELSE 2 END
    );
END;
$$;

-- 7.6 Obter meu status de apoiador
CREATE OR REPLACE FUNCTION public.get_my_supporter_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
BEGIN
    RETURN (SELECT row_to_json(s)::jsonb FROM public.supporter_status s WHERE user_id = auth.uid());
END;
$$;

-- 7.7 Vincular Identidade (BLOQUEADA PARA FUTURA EDGE FUNCTION)
CREATE OR REPLACE FUNCTION public.link_player_identity(p_provider TEXT, p_player_id TEXT, p_legacy_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public, auth
AS $$
BEGIN
    -- Esta função está preparada para ser chamada somente por um processo verificado
    -- Atualmente bloqueada para chamadas diretas do cliente sem verificação extra
    RAISE EXCEPTION 'Identity linking requires server-side verification';
END;
$$;

-- 7.8 Aceitar Desafio
CREATE OR REPLACE FUNCTION public.accept_challenge(p_challenge_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_challenge RECORD;
    v_participant_id UUID;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    SELECT * INTO v_challenge FROM public.challenges WHERE code = p_challenge_code AND status = 'open' AND expires_at > NOW();
    IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found or expired'; END IF;

    INSERT INTO public.challenge_participants (challenge_id, user_id, status)
    VALUES (v_challenge.id, v_user_id, 'accepted')
    ON CONFLICT (challenge_id, user_id) DO NOTHING
    RETURNING id INTO v_participant_id;

    RETURN jsonb_build_object('challenge_id', v_challenge.id, 'status', 'accepted');
END;
$$;

-- 7.9 Submeter Resultado de Desafio
CREATE OR REPLACE FUNCTION public.submit_challenge_result(
    p_challenge_id UUID,
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
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_challenge RECORD;
    v_result_id UUID;
    v_accuracy NUMERIC := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    SELECT * INTO v_challenge FROM public.challenges WHERE id = p_challenge_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Challenge not found'; END IF;

    -- Registrar como resultado normal (não ranqueado globalmente, mas verificado para o desafio)
    INSERT INTO public.game_results (
        event_id, user_id, mode, variation,
        score, correct_answers, wrong_answers, skipped_answers, total_questions,
        accuracy, elapsed_time_ms, best_streak, is_ranked, verification_status
    )
    VALUES (
        p_event_id, v_user_id, v_challenge.mode, v_challenge.variation,
        p_correct, p_correct, p_wrong, p_skipped, p_total,
        v_accuracy, p_time_ms, p_streak, FALSE, 'verified'
    )
    RETURNING id INTO v_result_id;

    UPDATE public.challenge_participants
    SET status = 'completed', completed_at = NOW(), result_id = v_result_id,
        final_score = p_correct, final_accuracy = v_accuracy
    WHERE challenge_id = p_challenge_id AND user_id = v_user_id;

    RETURN jsonb_build_object('result_id', v_result_id, 'status', 'completed');
END;
$$;

-- 7.10 Obter Perfil Público (Respeitando Privacidade)
CREATE OR REPLACE FUNCTION public.get_public_profile(p_target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile RECORD;
BEGIN
    SELECT * INTO v_profile FROM public.public_profiles WHERE id = p_target_user_id;
    IF NOT FOUND THEN RETURN NULL; END IF;

    RETURN jsonb_build_object(
        'id', v_profile.id,
        'nickname', v_profile.nickname,
        'country_code', v_profile.country_code,
        'avatar_key', v_profile.avatar_key,
        'is_supporter', v_profile.is_supporter,
        'created_at', v_profile.created_at
    );
END;
$$;

-- 7.11 Obter Detalhes de Apoiador (Somente se o chamador for apoiador e o alvo permitir)
CREATE OR REPLACE FUNCTION public.get_supporter_profile_details(p_target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_viewer_id UUID := auth.uid();
    v_is_viewer_supporter BOOLEAN;
    v_target_privacy JSONB;
    v_target_profile RECORD;
BEGIN
    IF v_viewer_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    -- 1. Verificar se o chamador é apoiador
    SELECT is_supporter INTO v_is_viewer_supporter FROM public.supporter_status WHERE user_id = v_viewer_id;
    IF NOT v_is_viewer_supporter AND v_viewer_id != p_target_user_id THEN
        RAISE EXCEPTION 'Detailed stats are exclusive to supporters';
    END IF;

    -- 2. Obter privacidade do alvo
    SELECT privacy_settings INTO v_target_privacy FROM public.profiles WHERE id = p_target_user_id;

    -- 3. Respeitar privacidade (a menos que seja o próprio usuário)
    IF v_viewer_id != p_target_user_id AND NOT (v_target_privacy->>'show_detailed_stats')::BOOLEAN THEN
        RAISE EXCEPTION 'This user has kept their statistics private';
    END IF;

    -- 4. Retornar estatísticas agregadas (Exemplo: totals)
    RETURN (
        SELECT jsonb_build_object(
            'total_games', count(*),
            'total_score', sum(score),
            'avg_accuracy', avg(accuracy)
        )
        FROM public.game_results
        WHERE user_id = p_target_user_id
    );
END;
$$;
