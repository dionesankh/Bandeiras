-- 3. Entitlements e Compras (Schema private)

-- Tabela de Entitlements de Apoiador (Fonte da Verdade)
CREATE TABLE private.supporter_entitlements (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    entitlement_type TEXT NOT NULL DEFAULT 'flag_game_supporter',
    product_id TEXT NOT NULL,
    source entitlement_source NOT NULL DEFAULT 'google_play',
    status supporter_status NOT NULL DEFAULT 'pending',
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    verified_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_user_entitlement UNIQUE (user_id, entitlement_type)
);

-- Tabela Privada de Compras
CREATE TABLE private.purchases (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL DEFAULT 'google_play',
    package_name TEXT NOT NULL,
    product_id TEXT NOT NULL,
    purchase_token TEXT NOT NULL,
    purchase_token_hash TEXT NOT NULL UNIQUE,
    order_id TEXT,
    purchase_state INTEGER,
    acknowledgement_state INTEGER,
    obfuscated_account_id TEXT,
    purchased_at TIMESTAMPTZ NOT NULL,
    last_verified_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    raw_response JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Triggers para updated_at
CREATE TRIGGER update_entitlements_updated_at BEFORE UPDATE ON private.supporter_entitlements FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
CREATE TRIGGER update_purchases_updated_at BEFORE UPDATE ON private.purchases FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
