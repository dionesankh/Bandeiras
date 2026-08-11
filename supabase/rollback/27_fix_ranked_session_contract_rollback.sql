-- Rollback for 27_fix_ranked_session_contract.sql
--
-- Conservative and non-destructive:
-- - does not drop ranked_game_sessions columns;
-- - does not delete ranked results or challenges;
-- - keeps submit_ranked_result compatible with already-created sessions;
-- - restores create_ranked_session to the pre-protected-sequence behavior.
--
-- After this rollback, newly created ranked sessions will not include
-- question_codes/sequence_hash and therefore remain ineligible for promotion
-- to friend challenges. Apply a new corrective migration to re-enable that.

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
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
    v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');

    INSERT INTO private.ranked_game_sessions (
        user_id,
        session_nonce_hash,
        mode,
        variation,
        expires_at
    )
    VALUES (
        v_user_id,
        v_nonce_hash,
        p_mode,
        p_variation,
        v_expires_at
    )
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'ranked_session_id', v_session_id,
        'nonce', v_nonce,
        'expires_at', v_expires_at
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
