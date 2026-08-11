-- 14. Correção de Visibilidade do Ranking
-- A view global_rankings dependia de uma view (supporter_status) que por sua vez lia de uma tabela privada (private.supporter_entitlements) protegida por RLS.
-- Isso causava a filtragem de todos os outros usuários no ranking (invoker-rights).
-- Resolvemos movendo a lógica de verificação de supporter para uma função SECURITY DEFINER.

CREATE OR REPLACE FUNCTION public.check_is_supporter(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM private.supporter_entitlements
        WHERE user_id = p_user_id
          AND status = 'active'
          AND (revoked_at IS NULL OR revoked_at > NOW())
    );
END;
$$;

-- Atualizar View de Ranking para usar a função segura
CREATE OR REPLACE VIEW public.global_rankings AS
WITH best_results AS (
    SELECT
        user_id,
        mode,
        variation,
        score,
        correct_answers,
        elapsed_time_ms,
        best_streak,
        created_at as achieved_at,
        ROW_NUMBER() OVER (
            PARTITION BY user_id, mode, variation
            ORDER BY
                score DESC,
                correct_answers DESC,
                elapsed_time_ms ASC,
                best_streak DESC,
                created_at ASC
        ) as rank_priority
    FROM public.game_results
    WHERE is_ranked = TRUE
      AND verification_status = 'verified'
      AND hearts_used = FALSE
)
SELECT
    br.user_id,
    br.mode,
    br.variation,
    br.score,
    br.correct_answers,
    br.elapsed_time_ms,
    br.best_streak,
    br.achieved_at,
    p.nickname,
    p.country_code,
    public.check_is_supporter(br.user_id) as is_supporter
FROM best_results br
JOIN public.profiles p ON br.user_id = p.id
WHERE br.rank_priority = 1;

-- Garantir permissão
GRANT SELECT ON public.global_rankings TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_is_supporter TO authenticated;
