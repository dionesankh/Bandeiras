-- Frontend-compatible rollback for 25_remote_history_alignment_security.sql
--
-- Local-only. Do not execute unless migration 25 has been applied and this
-- rollback mode is explicitly approved.
--
-- This option is intentionally different from the full rollback:
-- - restores the broader direct grants/policies observed before migration 25;
-- - keeps RPCs used by the current frontend, including:
--   public.get_public_profile(uuid)
--   public.get_supporter_profile_details(uuid)
--   public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)
-- - keeps the fixed submit_ranked_result expiration behavior from migration 25.
--
-- Use this if migration 25 causes frontend access regressions, but the app still
-- needs the newer RPC contract.

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

-- Restore the broader create_ranked_session grants observed before migration 25
-- while retaining authenticated access.
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION public.create_ranked_session(TEXT, TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.create_ranked_session(TEXT, TEXT) TO authenticated;

-- Keep current frontend RPCs available.
GRANT EXECUTE ON FUNCTION public.get_public_profile(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_supporter_profile_details(UUID) TO authenticated;
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

GRANT EXECUTE ON FUNCTION public.start_challenge_base_match(TEXT, TEXT) TO authenticated;
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
GRANT EXECUTE ON FUNCTION public.get_challenge_preview(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_challenge(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_challenge_session(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_challenge_result(
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
