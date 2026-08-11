-- 5. Desafios e Participantes

CREATE TABLE public.challenges (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,
    mode TEXT NOT NULL,
    variation TEXT NOT NULL,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    rules_version INTEGER NOT NULL DEFAULT 1,
    allow_hearts BOOLEAN DEFAULT TRUE,
    status challenge_status DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    idempotency_key TEXT UNIQUE
);

CREATE TABLE public.challenge_participants (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status challenge_participant_status DEFAULT 'accepted',
    accepted_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    result_id UUID REFERENCES public.game_results(id),

    final_score INTEGER,
    final_accuracy NUMERIC(5,2),

    CONSTRAINT unique_challenge_participant UNIQUE (challenge_id, user_id)
);
