-- 17. Corrigir resolução de funções do pgcrypto na criação de sessão ranqueada
-- Não reinstala extensões e não altera search_path global.
-- Apenas recria a RPC existente qualificando chamadas ao schema extensions.

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
    v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
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

GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
