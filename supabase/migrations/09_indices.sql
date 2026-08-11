-- 9. Índices de Performance

-- Busca por apelido (trgm para busca parcial)
CREATE INDEX idx_profiles_nickname ON public.profiles USING GIN (nickname gin_trgm_ops);

-- Performance do Ranking (O índice cobre as cláusulas ORDER BY da View)
CREATE INDEX idx_game_results_ranking ON public.game_results (mode, variation, score DESC, correct_answers DESC, elapsed_time_ms ASC)
WHERE is_ranked = TRUE AND verification_status = 'verified' AND hearts_used = FALSE;

-- Filtros de busca rápida
CREATE INDEX idx_ranked_sessions_hash ON private.ranked_game_sessions (session_nonce_hash);
CREATE INDEX idx_challenges_code ON public.challenges (code);

-- Chaves Estrangeiras Frequentes
CREATE INDEX idx_game_results_user ON public.game_results (user_id);
CREATE INDEX idx_challenges_creator ON public.challenges (creator_id);
CREATE INDEX idx_entitlements_user ON private.supporter_entitlements (user_id);
