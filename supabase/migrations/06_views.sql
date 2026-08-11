-- 6. Views Públicas

-- A migration 01 criou o enum public.supporter_status. Este nome conflita com
-- a view pública esperada abaixo, então renomeamos o enum já usado pelas
-- colunas existentes antes de criar a view.
DO $$
DECLARE
    v_values TEXT[];
BEGIN
    SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder)
    INTO v_values
    FROM pg_catalog.pg_type t
    JOIN pg_catalog.pg_namespace n
      ON n.oid = t.typnamespace
    LEFT JOIN pg_catalog.pg_enum e
      ON e.enumtypid = t.oid
    WHERE n.nspname = 'public'
      AND t.typname = 'supporter_status'
      AND t.typtype = 'e';

    IF v_values IS NULL THEN
        RAISE EXCEPTION 'Expected enum public.supporter_status was not found';
    END IF;

    IF v_values <> ARRAY['active', 'pending', 'revoked', 'refunded', 'invalid']::TEXT[] THEN
        RAISE EXCEPTION 'Unexpected values for enum public.supporter_status: %', v_values;
    END IF;

    ALTER TYPE public.supporter_status RENAME TO supporter_status_enum;
END;
$$;

-- View para verificar o status de apoiador (Lendo de private)
CREATE OR REPLACE VIEW public.supporter_status AS
SELECT
    p.id as user_id,
    EXISTS (
        SELECT 1 FROM private.supporter_entitlements e
        WHERE e.user_id = p.id
          AND status = 'active'
          AND (revoked_at IS NULL OR revoked_at > NOW())
    ) as is_supporter,
    (
        SELECT granted_at FROM private.supporter_entitlements e
        WHERE e.user_id = p.id
          AND status = 'active'
        ORDER BY granted_at ASC LIMIT 1
    ) as supporter_since
FROM public.profiles p;

-- View de Perfis Públicos
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
    p.id,
    p.nickname,
    p.country_code,
    p.avatar_key,
    s.is_supporter,
    p.created_at
FROM public.profiles p
LEFT JOIN public.supporter_status s ON p.id = s.user_id;

-- View de Ranking Oficial
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
    s.is_supporter
FROM best_results br
JOIN public.profiles p ON br.user_id = p.id
JOIN public.supporter_status s ON br.user_id = s.user_id
WHERE br.rank_priority = 1;
