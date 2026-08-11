-- 23. Prepare backend for direct player challenges
-- Remote state before this migration:
-- - public.challenges exists with a reduced schema.
-- - public.challenge_participants does not exist.
-- - private.challenge_sessions does not exist.
-- - create_challenge exists but is not sufficient for secure 1v1 challenges.
--
-- This migration does not implement UI or JavaScript. It prepares the database
-- contract for Supabase-only Android challenges.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON SCHEMA private FROM anon;
REVOKE ALL ON SCHEMA private FROM authenticated;
REVOKE CREATE ON SCHEMA public FROM anon;
REVOKE CREATE ON SCHEMA public FROM authenticated;

-- Existing remote enum challenge_status_t has at least: open, closed, cancelled.
-- Keep those values for compatibility and derive detailed UI states in RPCs.

ALTER TABLE public.challenges
  ADD COLUMN IF NOT EXISTS config JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS rules_version INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS allow_hearts BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS private.challenge_configs (
    challenge_id UUID PRIMARY KEY REFERENCES public.challenges(id) ON DELETE CASCADE,
    seed TEXT NOT NULL,
    algorithm_version TEXT NOT NULL DEFAULT 'challenge-v1',
    question_codes JSONB NOT NULL DEFAULT '[]'::jsonb,
    question_count INTEGER NOT NULL,
    rules_version INTEGER NOT NULL DEFAULT 1,
    allow_hearts BOOLEAN NOT NULL DEFAULT FALSE,
    scoring JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT challenge_configs_question_codes_array CHECK (jsonb_typeof(question_codes) = 'array'),
    CONSTRAINT challenge_configs_question_count_positive CHECK (question_count > 0)
);

CREATE TABLE IF NOT EXISTS public.challenge_participants (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('creator', 'opponent')),
    status TEXT NOT NULL DEFAULT 'accepted' CHECK (status IN ('accepted', 'playing', 'completed', 'failed')),
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    result_id UUID REFERENCES public.game_results(id),
    event_id TEXT,
    score INTEGER,
    correct_answers INTEGER,
    wrong_answers INTEGER,
    skipped_answers INTEGER,
    total_questions INTEGER,
    accuracy NUMERIC(5,2),
    elapsed_time_ms INTEGER,
    best_streak INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT challenge_participants_unique_user UNIQUE (challenge_id, user_id),
    CONSTRAINT challenge_participants_role_valid CHECK (role IN ('creator', 'opponent')),
    CONSTRAINT challenge_participants_math CHECK (
        total_questions IS NULL
        OR correct_answers IS NULL
        OR wrong_answers IS NULL
        OR skipped_answers IS NULL
        OR correct_answers + wrong_answers + skipped_answers = total_questions
    )
);

ALTER TABLE public.challenge_participants
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'opponent',
  ADD COLUMN IF NOT EXISTS event_id TEXT,
  ADD COLUMN IF NOT EXISTS score INTEGER,
  ADD COLUMN IF NOT EXISTS correct_answers INTEGER,
  ADD COLUMN IF NOT EXISTS wrong_answers INTEGER,
  ADD COLUMN IF NOT EXISTS skipped_answers INTEGER,
  ADD COLUMN IF NOT EXISTS total_questions INTEGER,
  ADD COLUMN IF NOT EXISTS accuracy NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS elapsed_time_ms INTEGER,
  ADD COLUMN IF NOT EXISTS best_streak INTEGER,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE UNIQUE INDEX IF NOT EXISTS challenge_participants_one_opponent
  ON public.challenge_participants (challenge_id)
  WHERE role = 'opponent';

CREATE UNIQUE INDEX IF NOT EXISTS challenge_participants_one_creator
  ON public.challenge_participants (challenge_id)
  WHERE role = 'creator';

