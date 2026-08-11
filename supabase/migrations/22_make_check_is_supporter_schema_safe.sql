-- 22. Tornar check_is_supporter tolerante ao schema remoto
-- A view public.global_rankings nao deve falhar se os dados de supporter
-- ainda nao existirem no banco remoto. Nesse caso, retorna false.

CREATE OR REPLACE FUNCTION public.check_is_supporter(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private
AS $$
DECLARE
    v_sql TEXT;
    v_result BOOLEAN;
BEGIN
    IF to_regclass('private.supporter_entitlements') IS NULL THEN
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.supporter_entitlements'::regclass
          AND attname = 'user_id'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        RETURN FALSE;
    END IF;

    v_sql := 'SELECT EXISTS (SELECT 1 FROM private.supporter_entitlements WHERE user_id = $1';

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.supporter_entitlements'::regclass
          AND attname = 'status'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_sql := v_sql || ' AND status = ''active''';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.supporter_entitlements'::regclass
          AND attname = 'revoked_at'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_sql := v_sql || ' AND (revoked_at IS NULL OR revoked_at > NOW())';
    END IF;

    v_sql := v_sql || ')';

    EXECUTE v_sql USING p_user_id INTO v_result;
    RETURN COALESCE(v_result, FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.check_is_supporter(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_is_supporter(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.check_is_supporter(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
