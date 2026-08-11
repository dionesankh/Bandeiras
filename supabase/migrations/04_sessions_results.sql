-- 4. Sessões Classificatórias e Resultados

-- Tabela de Sessões Ranqueadas (Schema private para proteger nonces)
CREATE TABLE private.ranked_game_sessions (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_nonce_hash TEXT NOT NULL UNIQUE,
    mode TEXT NOT NULL,
    variation TEXT NOT NULL,
    rules_version INTEGER NOT NULL DEFAULT 1,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    status session_status NOT NULL DEFAULT 'created',
    result_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabela Imutável de Resultados (Pública para leitura filtrada)
CREATE TABLE public.game_results (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    event_id TEXT NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ranked_session_id UUID REFERENCES private.ranked_game_sessions(id),
    mode TEXT NOT NULL,
    variation TEXT NOT NULL,
    rules_version INTEGER NOT NULL DEFAULT 1,
    score INTEGER NOT NULL DEFAULT 0,
    correct_answers INTEGER NOT NULL DEFAULT 0,
    wrong_answers INTEGER NOT NULL DEFAULT 0,
    skipped_answers INTEGER NOT NULL DEFAULT 0,
    total_questions INTEGER NOT NULL,
    accuracy NUMERIC(5,2) NOT NULL,
    elapsed_time_ms INTEGER NOT NULL,
    best_streak INTEGER NOT NULL DEFAULT 0,
    hearts_used BOOLEAN NOT NULL DEFAULT FALSE,
    is_ranked BOOLEAN NOT NULL DEFAULT FALSE,
    verification_status verification_status NOT NULL DEFAULT 'unverified',
    client_played_at TIMESTAMPTZ,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT positive_score CHECK (score >= 0),
    CONSTRAINT math_consistency CHECK (correct_answers + wrong_answers + skipped_answers = total_questions),
    CONSTRAINT valid_time CHECK (elapsed_time_ms > 0),
    CONSTRAINT ranked_no_hearts CHECK (is_ranked = FALSE OR hearts_used = FALSE)
);

-- Foreign Key circular protegida
ALTER TABLE private.ranked_game_sessions ADD CONSTRAINT fk_session_result FOREIGN KEY (result_id) REFERENCES public.game_results(id);
