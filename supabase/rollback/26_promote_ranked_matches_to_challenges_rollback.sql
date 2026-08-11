-- Rollback for 26_promote_ranked_matches_to_challenges.sql
-- Run only if you intentionally need to remove ranked-to-friend challenge support.
-- Existing ranked results are preserved. Existing challenges are preserved.
-- After this rollback, newly created ranked sessions no longer contain a
-- protected sequence and therefore cannot be promoted to friend challenges.

DROP FUNCTION IF EXISTS public.create_challenge_from_ranked_session(UUID, TEXT);

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
        'nonce', v_nonce,
        'expires_at', v_expires_at
    );
END;
$$;

DROP INDEX IF EXISTS private.idx_ranked_sessions_promotion_idempotency;
DROP INDEX IF EXISTS private.idx_ranked_sessions_challenge_id;

ALTER TABLE private.ranked_game_sessions
  DROP CONSTRAINT IF EXISTS ranked_game_sessions_challenge_id_fkey,
  DROP CONSTRAINT IF EXISTS ranked_game_sessions_question_count_positive,
  DROP CONSTRAINT IF EXISTS ranked_game_sessions_question_codes_array,
  DROP COLUMN IF EXISTS promotion_idempotency_key,
  DROP COLUMN IF EXISTS challenge_id,
  DROP COLUMN IF EXISTS sequence_hash,
  DROP COLUMN IF EXISTS question_count,
  DROP COLUMN IF EXISTS question_codes,
  DROP COLUMN IF EXISTS algorithm_version,
  DROP COLUMN IF EXISTS seed;

REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
