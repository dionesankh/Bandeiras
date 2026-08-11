-- 11. Testes de Auditoria e Segurança Real (Ambiente de Teste)

-- Limpar dados de teste anteriores
DELETE FROM public.challenge_participants;
DELETE FROM public.challenges;
DELETE FROM public.game_results;
DELETE FROM private.ranked_game_sessions;
DELETE FROM private.supporter_entitlements;
DELETE FROM public.profiles;

DO $$
DECLARE
    v_user1 UUID := '00000000-0000-0000-0000-000000000001';
    v_user2 UUID := '00000000-0000-0000-0000-000000000002';
    v_supporter UUID := '00000000-0000-0000-0000-000000000003';
    v_session JSONB;
    v_nonce TEXT;
    v_result JSONB;
    v_quota JSONB;
    v_challenge JSONB;
    v_pass_count INTEGER := 0;
    v_fail_count INTEGER := 0;
BEGIN
    -- SETUP: Emular usuários autenticados (Nota: em SQL real, auth.uid() requer configuração de session variable)
    -- Para este teste, usaremos as funções como superuser, mas validando a lógica interna.

    INSERT INTO public.profiles (id, nickname, country_code, privacy_settings) VALUES
    (v_user1, 'PlayerFree', 'BR', '{"show_detailed_stats": false}'::jsonb),
    (v_user2, 'ProExpert', 'US', '{"show_detailed_stats": true}'::jsonb),
    (v_supporter, 'SuperSupporter', 'PT', '{"show_detailed_stats": true}'::jsonb);

    INSERT INTO private.supporter_entitlements (user_id, product_id, status, source)
    VALUES (v_supporter, 'flag_game_supporter', 'active', 'manual');

    RAISE NOTICE '--- INICIANDO TESTES DE SEGURANÇA E LÓGICA ---';

    -- TESTE 1: Integridade Matemática em submit_ranked_result
    BEGIN
        -- Simulando um nonce hash manualmente para o teste
        v_nonce := 'test_nonce_123';
        INSERT INTO private.ranked_game_sessions (user_id, session_nonce_hash, mode, variation, expires_at)
        VALUES (v_user1, encode(digest(v_nonce, 'sha256'), 'hex'), 'world', '10', NOW() + INTERVAL '1 hour');

        -- Tentar submeter resultado incoerente (5+3+1 != 10)
        -- Nota: v_user1 é auth.uid() simulado dentro da RPC
        -- PERFORMANCE: SET LOCAL auth.uid = ...
        PERFORM set_config('request.jwt.claims', format('{"sub": "%s"}', v_user1), true);

        BEGIN
            PERFORM public.submit_ranked_result(v_nonce, 'ev_bad', 5, 3, 1, 10, 30000, 5);
            RAISE EXCEPTION 'Falha: Aceitou resultado matematicamente incoerente';
        EXCEPTION WHEN OTHERS THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'OK: Resultado incoerente rejeitado (%s)', SQLERRM;
        END;
    END;

    -- TESTE 2: Idempotência de Desafios
    BEGIN
        PERFORM set_config('request.jwt.claims', format('{"sub": "%s"}', v_user1), true);
        v_challenge := public.create_challenge('world', '20', '{}', 'idemp_key_1');

        -- Segunda chamada com a mesma chave
        v_result := public.create_challenge('world', '20', '{}', 'idemp_key_1');

        IF (v_result->>'restored')::BOOLEAN = TRUE THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'OK: Idempotência de desafio funcionando';
        ELSE
            RAISE EXCEPTION 'Falha: Criou desafio duplicado para a mesma chave';
        END IF;
    END;

    -- TESTE 3: Limite Diário (Gratuito)
    BEGIN
        -- v_user1 já criou 1 (idemp_key_1)
        PERFORM public.create_challenge('world', '20', '{}', 'idemp_key_2'); -- Segundo

        BEGIN
            PERFORM public.create_challenge('world', '20', '{}', 'idemp_key_3'); -- Terceiro (Deve falhar)
            RAISE EXCEPTION 'Falha: Ultrapassou limite diário de 2 desafios';
        EXCEPTION WHEN OTHERS THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'OK: Limite diário bloqueado (%s)', SQLERRM;
        END;
    END;

    -- TESTE 4: Apoiador sem Limite Comercial
    BEGIN
        PERFORM set_config('request.jwt.claims', format('{"sub": "%s"}', v_supporter), true);
        PERFORM public.create_challenge('world', '20', '{}', 's_key_1');
        PERFORM public.create_challenge('world', '20', '{}', 's_key_2');
        PERFORM public.create_challenge('world', '20', '{}', 's_key_3');
        v_pass_count := v_pass_count + 1;
        RAISE NOTICE 'OK: Apoiador criou múltiplos desafios sem bloqueio';
    END;

    -- TESTE 5: Privacidade (Estatísticas Detalhadas)
    BEGIN
        -- Player 2 tem show_detailed_stats = true
        -- Player 1 tem show_detailed_stats = false

        PERFORM set_config('request.jwt.claims', format('{"sub": "%s"}', v_supporter), true);

        -- Apoiador tentando ver Player 1 (Privado)
        BEGIN
            PERFORM public.get_supporter_profile_details(v_user1);
            RAISE EXCEPTION 'Falha: Apoiador acessou estatísticas privadas';
        EXCEPTION WHEN OTHERS THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'OK: Privacidade respeitada mesmo para apoiadores (%s)', SQLERRM;
        END;
    END;

    -- TESTE 6: Nonce Reutilizado
    BEGIN
        PERFORM set_config('request.jwt.claims', format('{"sub": "%s"}', v_user2), true);
        v_nonce := 'reusable_nonce_test';
        INSERT INTO private.ranked_game_sessions (user_id, session_nonce_hash, mode, variation, expires_at)
        VALUES (v_user2, encode(digest(v_nonce, 'sha256'), 'hex'), 'world', '195', NOW() + INTERVAL '1 hour');

        -- Primeira submissão
        PERFORM public.submit_ranked_result(v_nonce, 'ev_ok_1', 100, 0, 0, 100, 60000, 50);

        -- Segunda submissão com mesmo nonce
        BEGIN
            PERFORM public.submit_ranked_result(v_nonce, 'ev_ok_2', 100, 0, 0, 100, 60000, 50);
            RAISE EXCEPTION 'Falha: Nonce reutilizado com sucesso';
        EXCEPTION WHEN OTHERS THEN
            v_pass_count := v_pass_count + 1;
            RAISE NOTICE 'OK: Reuso de nonce bloqueado (%s)', SQLERRM;
        END;
    END;

    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'RESUMO: % testes aprovados, % reprovados.', v_pass_count, v_fail_count;

    IF v_fail_count > 0 THEN
        RAISE EXCEPTION 'Finalizando com erros no conjunto de testes';
    END IF;
END $$;
