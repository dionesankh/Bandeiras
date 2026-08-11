-- 16. Criar/corrigir a view pública usada pela tela de rankings
-- Corrige ambientes em que public.global_rankings não existe no schema public
-- ou não foi recarregada no schema cache do PostgREST.

CREATE OR REPLACE FUNCTION public.check_is_supporter(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM private.supporter_entitlements e
        WHERE e.user_id = p_user_id
          AND e.status = 'active'
          AND (e.revoked_at IS NULL OR e.revoked_at > NOW())
    );
END;
$$;

CREATE OR REPLACE VIEW public.global_rankings
WITH (security_invoker = false)
AS
WITH normalized_results AS (
    SELECT
        gr.user_id,
        COALESCE(
            to_jsonb(rgs)->>'mode',
            to_jsonb(gr)->>'mode',
            to_jsonb(gr)->>'game_mode',
            to_jsonb(gr)->>'ranking_mode'
        ) AS ranking_mode,
        COALESCE(
            to_jsonb(rgs)->>'variation',
            to_jsonb(gr)->>'variation',
            to_jsonb(gr)->>'ranking_variation'
        ) AS variation,
        COALESCE(
            NULLIF(to_jsonb(rgs)->>'rules_version', '')::INTEGER,
            NULLIF(to_jsonb(gr)->>'rules_version', '')::INTEGER,
            1
        ) AS rules_version,
        COALESCE(NULLIF(to_jsonb(gr)->>'score', '')::INTEGER, 0) AS score,
        COALESCE(
            NULLIF(to_jsonb(gr)->>'correct_answers', '')::INTEGER,
            NULLIF(to_jsonb(gr)->>'correct', '')::INTEGER,
            NULLIF(to_jsonb(gr)->>'score', '')::INTEGER,
            0
        ) AS correct_answers,
        COALESCE(
            NULLIF(to_jsonb(gr)->>'elapsed_time_ms', '')::INTEGER,
            NULLIF(to_jsonb(gr)->>'time_ms', '')::INTEGER,
            NULLIF(to_jsonb(gr)->>'duration_ms', '')::INTEGER,
            0
        ) AS elapsed_time_ms,
        COALESCE(NULLIF(to_jsonb(gr)->>'best_streak', '')::INTEGER, 0) AS best_streak,
        COALESCE(
            NULLIF(to_jsonb(gr)->>'created_at', '')::TIMESTAMPTZ,
            NULLIF(to_jsonb(gr)->>'received_at', '')::TIMESTAMPTZ,
            NOW()
        ) AS created_at
    FROM public.game_results gr
    LEFT JOIN private.ranked_game_sessions rgs
      ON rgs.id = gr.ranked_session_id
    WHERE COALESCE(NULLIF(to_jsonb(gr)->>'is_ranked', '')::BOOLEAN, gr.ranked_session_id IS NOT NULL) = TRUE
      AND COALESCE(NULLIF(to_jsonb(gr)->>'verification_status', ''), 'verified') = 'verified'
      AND COALESCE(NULLIF(to_jsonb(gr)->>'hearts_used', '')::BOOLEAN, FALSE) = FALSE
),
best_results AS (
    SELECT
        user_id,
        ranking_mode,
        variation,
        rules_version,
        score,
        correct_answers,
        elapsed_time_ms,
        best_streak,
        created_at AS achieved_at,
        ROW_NUMBER() OVER (
            PARTITION BY
                user_id,
                ranking_mode,
                variation,
                rules_version
            ORDER BY
                score DESC,
                correct_answers DESC,
                elapsed_time_ms ASC,
                best_streak DESC,
                created_at ASC
        ) AS result_priority
    FROM normalized_results
    WHERE ranking_mode IS NOT NULL
)
SELECT
    br.user_id,
    br.ranking_mode AS "mode",
    br.variation,
    br.score,
    br.correct_answers,
    br.elapsed_time_ms,
    br.best_streak,
    br.achieved_at,
    p.nickname,
    p.country_code,
    public.check_is_supporter(br.user_id) AS is_supporter,
    br.rules_version
FROM best_results br
JOIN public.profiles p
  ON p.id = br.user_id
WHERE br.result_priority = 1;

REVOKE ALL ON public.global_rankings FROM anon;
REVOKE ALL ON public.global_rankings FROM authenticated;
GRANT SELECT ON public.global_rankings TO authenticated;

REVOKE ALL ON FUNCTION public.check_is_supporter(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_is_supporter(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.check_is_supporter(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
