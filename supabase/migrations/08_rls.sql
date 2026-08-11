-- 8. Políticas de RLS e GRANTS Efetivos

-- 8.1 Limpeza de Permissões (Princípio do Menor Privilégio)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA private FROM anon, authenticated;

-- 8.2 Habilitar RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.player_identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.supporter_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.ranked_game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;

-- 8.3 Políticas: Perfis
GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT UPDATE(nickname, country_code, avatar_key, privacy_settings) ON public.profiles TO authenticated;

CREATE POLICY "Perfis visíveis para todos" ON public.profiles FOR SELECT USING (TRUE);
CREATE POLICY "Dono edita campos permitidos" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- 8.4 Políticas: Identidades
GRANT SELECT ON private.player_identities TO authenticated;
CREATE POLICY "Dono vê suas identidades" ON private.player_identities FOR SELECT USING (auth.uid() = user_id);

-- 8.5 Políticas: Entitlements
GRANT SELECT ON private.supporter_entitlements TO authenticated;
CREATE POLICY "Dono vê seus entitlements" ON private.supporter_entitlements FOR SELECT USING (auth.uid() = user_id);

-- 8.6 Políticas: Resultados
GRANT SELECT ON public.game_results TO authenticated;
CREATE POLICY "Dono vê seus resultados" ON public.game_results FOR SELECT USING (auth.uid() = user_id);

-- 8.7 Políticas: Sessões
GRANT SELECT ON private.ranked_game_sessions TO authenticated;
CREATE POLICY "Dono vê suas sessões" ON private.ranked_game_sessions FOR SELECT USING (auth.uid() = user_id);

-- 8.8 Políticas: Desafios
GRANT SELECT ON public.challenges TO anon, authenticated;
CREATE POLICY "Desafios abertos visíveis" ON public.challenges FOR SELECT USING (status = 'open' AND expires_at > NOW());
CREATE POLICY "Dono gerencia seus desafios" ON public.challenges FOR ALL USING (auth.uid() = creator_id);

-- 8.9 Políticas: Participantes
GRANT SELECT ON public.challenge_participants TO authenticated;
CREATE POLICY "Ver meus dados no desafio" ON public.challenge_participants FOR SELECT USING (auth.uid() = user_id);

-- 8.10 GRANTS para Views e Funções
GRANT SELECT ON public.supporter_status TO authenticated;
GRANT SELECT ON public.public_profiles TO anon, authenticated;
GRANT SELECT ON public.global_rankings TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.ensure_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_ranked_session TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_ranked_result TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_challenge TO authenticated;
