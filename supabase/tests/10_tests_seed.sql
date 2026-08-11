-- 10. Dados de Desenvolvimento e Auditoria SQL

-- Nota: IDs de auth.users devem existir para as FKs funcionarem
-- Em um ambiente de desenvolvimento real, criaríamos usuários via Dashboard ou CLI.
-- Para esta seed, assumiremos que os IDs existem (ou desabilitar FKs apenas para seed se necessário)

INSERT INTO public.profiles (id, nickname, country_code) VALUES
('00000000-0000-0000-0000-000000000001', 'PlayerUm', 'BR'),
('00000000-0000-0000-0000-000000000002', 'ProFlagExpert', 'US'),
('00000000-0000-0000-0000-000000000003', 'ApoiadorFiel', 'PT');

INSERT INTO private.supporter_entitlements (user_id, product_id, status, source) VALUES
('00000000-0000-0000-0000-000000000003', 'flag_game_supporter', 'active', 'manual');

INSERT INTO public.game_results (event_id, user_id, mode, variation, score, correct_answers, total_questions, accuracy, elapsed_time_ms, is_ranked, verification_status) VALUES
('ev_01', '00000000-0000-0000-0000-000000000001', 'continent', 'europe', 10, 10, 10, 100, 45000, TRUE, 'verified'),
('ev_02', '00000000-0000-0000-0000-000000000002', 'continent', 'europe', 10, 10, 10, 100, 32000, TRUE, 'verified');
