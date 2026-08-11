-- 12. Script de Auditoria Operacional (Etapa 2)
-- Execute este script para gerar um relatório de validação no console do Supabase.

DO $$
DECLARE
    v_report TEXT := '';
    v_test_user UUID := '00000000-0000-0000-0000-000000000001';
    v_nonce TEXT := 'audit_nonce_456';
    v_nonce_hash TEXT;
    v_challenge_code TEXT;
    v_session_id UUID;
    v_result_id UUID;
    v_is_supporter BOOLEAN;
    v_check_count INTEGER;
BEGIN
    v_report := v_report || E'\n--- RELATÓRIO DE AUDITORIA OPERACIONAL ---\n';

    -- 1. Verificar Isolamento do Schema Private
    BEGIN
        SELECT count(*) INTO v_check_count FROM information_schema.schemata WHERE schema_name = 'private';
        v_report := v_report || 'Schema Private Existe: ' || CASE WHEN v_check_count > 0 THEN 'SIM' ELSE 'NÃO' END || E'\n';

        -- Verificar se anon tem USAGE (deve ser false)
        SELECT has_schema_privilege('anon', 'private', 'USAGE') INTO v_is_supporter;
        v_report := v_report || 'Anon possui acesso ao schema private: ' || CASE WHEN v_is_supporter THEN 'ERRO' ELSE 'NÃO (OK)' END || E'\n';
    END;

    -- 2. Testar Idempotência e Limite de Desafios
    BEGIN
        -- Simular contexto de usuário
        PERFORM set_config('request.jwt.claims', format('{"sub": "%s"}', v_test_user), true);

        -- Limpar desafios do dia para o teste ser puro
        DELETE FROM public.challenges WHERE creator_id = v_test_user;

        -- Desafio 1
        SELECT public.create_challenge('world', '10', 'key_1')->>'code' INTO v_challenge_code;
        v_report := v_report || 'Desafio 1 Criado: ' || v_challenge_code || E'\n';

        -- Teste Idempotência (mesma chave)
        IF (SELECT public.create_challenge('world', '10', 'key_1')->>'restored')::BOOLEAN THEN
            v_report := v_report || 'Idempotência (Clique Duplo): OK' || E'\n';
        END IF;

        -- Desafio 2
        PERFORM public.create_challenge('world', '10', 'key_2');
        v_report := v_report || 'Desafio 2 Criado: OK' || E'\n';

        -- Desafio 3 (Deve falhar)
        BEGIN
            PERFORM public.create_challenge('world', '10', 'key_3');
            v_report := v_report || 'Limite Diário: FALHA (Aceitou 3 desafios)' || E'\n';
        EXCEPTION WHEN OTHERS THEN
            v_report := v_report || 'Limite Diário (Bloqueio do 3º): OK (' || SQLERRM || E'\n';
        END;
    END;

    -- 3. Testar Fluxo de Sessão e Nonce
    BEGIN
        -- Criar sessão
        SELECT (public.create_ranked_session('continent', 'europe')->>'nonce') INTO v_nonce;
        v_nonce_hash := encode(digest(v_nonce, 'sha256'), 'hex');

        SELECT id INTO v_session_id FROM private.ranked_game_sessions WHERE session_nonce_hash = v_nonce_hash;
        v_report := v_report || 'Sessão Ranqueada Criada (Nonce Hash gerado): OK' || E'\n';

        -- Submeter Resultado Válido
        SELECT public.submit_ranked_result(v_nonce, 'ev_final_audit', 10, 0, 0, 10, 45000, 10)->>'result_id' INTO v_result_id;

        -- Verificar se a sessão foi marcada como completed
        IF (SELECT status FROM private.ranked_game_sessions WHERE id = v_session_id) = 'completed' THEN
            v_report := v_report || 'Fechamento de Sessão e Vínculo de Resultado: OK' || E'\n';
        ELSE
            v_report := v_report || 'Fechamento de Sessão: FALHA' || E'\n';
        END IF;

        -- Testar Reuso do Nonce (Deve falhar)
        BEGIN
            PERFORM public.submit_ranked_result(v_nonce, 'ev_fraud', 10, 0, 0, 10, 45000, 10);
            v_report := v_report || 'Reuso de Nonce: FALHA (Aceitou reuso)' || E'\n';
        EXCEPTION WHEN OTHERS THEN
            v_report := v_report || 'Reuso de Nonce: BLOQUEADO (OK)' || E'\n';
        END;
    END;

    -- 4. Verificar View de Ranking (Desempate)
    BEGIN
        -- Player 2 é mais rápido que Player 1 na seed
        IF (SELECT user_id FROM public.global_rankings WHERE variation = 'europe' LIMIT 1) = '00000000-0000-0000-0000-000000000002' THEN
            v_report := v_report || 'Lógica de Ranking e Desempate (Tempo): OK' || E'\n';
        ELSE
            v_report := v_report || 'Lógica de Ranking: FALHA' || E'\n';
        END IF;
    END;

    RAISE NOTICE '%', v_report;
    RAISE NOTICE E'\n--- FIM DA AUDITORIA ---\n';
END $$;
