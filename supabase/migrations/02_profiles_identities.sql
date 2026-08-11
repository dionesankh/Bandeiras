-- 2. Perfis e Identidades

-- Tabela de Perfis Públicos
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nickname TEXT NOT NULL,
    country_code CHAR(2) DEFAULT 'BR',
    avatar_key TEXT,
    privacy_settings JSONB DEFAULT '{
        "show_detailed_stats": false,
        "show_recent_activity": true,
        "show_wrong_flags": false,
        "show_challenge_history": true
    }'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT nickname_length CHECK (char_length(nickname) >= 3 AND char_length(nickname) <= 24),
    CONSTRAINT nickname_chars CHECK (nickname ~ '^[a-zA-Z0-9 _-]+$')
);

-- Tabela Privada de Identidades de Jogador (Schema private)
CREATE TABLE private.player_identities (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL, -- 'google_play', 'legacy'
    provider_player_id TEXT,
    legacy_player_id TEXT,
    linked_at TIMESTAMPTZ DEFAULT NOW(),
    verified_at TIMESTAMPTZ,
    status TEXT DEFAULT 'active',
    metadata JSONB DEFAULT '{}'::jsonb,

    CONSTRAINT unique_provider_player UNIQUE (provider, provider_player_id),
    CONSTRAINT unique_user_provider UNIQUE (user_id, provider)
);

-- Função e Trigger para updated_at (Usada por múltiplos schemas)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