CREATE INDEX IF NOT EXISTS idx_challenge_participants_user
  ON public.challenge_participants (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_challenge_participants_challenge
  ON public.challenge_participants (challenge_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_challenge_participants_event
  ON public.challenge_participants (event_id)
  WHERE event_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_challenge_participants_result
  ON public.challenge_participants (result_id)
  WHERE result_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS private.challenge_sessions (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    challenge_id UUID NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    participant_id UUID NOT NULL REFERENCES public.challenge_participants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_nonce_hash TEXT NOT NULL UNIQUE,
    config_snapshot JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'created' CHECK (status IN ('created', 'completed', 'expired', 'cancelled', 'rejected')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    result_id UUID REFERENCES public.game_results(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_challenge_sessions_nonce
  ON private.challenge_sessions (session_nonce_hash);

CREATE INDEX IF NOT EXISTS idx_challenge_sessions_participant
  ON private.challenge_sessions (participant_id, status);

CREATE UNIQUE INDEX IF NOT EXISTS idx_challenge_sessions_one_created_per_participant
  ON private.challenge_sessions (participant_id)
  WHERE status = 'created';

CREATE UNIQUE INDEX IF NOT EXISTS idx_challenges_code_unique
  ON public.challenges (code);

CREATE INDEX IF NOT EXISTS idx_challenges_creator_created
  ON public.challenges (creator_id, created_at DESC);

ALTER TABLE public.challenges
  DROP CONSTRAINT IF EXISTS challenges_idempotency_key_key;

CREATE UNIQUE INDEX IF NOT EXISTS idx_challenges_creator_idempotency
  ON public.challenges (creator_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_challenges_status_expires
  ON public.challenges (status, expires_at);

-- Remove unsafe direct table access. All challenge writes must go through RPCs.
REVOKE ALL ON public.challenges FROM PUBLIC;
REVOKE ALL ON public.challenges FROM anon;
REVOKE ALL ON public.challenges FROM authenticated;
REVOKE ALL ON public.challenge_participants FROM PUBLIC;
REVOKE ALL ON public.challenge_participants FROM anon;
REVOKE ALL ON public.challenge_participants FROM authenticated;
REVOKE ALL ON private.challenge_configs FROM PUBLIC;
REVOKE ALL ON private.challenge_configs FROM anon;
REVOKE ALL ON private.challenge_configs FROM authenticated;
REVOKE ALL ON private.challenge_sessions FROM PUBLIC;
REVOKE ALL ON private.challenge_sessions FROM anon;
REVOKE ALL ON private.challenge_sessions FROM authenticated;
REVOKE ALL ON public.game_results FROM PUBLIC;
REVOKE ALL ON public.game_results FROM anon;
REVOKE ALL ON public.game_results FROM authenticated;

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.challenge_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.challenge_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_results ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Desafios abertos visiveis" ON public.challenges;
DROP POLICY IF EXISTS "Desafios abertos visíveis" ON public.challenges;
DROP POLICY IF EXISTS "Dono gerencia seus desafios" ON public.challenges;
DROP POLICY IF EXISTS "Ver meus dados no desafio" ON public.challenge_participants;
DROP POLICY IF EXISTS "challenge_participants_select_own" ON public.challenge_participants;
DROP POLICY IF EXISTS "challenge_sessions_select_own" ON private.challenge_sessions;

CREATE POLICY "challenge_participants_select_own"
ON public.challenge_participants
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "challenge_sessions_select_own"
ON private.challenge_sessions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.normalize_challenge_code(p_code TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
    v_clean TEXT;
BEGIN
    v_clean := regexp_replace(upper(trim(COALESCE(p_code, ''))), '[^A-Z0-9]', '', 'g');

    IF left(v_clean, 2) = 'FG' THEN
        v_clean := substring(v_clean from 3);
    END IF;

    IF v_clean !~ '^[A-Z2-9]{8}$' THEN
        RETURN NULL;
    END IF;

    RETURN 'FG-' || v_clean;
END;
$$;

CREATE OR REPLACE FUNCTION private.generate_challenge_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = private, public
AS $$
DECLARE
    v_alphabet CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    v_bytes BYTEA;
    v_body TEXT;
    v_code TEXT;
    v_attempt INTEGER;
    i INTEGER;
BEGIN
    FOR v_attempt IN 1..20 LOOP
        v_body := '';
        v_bytes := extensions.gen_random_bytes(8);

        FOR i IN 0..7 LOOP
            v_body := v_body || substr(v_alphabet, (get_byte(v_bytes, i) % length(v_alphabet)) + 1, 1);
        END LOOP;

        v_code := 'FG-' || v_body;

        IF NOT EXISTS (SELECT 1 FROM public.challenges WHERE code = v_code) THEN
            RETURN v_code;
        END IF;
    END LOOP;

    RAISE EXCEPTION 'Could not generate unique challenge code';
END;
$$;

CREATE OR REPLACE FUNCTION private.challenge_question_count(p_mode TEXT, p_variation TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
SET search_path = private
AS $$
BEGIN
    IF p_mode = 'world' AND p_variation IN ('10', '20', '50', '195') THEN
        RETURN p_variation::INTEGER;
    END IF;

    IF p_mode = 'continent' THEN
        IF p_variation = 'south-america' THEN RETURN 12; END IF;
        IF p_variation = 'north-america' THEN RETURN 23; END IF;
        IF p_variation = 'europe' THEN RETURN 44; END IF;
        IF p_variation = 'africa' THEN RETURN 54; END IF;
        IF p_variation = 'asia' THEN RETURN 48; END IF;
        IF p_variation = 'oceania' THEN RETURN 14; END IF;
    END IF;

    RAISE EXCEPTION 'Invalid challenge variation';
END;
$$;

INSERT INTO private.challenge_configs (
    challenge_id,
    seed,
    algorithm_version,
    question_codes,
    question_count,
    rules_version,
    allow_hearts,
    scoring
)
SELECT
    c.id,
    COALESCE(NULLIF(c.config->>'seed', ''), encode(extensions.gen_random_bytes(16), 'hex')),
    COALESCE(NULLIF(c.config->>'algorithm_version', ''), 'challenge-v1'),
    CASE
        WHEN jsonb_typeof(c.config->'question_codes') = 'array' THEN c.config->'question_codes'
        ELSE '[]'::jsonb
    END,
    private.challenge_question_count(c.mode, c.variation),
    c.rules_version,
    c.allow_hearts,
    COALESCE(
        c.config->'scoring',
        jsonb_build_object(
            'score', 'correct_answers',
            'tie_breakers', jsonb_build_array(
                'score_desc',
                'correct_answers_desc',
                'elapsed_time_ms_asc',
                'best_streak_desc'
            )
        )
    )
FROM public.challenges c
ON CONFLICT (challenge_id) DO NOTHING;

UPDATE public.challenges
SET config = (config - 'seed' - 'scoring' - 'question_codes' - 'algorithm_version')
WHERE config ? 'seed'
   OR config ? 'scoring'
   OR config ? 'question_codes'
   OR config ? 'algorithm_version';

UPDATE private.challenge_configs cc
SET question_count = private.challenge_question_count(c.mode, c.variation)
FROM public.challenges c
WHERE cc.challenge_id = c.id
  AND cc.question_count IS NULL;

ALTER TABLE private.challenge_configs
  ALTER COLUMN question_count SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'challenge_configs_question_count_positive'
          AND conrelid = 'private.challenge_configs'::regclass
    ) THEN
        ALTER TABLE private.challenge_configs
          ADD CONSTRAINT challenge_configs_question_count_positive CHECK (question_count > 0);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION private.challenge_public_status(p_challenge_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = private, public
AS $$
DECLARE
    v_challenge RECORD;
    v_creator_done BOOLEAN;
    v_opponent_exists BOOLEAN;
    v_opponent_done BOOLEAN;
BEGIN
    SELECT * INTO v_challenge
    FROM public.challenges
    WHERE id = p_challenge_id;

    IF NOT FOUND THEN
        RETURN 'unavailable';
    END IF;

    IF v_challenge.status = 'cancelled' THEN
        RETURN 'cancelled';
    END IF;

    IF v_challenge.expires_at <= NOW() AND v_challenge.status <> 'closed' THEN
        RETURN 'expired';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.challenge_participants
        WHERE challenge_id = p_challenge_id
          AND role = 'creator'
          AND status = 'completed'
    ) INTO v_creator_done;

    SELECT EXISTS (
        SELECT 1 FROM public.challenge_participants
        WHERE challenge_id = p_challenge_id
          AND role = 'opponent'
    ) INTO v_opponent_exists;

    SELECT EXISTS (
        SELECT 1 FROM public.challenge_participants
        WHERE challenge_id = p_challenge_id
          AND role = 'opponent'
          AND status = 'completed'
    ) INTO v_opponent_done;

    IF v_creator_done AND v_opponent_done THEN
        RETURN 'completed';
    END IF;

    IF v_creator_done AND NOT v_opponent_exists THEN
        RETURN 'awaiting_opponent';
    END IF;

    IF v_opponent_exists THEN
        RETURN 'accepted';
    END IF;

    RETURN 'created';
END;
$$;

CREATE OR REPLACE FUNCTION private.challenge_winner_payload(p_challenge_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = private, public
AS $$
DECLARE
    v_completed_count INTEGER;
    v_top RECORD;
    v_second RECORD;
BEGIN
    SELECT count(*) INTO v_completed_count
    FROM public.challenge_participants
    WHERE challenge_id = p_challenge_id
      AND status = 'completed';

    IF v_completed_count < 2 THEN
        RETURN jsonb_build_object('status', 'pending');
    END IF;

    SELECT * INTO v_top
    FROM public.challenge_participants
    WHERE challenge_id = p_challenge_id
      AND status = 'completed'
    ORDER BY
      score DESC NULLS LAST,
      correct_answers DESC NULLS LAST,
      elapsed_time_ms ASC NULLS LAST,
      best_streak DESC NULLS LAST
    LIMIT 1;

    SELECT * INTO v_second
    FROM public.challenge_participants
    WHERE challenge_id = p_challenge_id
      AND status = 'completed'
      AND id <> v_top.id
    ORDER BY
      score DESC NULLS LAST,
      correct_answers DESC NULLS LAST,
      elapsed_time_ms ASC NULLS LAST,
      best_streak DESC NULLS LAST
    LIMIT 1;

    IF v_top.score = v_second.score
       AND v_top.correct_answers = v_second.correct_answers
       AND v_top.elapsed_time_ms = v_second.elapsed_time_ms
       AND v_top.best_streak = v_second.best_streak THEN
        RETURN jsonb_build_object('status', 'tie');
    END IF;

    RETURN jsonb_build_object(
        'status', 'winner',
        'winner_participant_id', v_top.id,
        'winner_role', v_top.role
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_daily_challenge_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_supporter BOOLEAN;
    v_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_is_supporter := COALESCE(public.check_is_supporter(v_user_id), FALSE);

    SELECT count(*) INTO v_count
    FROM public.challenges
    WHERE creator_id = v_user_id
      AND (created_at AT TIME ZONE 'UTC')::DATE = (NOW() AT TIME ZONE 'UTC')::DATE;

    RETURN jsonb_build_object(
        'is_supporter', v_is_supporter,
        'used_today', v_count,
        'limit', CASE WHEN v_is_supporter THEN -1 ELSE 2 END,
        'remaining', CASE WHEN v_is_supporter THEN -1 ELSE GREATEST(2 - v_count, 0) END
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_challenge(
    p_mode TEXT,
    p_variation TEXT,
    p_idemp_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_supporter BOOLEAN;
    v_daily_count INTEGER;
    v_code TEXT;
    v_challenge_id UUID;
    v_idemp_key TEXT;
    v_question_count INTEGER;
    v_seed TEXT;
    v_public_config JSONB;
    v_scoring JSONB;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '7 days';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_idemp_key := trim(COALESCE(p_idemp_key, ''));

    IF length(v_idemp_key) < 8 OR length(v_idemp_key) > 128 THEN
        RAISE EXCEPTION 'Invalid idempotency key';
    END IF;

    IF p_mode NOT IN ('world', 'continent') THEN
        RAISE EXCEPTION 'Invalid challenge mode';
    END IF;

    IF p_mode = 'world' AND p_variation NOT IN ('10', '20', '50', '195') THEN
        RAISE EXCEPTION 'Invalid world variation';
    END IF;

    IF p_mode = 'continent' AND p_variation NOT IN (
        'south-america',
        'north-america',
        'europe',
        'africa',
        'asia',
        'oceania'
    ) THEN
        RAISE EXCEPTION 'Invalid continent variation';
    END IF;

    SELECT id, code, expires_at
    INTO v_challenge_id, v_code, v_expires_at
    FROM public.challenges
    WHERE creator_id = v_user_id
      AND idempotency_key = v_idemp_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'challenge_id', v_challenge_id,
            'code', v_code,
            'expires_at', v_expires_at,
            'restored', TRUE
        );
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::TEXT));

    SELECT id, code, expires_at
    INTO v_challenge_id, v_code, v_expires_at
    FROM public.challenges
    WHERE creator_id = v_user_id
      AND idempotency_key = v_idemp_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'challenge_id', v_challenge_id,
            'code', v_code,
            'expires_at', v_expires_at,
            'restored', TRUE
        );
    END IF;

    v_is_supporter := COALESCE(public.check_is_supporter(v_user_id), FALSE);

    IF NOT v_is_supporter THEN
        SELECT count(*) INTO v_daily_count
        FROM public.challenges
        WHERE creator_id = v_user_id
          AND (created_at AT TIME ZONE 'UTC')::DATE = (NOW() AT TIME ZONE 'UTC')::DATE;

        IF v_daily_count >= 2 THEN
            RAISE EXCEPTION 'Daily limit reached';
        END IF;
    END IF;

    v_question_count := private.challenge_question_count(p_mode, p_variation);
    v_seed := encode(extensions.gen_random_bytes(16), 'hex');
    v_code := private.generate_challenge_code();

    v_scoring := jsonb_build_object(
        'score', 'correct_answers',
        'tie_breakers', jsonb_build_array(
            'score_desc',
            'correct_answers_desc',
            'elapsed_time_ms_asc',
            'best_streak_desc'
        )
    );

    v_public_config := jsonb_build_object(
        'mode', p_mode,
        'variation', p_variation,
        'question_count', v_question_count,
        'rules_version', 1,
        'allow_hearts', FALSE
    );

    INSERT INTO public.challenges (
        creator_id,
        code,
        mode,
        variation,
        idempotency_key,
        config,
        rules_version,
        allow_hearts,
        status,
        expires_at
    )
    VALUES (
        v_user_id,
        v_code,
        p_mode,
        p_variation,
        v_idemp_key,
        v_public_config,
        1,
        FALSE,
        'open',
        v_expires_at
    )
    ON CONFLICT (creator_id, idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING
    RETURNING id, code, expires_at INTO v_challenge_id, v_code, v_expires_at;

    IF v_challenge_id IS NULL THEN
        SELECT id, code, expires_at
        INTO v_challenge_id, v_code, v_expires_at
        FROM public.challenges
        WHERE creator_id = v_user_id
          AND idempotency_key = v_idemp_key;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'challenge_id', v_challenge_id,
                'code', v_code,
                'expires_at', v_expires_at,
                'restored', TRUE
            );
        END IF;

        RAISE EXCEPTION 'Could not create challenge';
    END IF;

    INSERT INTO private.challenge_configs (
        challenge_id,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        rules_version,
        allow_hearts,
        scoring
    )
    VALUES (
        v_challenge_id,
        v_seed,
        'challenge-v1',
        '[]'::jsonb,
        v_question_count,
        1,
        FALSE,
        v_scoring
    )
    ON CONFLICT (challenge_id) DO NOTHING;

    INSERT INTO public.challenge_participants (
        challenge_id,
        user_id,
        role,
        status
    )
    VALUES (
        v_challenge_id,
        v_user_id,
        'creator',
        'accepted'
    )
    ON CONFLICT (challenge_id, user_id) DO NOTHING;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge_id,
        'code', v_code,
        'expires_at', v_expires_at,
        'remaining_daily', CASE
            WHEN v_is_supporter THEN -1
            ELSE GREATEST(2 - (COALESCE(v_daily_count, 0) + 1), 0)
        END,
        'is_supporter', v_is_supporter,
        'question_count', v_question_count,
        'rules_version', 1,
        'allow_hearts', FALSE
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_challenge_preview(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_code TEXT;
    v_challenge RECORD;
    v_creator RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_code := public.normalize_challenge_code(p_code);

    IF v_code IS NULL THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT
        c.id,
        c.creator_id,
        c.code,
        c.mode,
        c.variation,
        c.rules_version,
        c.allow_hearts,
        c.expires_at,
        COALESCE(cc.question_count, private.challenge_question_count(c.mode, c.variation)) AS question_count
    INTO v_challenge
    FROM public.challenges c
    LEFT JOIN private.challenge_configs cc ON cc.challenge_id = c.id
    WHERE c.code = v_code
      AND c.status = 'open'
      AND c.expires_at > NOW();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT id, nickname, country_code, avatar_key
    INTO v_creator
    FROM public.profiles
    WHERE id = v_challenge.creator_id;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge.id,
        'code', v_challenge.code,
        'creator', jsonb_build_object(
            'nickname', v_creator.nickname,
            'country_code', v_creator.country_code,
            'avatar_key', v_creator.avatar_key
        ),
        'mode', v_challenge.mode,
        'variation', v_challenge.variation,
        'question_count', v_challenge.question_count,
        'rules_version', v_challenge.rules_version,
        'allow_hearts', v_challenge.allow_hearts,
        'expires_at', v_challenge.expires_at,
        'status', private.challenge_public_status(v_challenge.id),
        'already_participant', EXISTS (
            SELECT 1 FROM public.challenge_participants
            WHERE challenge_id = v_challenge.id
              AND user_id = v_user_id
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_challenge(p_challenge_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_code TEXT;
    v_challenge RECORD;
    v_participant_id UUID;
    v_existing_opponent UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_code := public.normalize_challenge_code(p_challenge_code);

    IF v_code IS NULL THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT *
    INTO v_challenge
    FROM public.challenges
    WHERE code = v_code
      AND status = 'open'
      AND expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    IF v_challenge.creator_id = v_user_id THEN
        RAISE EXCEPTION 'Creator cannot accept own challenge as opponent';
    END IF;

    SELECT user_id INTO v_existing_opponent
    FROM public.challenge_participants
    WHERE challenge_id = v_challenge.id
      AND role = 'opponent'
    LIMIT 1;

    IF v_existing_opponent IS NOT NULL AND v_existing_opponent <> v_user_id THEN
        RAISE EXCEPTION 'Challenge already has an opponent';
    END IF;

    INSERT INTO public.challenge_participants (
        challenge_id,
        user_id,
        role,
        status
    )
    VALUES (
        v_challenge.id,
        v_user_id,
        'opponent',
        'accepted'
    )
    ON CONFLICT (challenge_id, user_id) DO UPDATE
    SET updated_at = NOW()
    RETURNING id INTO v_participant_id;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge.id,
        'participant_id', v_participant_id,
        'status', 'accepted'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.start_challenge_session(p_challenge_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_code TEXT;
    v_challenge RECORD;
    v_participant RECORD;
    v_config_snapshot JSONB;
    v_client_config JSONB;
    v_nonce TEXT;
    v_nonce_hash TEXT;
    v_session_id UUID;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '30 minutes';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_code := public.normalize_challenge_code(p_challenge_code);

    IF v_code IS NULL THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT *
    INTO v_challenge
    FROM public.challenges
    WHERE code = v_code
      AND status = 'open'
      AND expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT *
    INTO v_participant
    FROM public.challenge_participants
    WHERE challenge_id = v_challenge.id
      AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge must be accepted before starting';
    END IF;

    IF v_participant.status = 'completed' THEN
        RAISE EXCEPTION 'Challenge participation already completed';
    END IF;

    INSERT INTO private.challenge_configs (
        challenge_id,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        rules_version,
        allow_hearts,
        scoring
    )
    VALUES (
        v_challenge.id,
        encode(extensions.gen_random_bytes(16), 'hex'),
        'challenge-v1',
        '[]'::jsonb,
        private.challenge_question_count(v_challenge.mode, v_challenge.variation),
        v_challenge.rules_version,
        v_challenge.allow_hearts,
        jsonb_build_object(
            'score', 'correct_answers',
            'tie_breakers', jsonb_build_array(
                'score_desc',
                'correct_answers_desc',
                'elapsed_time_ms_asc',
                'best_streak_desc'
            )
        )
    )
    ON CONFLICT (challenge_id) DO NOTHING;

    SELECT jsonb_build_object(
        'mode', v_challenge.mode,
        'variation', v_challenge.variation,
        'seed', cc.seed,
        'algorithm_version', cc.algorithm_version,
        'question_codes', cc.question_codes,
        'question_count', cc.question_count,
        'rules_version', cc.rules_version,
        'allow_hearts', cc.allow_hearts,
        'scoring', cc.scoring
    )
    INTO v_config_snapshot
    FROM private.challenge_configs cc
    WHERE cc.challenge_id = v_challenge.id;

    v_client_config := v_config_snapshot - 'question_codes' - 'scoring';

    UPDATE private.challenge_sessions
    SET status = 'cancelled'
    WHERE participant_id = v_participant.id
      AND status = 'created';

    v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
    v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');

    INSERT INTO private.challenge_sessions (
        challenge_id,
        participant_id,
        user_id,
        session_nonce_hash,
        config_snapshot,
        status,
        expires_at
    )
    VALUES (
        v_challenge.id,
        v_participant.id,
        v_user_id,
        v_nonce_hash,
        v_config_snapshot,
        'created',
        v_expires_at
    )
    RETURNING id INTO v_session_id;

    UPDATE public.challenge_participants
    SET status = 'playing',
        started_at = COALESCE(started_at, NOW()),
        updated_at = NOW()
    WHERE id = v_participant.id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'challenge_id', v_challenge.id,
        'participant_id', v_participant.id,
        'nonce', v_nonce,
        'expires_at', v_expires_at,
        'config', v_client_config
    );
END;
$$;

DROP FUNCTION IF EXISTS public.submit_challenge_result(
    UUID,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER
);

CREATE OR REPLACE FUNCTION public.submit_challenge_result(
    p_nonce TEXT,
    p_event_id TEXT,
    p_correct INTEGER,
    p_wrong INTEGER,
    p_skipped INTEGER,
    p_total INTEGER,
    p_time_ms INTEGER,
    p_streak INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce_hash TEXT;
    v_session RECORD;
    v_participant RECORD;
    v_challenge RECORD;
    v_question_count INTEGER;
    v_accuracy NUMERIC(5,2);
    v_result_id UUID;
    v_score INTEGER;
    v_outcome JSONB;
    v_event_id TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_nonce IS NULL OR length(trim(p_nonce)) < 32 OR length(trim(p_nonce)) > 128 THEN
        RAISE EXCEPTION 'Invalid challenge session';
    END IF;

    v_event_id := trim(COALESCE(p_event_id, ''));

    IF length(v_event_id) < 8 OR length(v_event_id) > 128 THEN
        RAISE EXCEPTION 'Invalid event id';
    END IF;

    IF p_correct IS NULL
       OR p_wrong IS NULL
       OR p_skipped IS NULL
       OR p_total IS NULL
       OR p_time_ms IS NULL
       OR p_streak IS NULL THEN
        RAISE EXCEPTION 'Invalid result numbers';
    END IF;

    IF p_correct < 0
       OR p_wrong < 0
       OR p_skipped < 0
       OR p_total <= 0
       OR p_time_ms <= 0
       OR p_streak < 0 THEN
        RAISE EXCEPTION 'Invalid result numbers';
    END IF;

    IF p_time_ms > 1800000 THEN
        RAISE EXCEPTION 'Invalid elapsed time';
    END IF;

    IF p_correct > p_total
       OR p_wrong > p_total
       OR p_skipped > p_total
       OR p_streak > p_correct THEN
        RAISE EXCEPTION 'Invalid result numbers';
    END IF;

    v_nonce_hash := encode(extensions.digest(p_nonce, 'sha256'), 'hex');

    SELECT
        id,
        challenge_id,
        participant_id
    INTO v_session
    FROM private.challenge_sessions
    WHERE session_nonce_hash = v_nonce_hash
      AND user_id = v_user_id
      AND status = 'created';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid challenge session or already used';
    END IF;

    SELECT *
    INTO v_challenge
    FROM public.challenges
    WHERE id = v_session.challenge_id
      AND status = 'open'
      AND expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT *
    INTO v_participant
    FROM public.challenge_participants
    WHERE id = v_session.participant_id
      AND challenge_id = v_challenge.id
      AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge participant not found';
    END IF;

    SELECT *
    INTO v_session
    FROM private.challenge_sessions
    WHERE id = v_session.id
      AND user_id = v_user_id
      AND participant_id = v_participant.id
      AND challenge_id = v_challenge.id
      AND session_nonce_hash = v_nonce_hash
      AND status = 'created'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid challenge session or already used';
    END IF;

    IF v_session.expires_at < NOW() THEN
        RAISE EXCEPTION 'Challenge session expired';
    END IF;

    IF v_participant.status = 'completed' THEN
        RAISE EXCEPTION 'Challenge result already submitted';
    END IF;

    IF (p_correct + p_wrong + p_skipped) != p_total THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    v_question_count := NULLIF(v_session.config_snapshot->>'question_count', '')::INTEGER;

    IF v_question_count IS NOT NULL AND p_total <> v_question_count THEN
        RAISE EXCEPTION 'Challenge question count mismatch';
    END IF;

    v_score := p_correct;
    v_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    IF v_accuracy < 0 OR v_accuracy > 100 THEN
        RAISE EXCEPTION 'Invalid accuracy';
    END IF;

    INSERT INTO public.game_results (
        event_id,
        user_id,
        score,
        correct_answers,
        total_questions,
        accuracy,
        elapsed_time_ms,
        hearts_used,
        is_ranked,
        verification_status,
        received_at
    )
    VALUES (
        v_event_id,
        v_user_id,
        v_score,
        p_correct,
        p_total,
        v_accuracy,
        p_time_ms,
        FALSE,
        FALSE,
        'pending',
        NOW()
    )
    RETURNING id INTO v_result_id;

    UPDATE public.challenge_participants
    SET status = 'completed',
        completed_at = NOW(),
        result_id = v_result_id,
        event_id = v_event_id,
        score = v_score,
        correct_answers = p_correct,
        wrong_answers = p_wrong,
        skipped_answers = p_skipped,
        total_questions = p_total,
        accuracy = v_accuracy,
        elapsed_time_ms = p_time_ms,
        best_streak = p_streak,
        updated_at = NOW()
    WHERE id = v_participant.id;

    UPDATE private.challenge_sessions
    SET status = 'completed',
        completed_at = NOW(),
        result_id = v_result_id
    WHERE id = v_session.id;

    IF (
        SELECT count(*)
        FROM public.challenge_participants
        WHERE challenge_id = v_challenge.id
          AND status = 'completed'
    ) >= 2 THEN
        UPDATE public.challenges
        SET status = 'closed'
        WHERE id = v_challenge.id;
    END IF;

    v_outcome := private.challenge_winner_payload(v_challenge.id);

    RETURN jsonb_build_object(
        'result_id', v_result_id,
        'status', 'completed',
        'challenge_status', private.challenge_public_status(v_challenge.id),
        'outcome', v_outcome
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_challenge(p_challenge_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_code TEXT;
    v_challenge RECORD;
    v_has_opponent BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_code := public.normalize_challenge_code(p_challenge_code);

    IF v_code IS NULL THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT *
    INTO v_challenge
    FROM public.challenges
    WHERE code = v_code
      AND status = 'open'
      AND expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    IF v_challenge.creator_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the creator can cancel this challenge';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.challenge_participants
        WHERE challenge_id = v_challenge.id
          AND role = 'opponent'
    ) INTO v_has_opponent;

    IF v_has_opponent THEN
        RAISE EXCEPTION 'Challenge already accepted';
    END IF;

    UPDATE public.challenges
    SET status = 'cancelled',
        cancelled_at = NOW()
    WHERE id = v_challenge.id;

    UPDATE private.challenge_sessions
    SET status = 'cancelled'
    WHERE challenge_id = v_challenge.id
      AND status = 'created';

    RETURN jsonb_build_object(
        'challenge_id', v_challenge.id,
        'code', v_challenge.code,
        'status', 'cancelled'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_challenge_result(p_challenge_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_challenge RECORD;
    v_allowed BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT *
    INTO v_challenge
    FROM public.challenges
    WHERE id = p_challenge_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.challenge_participants
        WHERE challenge_id = p_challenge_id
          AND user_id = v_user_id
    ) INTO v_allowed;

    IF NOT v_allowed THEN
        RAISE EXCEPTION 'Challenge not found or unavailable';
    END IF;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge.id,
        'code', v_challenge.code,
        'mode', v_challenge.mode,
        'variation', v_challenge.variation,
        'expires_at', v_challenge.expires_at,
        'status', private.challenge_public_status(v_challenge.id),
        'outcome', private.challenge_winner_payload(v_challenge.id),
        'participants', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'participant_id', cp.id,
                    'role', cp.role,
                    'status', cp.status,
                    'nickname', p.nickname,
                    'country_code', p.country_code,
                    'avatar_key', p.avatar_key,
                    'score', cp.score,
                    'correct_answers', cp.correct_answers,
                    'total_questions', cp.total_questions,
                    'accuracy', cp.accuracy,
                    'elapsed_time_ms', cp.elapsed_time_ms,
                    'best_streak', cp.best_streak,
                    'completed_at', cp.completed_at
                )
                ORDER BY cp.role
            )
            FROM public.challenge_participants cp
            JOIN public.profiles p ON p.id = cp.user_id
            WHERE cp.challenge_id = v_challenge.id
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_my_challenges(
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    RETURN jsonb_build_object(
        'items', COALESCE((
            SELECT jsonb_agg(item ORDER BY item_created_at DESC)
            FROM (
                SELECT
                    jsonb_build_object(
                        'challenge_id', c.id,
                        'code', c.code,
                        'mode', c.mode,
                        'variation', c.variation,
                        'status', private.challenge_public_status(c.id),
                        'role', cp.role,
                        'expires_at', c.expires_at,
                        'created_at', c.created_at,
                        'outcome', private.challenge_winner_payload(c.id)
                    ) AS item,
                    c.created_at AS item_created_at
                FROM public.challenge_participants cp
                JOIN public.challenges c ON c.id = cp.challenge_id
                WHERE cp.user_id = v_user_id
                  AND (
                    p_status IS NULL
                    OR private.challenge_public_status(c.id) = p_status
                  )
                ORDER BY c.created_at DESC
                LIMIT v_limit OFFSET v_offset
            ) q
        ), '[]'::jsonb),
        'limit', v_limit,
        'offset', v_offset
    );
END;
$$;

REVOKE ALL ON FUNCTION public.normalize_challenge_code(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.normalize_challenge_code(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.normalize_challenge_code(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION private.generate_challenge_code() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.generate_challenge_code() FROM anon;
REVOKE ALL ON FUNCTION private.generate_challenge_code() FROM authenticated;
REVOKE ALL ON FUNCTION private.challenge_question_count(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.challenge_question_count(TEXT, TEXT) FROM anon;
REVOKE ALL ON FUNCTION private.challenge_question_count(TEXT, TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION private.challenge_public_status(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.challenge_public_status(UUID) FROM anon;
REVOKE ALL ON FUNCTION private.challenge_public_status(UUID) FROM authenticated;
REVOKE ALL ON FUNCTION private.challenge_winner_payload(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.challenge_winner_payload(UUID) FROM anon;
REVOKE ALL ON FUNCTION private.challenge_winner_payload(UUID) FROM authenticated;

REVOKE ALL ON FUNCTION public.create_challenge(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_challenge(TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_challenge(TEXT, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.get_daily_challenge_quota() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_daily_challenge_quota() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_daily_challenge_quota() TO authenticated;

REVOKE ALL ON FUNCTION public.get_challenge_preview(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_challenge_preview(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_challenge_preview(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.accept_challenge(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.accept_challenge(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.accept_challenge(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.start_challenge_session(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.start_challenge_session(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.start_challenge_session(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_challenge_result(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_challenge_result(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER
) FROM anon;
GRANT EXECUTE ON FUNCTION public.submit_challenge_result(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER
) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_challenge(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancel_challenge(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.cancel_challenge(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.get_challenge_result(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_challenge_result(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_challenge_result(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.list_my_challenges(TEXT, INTEGER, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_my_challenges(TEXT, INTEGER, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION public.list_my_challenges(TEXT, INTEGER, INTEGER) TO authenticated;

NOTIFY pgrst, 'reload schema';
