-- 13. Correção da Assinatura da RPC ensure_profile
-- Esta migration resolve problemas de resolução de tipos (schema cache) ao padronizar argumentos para TEXT.

-- 1. Remover assinaturas antigas para evitar sobrecarga ou conflitos
-- Nota: Identificamos que a assinatura anterior usava CHAR(2), que mapeia para 'character' ou 'bpchar'.
DROP FUNCTION IF EXISTS public.ensure_profile(text, character);
DROP FUNCTION IF EXISTS public.ensure_profile(text, bpchar);
DROP FUNCTION IF EXISTS public.ensure_profile(text, text);

-- 2. Criar a nova assinatura única e flexível
CREATE OR REPLACE FUNCTION public.ensure_profile(
    p_nickname TEXT DEFAULT 'Player',
    p_country TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
    v_clean_nickname TEXT;
    v_clean_country CHAR(2);
BEGIN
    -- Validação de Autenticação
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    -- Validação e Sanitização do Apelido (Nickname) no Banco
    -- Mínimo 3, máximo 24, apenas alfanuméricos, espaços, hifens e underscores.
    v_clean_nickname := trim(p_nickname);
    IF v_clean_nickname IS NULL OR char_length(v_clean_nickname) < 3 OR v_clean_nickname !~ '^[a-zA-Z0-9 _-]+$' THEN
        v_clean_nickname := 'Player';
    END IF;
    v_clean_nickname := substring(v_clean_nickname from 1 for 24);

    -- Validação e Sanitização do País (Country)
    -- Deve ser exatamente 2 letras (A-Z).
    v_clean_country := upper(trim(p_country));
    IF v_clean_country !~ '^[A-Z]{2}$' THEN
        v_clean_country := NULL;
    END IF;

    -- Operação Idempotente: Inserir se não existir, atualizar apenas meta se existir
    -- Nota: Não sobrescrevemos o nickname de um perfil já criado para preservar escolhas do usuário.
    INSERT INTO public.profiles (id, nickname, country_code)
    VALUES (v_user_id, v_clean_nickname, v_clean_country)
    ON CONFLICT (id) DO UPDATE SET
        updated_at = NOW()
    WHERE profiles.id = v_user_id;

    -- Obter o registro final para retorno
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'id', v_profile.id,
        'nickname', v_profile.nickname,
        'country_code', v_profile.country_code,
        'avatar_key', v_profile.avatar_key,
        'updated_at', v_profile.updated_at
    );
END;
$$;

-- 3. Configurações de Segurança e Permissões
REVOKE ALL ON FUNCTION public.ensure_profile(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ensure_profile(text, text) FROM anon;

GRANT EXECUTE ON FUNCTION public.ensure_profile(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_profile(text, text) TO service_role;

-- 4. Forçar recarregamento do schema cache do PostgREST
NOTIFY pgrst, 'reload schema';
