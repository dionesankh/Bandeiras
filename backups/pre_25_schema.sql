


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "private";


ALTER SCHEMA "private" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."challenge_participant_status_t" AS ENUM (
    'invited',
    'accepted',
    'completed',
    'failed'
);


ALTER TYPE "public"."challenge_participant_status_t" OWNER TO "postgres";


CREATE TYPE "public"."challenge_status_t" AS ENUM (
    'open',
    'closed',
    'cancelled'
);


ALTER TYPE "public"."challenge_status_t" OWNER TO "postgres";


CREATE TYPE "public"."entitlement_source_t" AS ENUM (
    'google_play',
    'manual',
    'promo'
);


ALTER TYPE "public"."entitlement_source_t" OWNER TO "postgres";


CREATE TYPE "public"."session_status_t" AS ENUM (
    'created',
    'completed',
    'expired',
    'cancelled',
    'rejected'
);


ALTER TYPE "public"."session_status_t" OWNER TO "postgres";


CREATE TYPE "public"."supporter_status_t" AS ENUM (
    'active',
    'pending',
    'revoked',
    'refunded',
    'invalid'
);


ALTER TYPE "public"."supporter_status_t" OWNER TO "postgres";


CREATE TYPE "public"."verification_status_t" AS ENUM (
    'unverified',
    'pending',
    'verified',
    'rejected'
);


ALTER TYPE "public"."verification_status_t" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."challenge_build_question_codes"("p_mode" "text", "p_variation" "text", "p_seed" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'private', 'public'
    AS $$
DECLARE
    v_question_count INTEGER;
    v_codes JSONB;
    v_actual_count INTEGER;
BEGIN
    v_question_count := private.challenge_question_count(p_mode, p_variation);

    WITH source AS (
        SELECT code
        FROM private.challenge_country_catalog()
        WHERE p_mode = 'world'
           OR continent = p_variation
    ),
    ordered AS (
        SELECT
            code,
            row_number() OVER (
                ORDER BY encode(extensions.digest(p_seed || ':' || code || ':flags', 'sha256'), 'hex'), code
            ) AS rn
        FROM source
    ),
    selected AS (
        SELECT code, rn
        FROM ordered
        ORDER BY rn
        LIMIT v_question_count
    )
    SELECT jsonb_agg(code ORDER BY rn), count(*)
    INTO v_codes, v_actual_count
    FROM selected;

    IF COALESCE(v_actual_count, 0) <> v_question_count THEN
        RAISE EXCEPTION 'Invalid challenge catalog for mode and variation';
    END IF;

    RETURN v_codes;
END;
$$;


ALTER FUNCTION "private"."challenge_build_question_codes"("p_mode" "text", "p_variation" "text", "p_seed" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."challenge_country_catalog"() RETURNS TABLE("code" "text", "continent" "text")
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO 'private'
    AS $$
  VALUES
    ('AR','south-america'), ('BO','south-america'), ('BR','south-america'), ('CL','south-america'),
    ('CO','south-america'), ('EC','south-america'), ('GY','south-america'), ('PY','south-america'),
    ('PE','south-america'), ('SR','south-america'), ('UY','south-america'), ('VE','south-america'),
    ('AG','north-america'), ('BS','north-america'), ('BB','north-america'), ('BZ','north-america'),
    ('CA','north-america'), ('CR','north-america'), ('CU','north-america'), ('DM','north-america'),
    ('DO','north-america'), ('SV','north-america'), ('GD','north-america'), ('GT','north-america'),
    ('HT','north-america'), ('HN','north-america'), ('JM','north-america'), ('MX','north-america'),
    ('NI','north-america'), ('PA','north-america'), ('KN','north-america'), ('LC','north-america'),
    ('VC','north-america'), ('TT','north-america'), ('US','north-america'),
    ('AL','europe'), ('AD','europe'), ('AT','europe'), ('BY','europe'), ('BE','europe'), ('BA','europe'),
    ('BG','europe'), ('HR','europe'), ('CZ','europe'), ('DK','europe'), ('EE','europe'), ('FI','europe'),
    ('FR','europe'), ('DE','europe'), ('GR','europe'), ('VA','europe'), ('HU','europe'), ('IS','europe'),
    ('IE','europe'), ('IT','europe'), ('LV','europe'), ('LI','europe'), ('LT','europe'), ('LU','europe'),
    ('MT','europe'), ('MD','europe'), ('MC','europe'), ('ME','europe'), ('NL','europe'), ('MK','europe'),
    ('NO','europe'), ('PL','europe'), ('PT','europe'), ('RO','europe'), ('RU','europe'), ('SM','europe'),
    ('RS','europe'), ('SK','europe'), ('SI','europe'), ('ES','europe'), ('SE','europe'), ('CH','europe'),
    ('UA','europe'), ('GB','europe'),
    ('DZ','africa'), ('AO','africa'), ('BJ','africa'), ('BW','africa'), ('BF','africa'), ('BI','africa'),
    ('CV','africa'), ('CM','africa'), ('CF','africa'), ('TD','africa'), ('KM','africa'), ('CG','africa'),
    ('CD','africa'), ('CI','africa'), ('DJ','africa'), ('EG','africa'), ('GQ','africa'), ('ER','africa'),
    ('SZ','africa'), ('ET','africa'), ('GA','africa'), ('GM','africa'), ('GH','africa'), ('GN','africa'),
    ('GW','africa'), ('KE','africa'), ('LS','africa'), ('LR','africa'), ('LY','africa'), ('MG','africa'),
    ('MW','africa'), ('ML','africa'), ('MR','africa'), ('MU','africa'), ('MA','africa'), ('MZ','africa'),
    ('NA','africa'), ('NE','africa'), ('NG','africa'), ('RW','africa'), ('ST','africa'), ('SN','africa'),
    ('SC','africa'), ('SL','africa'), ('SO','africa'), ('ZA','africa'), ('SS','africa'), ('SD','africa'),
    ('TZ','africa'), ('TG','africa'), ('TN','africa'), ('UG','africa'), ('ZM','africa'), ('ZW','africa'),
    ('AF','asia'), ('AM','asia'), ('AZ','asia'), ('BH','asia'), ('BD','asia'), ('BT','asia'),
    ('BN','asia'), ('KH','asia'), ('CN','asia'), ('CY','asia'), ('GE','asia'), ('IN','asia'),
    ('ID','asia'), ('IR','asia'), ('IQ','asia'), ('IL','asia'), ('JP','asia'), ('JO','asia'),
    ('KZ','asia'), ('KW','asia'), ('KG','asia'), ('LA','asia'), ('LB','asia'), ('MY','asia'),
    ('MV','asia'), ('MN','asia'), ('MM','asia'), ('NP','asia'), ('KP','asia'), ('OM','asia'),
    ('PK','asia'), ('PS','asia'), ('PH','asia'), ('QA','asia'), ('SA','asia'), ('SG','asia'),
    ('KR','asia'), ('LK','asia'), ('SY','asia'), ('TJ','asia'), ('TH','asia'), ('TL','asia'),
    ('TR','asia'), ('TM','asia'), ('AE','asia'), ('UZ','asia'), ('VN','asia'), ('YE','asia'),
    ('AU','oceania'), ('FJ','oceania'), ('KI','oceania'), ('MH','oceania'), ('FM','oceania'),
    ('NR','oceania'), ('NZ','oceania'), ('PW','oceania'), ('PG','oceania'), ('WS','oceania'),
    ('SB','oceania'), ('TO','oceania'), ('TV','oceania'), ('VU','oceania')
$$;


ALTER FUNCTION "private"."challenge_country_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."challenge_public_status"("p_challenge_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'private', 'public'
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


ALTER FUNCTION "private"."challenge_public_status"("p_challenge_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."challenge_question_count"("p_mode" "text", "p_variation" "text") RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'private'
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


ALTER FUNCTION "private"."challenge_question_count"("p_mode" "text", "p_variation" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."challenge_sequence_hash"("p_mode" "text", "p_variation" "text", "p_question_codes" "jsonb", "p_rules_version" integer, "p_algorithm_version" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'private', 'public'
    AS $$
DECLARE
    v_joined_codes TEXT;
BEGIN
    SELECT string_agg(value, ',' ORDER BY ord)
    INTO v_joined_codes
    FROM jsonb_array_elements_text(p_question_codes) WITH ORDINALITY AS q(value, ord);

    RETURN encode(
        extensions.digest(
            concat_ws('|', p_mode, p_variation, p_rules_version::TEXT, p_algorithm_version, COALESCE(v_joined_codes, '')),
            'sha256'
        ),
        'hex'
    );
END;
$$;


ALTER FUNCTION "private"."challenge_sequence_hash"("p_mode" "text", "p_variation" "text", "p_question_codes" "jsonb", "p_rules_version" integer, "p_algorithm_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."challenge_validate_question_codes"("p_mode" "text", "p_variation" "text", "p_question_codes" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'private', 'public'
    AS $$
DECLARE
    v_expected_count INTEGER;
    v_total_count INTEGER;
    v_distinct_count INTEGER;
    v_invalid_count INTEGER;
BEGIN
    IF jsonb_typeof(p_question_codes) <> 'array' THEN
        RAISE EXCEPTION 'Invalid question sequence';
    END IF;

    v_expected_count := private.challenge_question_count(p_mode, p_variation);

    SELECT count(*), count(DISTINCT value)
    INTO v_total_count, v_distinct_count
    FROM jsonb_array_elements_text(p_question_codes) AS q(value);

    IF v_total_count <> v_expected_count OR v_distinct_count <> v_total_count THEN
        RAISE EXCEPTION 'Invalid question sequence';
    END IF;

    SELECT count(*)
    INTO v_invalid_count
    FROM jsonb_array_elements_text(p_question_codes) AS q(value)
    LEFT JOIN private.challenge_country_catalog() c
      ON c.code = q.value
     AND (p_mode = 'world' OR c.continent = p_variation)
    WHERE c.code IS NULL;

    IF v_invalid_count <> 0 THEN
        RAISE EXCEPTION 'Invalid question sequence';
    END IF;
END;
$$;


ALTER FUNCTION "private"."challenge_validate_question_codes"("p_mode" "text", "p_variation" "text", "p_question_codes" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."challenge_winner_payload"("p_challenge_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'private', 'public'
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


ALTER FUNCTION "private"."challenge_winner_payload"("p_challenge_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."generate_challenge_code"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'private', 'public'
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


ALTER FUNCTION "private"."generate_challenge_code"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."accept_challenge"("p_challenge_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."accept_challenge"("p_challenge_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_challenge"("p_challenge_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."cancel_challenge"("p_challenge_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_is_supporter"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private'
    AS $_$
DECLARE
    v_sql TEXT;
    v_result BOOLEAN;
BEGIN
    IF to_regclass('private.supporter_entitlements') IS NULL THEN
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.supporter_entitlements'::regclass
          AND attname = 'user_id'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        RETURN FALSE;
    END IF;

    v_sql := 'SELECT EXISTS (SELECT 1 FROM private.supporter_entitlements WHERE user_id = $1';

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.supporter_entitlements'::regclass
          AND attname = 'status'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_sql := v_sql || ' AND status = ''active''';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.supporter_entitlements'::regclass
          AND attname = 'revoked_at'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_sql := v_sql || ' AND (revoked_at IS NULL OR revoked_at > NOW())';
    END IF;

    v_sql := v_sql || ')';

    EXECUTE v_sql USING p_user_id INTO v_result;
    RETURN COALESCE(v_result, FALSE);
END;
$_$;


ALTER FUNCTION "public"."check_is_supporter"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_challenge"("p_mode" "text", "p_variation" "text", "p_idemp_key" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."create_challenge"("p_mode" "text", "p_variation" "text", "p_idemp_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_challenge_from_completed_match"("p_base_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer, "p_idemp_key" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
    AS $_$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce_hash TEXT;
    v_base RECORD;
    v_is_supporter BOOLEAN;
    v_daily_count INTEGER;
    v_code TEXT;
    v_challenge_id UUID;
    v_result_id UUID;
    v_accuracy NUMERIC(5,2);
    v_score INTEGER;
    v_idemp_key TEXT;
    v_event_id TEXT;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '7 days';
    v_public_config JSONB;
    v_scoring JSONB;
    v_result_payload JSONB;
    v_result_columns TEXT;
    v_result_values TEXT;
    v_result_insert_sql TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_base_nonce IS NULL OR length(trim(p_base_nonce)) < 32 OR length(trim(p_base_nonce)) > 128 THEN
        RAISE EXCEPTION 'Invalid base match session';
    END IF;

    v_event_id := trim(COALESCE(p_event_id, ''));
    v_idemp_key := trim(COALESCE(p_idemp_key, ''));

    IF length(v_event_id) < 8 OR length(v_event_id) > 128 THEN
        RAISE EXCEPTION 'Invalid event id';
    END IF;

    IF length(v_idemp_key) < 8 OR length(v_idemp_key) > 128 THEN
        RAISE EXCEPTION 'Invalid idempotency key';
    END IF;

    v_nonce_hash := encode(extensions.digest(p_base_nonce, 'sha256'), 'hex');

    SELECT *
    INTO v_base
    FROM private.challenge_base_match_sessions
    WHERE session_nonce_hash = v_nonce_hash
      AND user_id = v_user_id
      AND status = 'created'
    FOR UPDATE;

    IF NOT FOUND THEN
        SELECT c.id, c.code, c.expires_at
        INTO v_challenge_id, v_code, v_expires_at
        FROM public.challenges c
        WHERE c.creator_id = v_user_id
          AND c.idempotency_key = v_idemp_key;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'challenge_id', v_challenge_id,
                'code', v_code,
                'expires_at', v_expires_at,
                'restored', TRUE
            );
        END IF;

        RAISE EXCEPTION 'Invalid base match session';
    END IF;

    IF v_base.expires_at < NOW() THEN
        RAISE EXCEPTION 'Base match session expired';
    END IF;

    PERFORM private.challenge_validate_question_codes(v_base.mode, v_base.variation, v_base.question_codes);

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
       OR p_streak > p_correct
       OR (p_correct + p_wrong + p_skipped) <> p_total
       OR p_total <> v_base.question_count THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    SELECT c.id, c.code, c.expires_at
    INTO v_challenge_id, v_code, v_expires_at
    FROM public.challenges c
    WHERE c.creator_id = v_user_id
      AND c.idempotency_key = v_idemp_key;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'challenge_id', v_challenge_id,
            'code', v_code,
            'expires_at', v_expires_at,
            'restored', TRUE
        );
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::TEXT));

    SELECT c.id, c.code, c.expires_at
    INTO v_challenge_id, v_code, v_expires_at
    FROM public.challenges c
    WHERE c.creator_id = v_user_id
      AND c.idempotency_key = v_idemp_key;

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

    v_score := p_correct;
    v_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);
    v_code := private.generate_challenge_code();
    v_result_payload := jsonb_build_object(
        'event_id', v_event_id,
        'user_id', v_user_id,
        'mode', v_base.mode,
        'variation', v_base.variation,
        'rules_version', v_base.rules_version,
        'score', v_score,
        'correct_answers', p_correct,
        'wrong_answers', p_wrong,
        'skipped_answers', p_skipped,
        'total_questions', p_total,
        'accuracy', v_accuracy,
        'elapsed_time_ms', p_time_ms,
        'best_streak', p_streak,
        'hearts_used', FALSE,
        'is_ranked', FALSE,
        'verification_status', 'verified',
        'received_at', NOW(),
        'created_at', NOW()
    );

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
        'mode', v_base.mode,
        'variation', v_base.variation,
        'question_count', v_base.question_count,
        'sequence_hash', v_base.sequence_hash,
        'rules_version', v_base.rules_version,
        'allow_hearts', v_base.allow_hearts,
        'source', 'completed_match'
    );

    SELECT
        string_agg(format('%I', a.attname), ', ' ORDER BY a.attnum),
        string_agg(
            format('($1->>%L)::%s', a.attname, format_type(a.atttypid, a.atttypmod)),
            ', ' ORDER BY a.attnum
        )
    INTO v_result_columns, v_result_values
    FROM pg_attribute a
    WHERE a.attrelid = 'public.game_results'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND a.attname IN (
          'event_id',
          'user_id',
          'mode',
          'variation',
          'rules_version',
          'score',
          'correct_answers',
          'wrong_answers',
          'skipped_answers',
          'total_questions',
          'accuracy',
          'elapsed_time_ms',
          'best_streak',
          'hearts_used',
          'is_ranked',
          'verification_status',
          'received_at',
          'created_at'
      );

    IF v_result_columns IS NULL OR v_result_values IS NULL THEN
        RAISE EXCEPTION 'No compatible columns found in public.game_results';
    END IF;

    v_result_insert_sql := format(
        'INSERT INTO public.game_results (%s) VALUES (%s) RETURNING id',
        v_result_columns,
        v_result_values
    );

    EXECUTE v_result_insert_sql USING v_result_payload INTO v_result_id;

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
        v_base.mode,
        v_base.variation,
        v_idemp_key,
        v_public_config,
        v_base.rules_version,
        v_base.allow_hearts,
        'open',
        v_expires_at
    )
    RETURNING id INTO v_challenge_id;

    INSERT INTO private.challenge_configs (
        challenge_id,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        sequence_hash,
        base_match_id,
        rules_version,
        allow_hearts,
        scoring
    )
    VALUES (
        v_challenge_id,
        v_base.seed,
        v_base.algorithm_version,
        v_base.question_codes,
        v_base.question_count,
        v_base.sequence_hash,
        v_base.id,
        v_base.rules_version,
        v_base.allow_hearts,
        v_scoring
    );

    INSERT INTO public.challenge_participants (
        challenge_id,
        user_id,
        role,
        status,
        accepted_at,
        started_at,
        completed_at,
        result_id,
        event_id,
        score,
        correct_answers,
        wrong_answers,
        skipped_answers,
        total_questions,
        accuracy,
        elapsed_time_ms,
        best_streak
    )
    VALUES (
        v_challenge_id,
        v_user_id,
        'creator',
        'completed',
        v_base.started_at,
        v_base.started_at,
        NOW(),
        v_result_id,
        v_event_id,
        v_score,
        p_correct,
        p_wrong,
        p_skipped,
        p_total,
        v_accuracy,
        p_time_ms,
        p_streak
    );

    UPDATE private.challenge_base_match_sessions
    SET status = 'completed',
        completed_at = NOW(),
        result_id = v_result_id,
        challenge_id = v_challenge_id,
        event_id = v_event_id,
        idempotency_key = v_idemp_key
    WHERE id = v_base.id;

    RETURN jsonb_build_object(
        'challenge_id', v_challenge_id,
        'code', v_code,
        'expires_at', v_expires_at,
        'result_id', v_result_id,
        'sequence_hash', v_base.sequence_hash,
        'challenge_status', private.challenge_public_status(v_challenge_id),
        'remaining_daily', CASE
            WHEN v_is_supporter THEN -1
            ELSE GREATEST(2 - (COALESCE(v_daily_count, 0) + 1), 0)
        END,
        'is_supporter', v_is_supporter
    );
END;
$_$;


ALTER FUNCTION "public"."create_challenge_from_completed_match"("p_base_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer, "p_idemp_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_ranked_session"("p_mode" "text", "p_variation" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'private', 'public', 'auth'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce TEXT;
    v_nonce_hash TEXT;
    v_session_id UUID;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '30 minutes';
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    -- Gerar nonce aleatório (32 bytes)
    v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
    v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');

    INSERT INTO private.ranked_game_sessions (user_id, session_nonce_hash, mode, variation, expires_at)
    VALUES (v_user_id, v_nonce_hash, p_mode, p_variation, v_expires_at)
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'nonce', v_nonce,
        'expires_at', v_expires_at
    );
END;
$$;


ALTER FUNCTION "public"."create_ranked_session"("p_mode" "text", "p_variation" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_profile"("p_nickname" "text" DEFAULT 'Player'::"text", "p_country" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $_$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
    v_clean_nickname TEXT;
    v_clean_country CHAR(2);
BEGIN
    -- Validação de Autenticação
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;

    -- Validação e Sanitização do Apelido (Nickname) no Banco
    v_clean_nickname := trim(p_nickname);
    IF v_clean_nickname IS NULL OR char_length(v_clean_nickname) < 3 OR v_clean_nickname !~ '^[a-zA-Z0-9 _-]+$' THEN
        v_clean_nickname := 'Player';
    END IF;
    v_clean_nickname := substring(v_clean_nickname from 1 for 24);

    -- Validação e Sanitização do País (Country)
    v_clean_country := upper(trim(p_country));
    IF v_clean_country !~ '^[A-Z]{2}$' THEN
        v_clean_country := NULL;
    END IF;

    -- Operação Idempotente
    INSERT INTO public.profiles (id, nickname, country_code)
    VALUES (v_user_id, v_clean_nickname, v_clean_country)
    ON CONFLICT (id) DO UPDATE SET
        updated_at = NOW()
    WHERE profiles.id = v_user_id;

    -- Obter o registro final para retorno
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'id', v_profile.id,
        'nickname', v_profile.nickname,
        'country_code', v_profile.country_code,
        'avatar_key', v_profile.avatar_key,
        'updated_at', v_profile.updated_at
    );
END;
$_$;


ALTER FUNCTION "public"."ensure_profile"("p_nickname" "text", "p_country" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_challenge_preview"("p_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."get_challenge_preview"("p_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_challenge_result"("p_challenge_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."get_challenge_result"("p_challenge_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_daily_challenge_quota"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."get_daily_challenge_quota"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_my_challenges"("p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."list_my_challenges"("p_status" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_challenge_code"("p_code" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $_$
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
$_$;


ALTER FUNCTION "public"."normalize_challenge_code"("p_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_challenge_base_match"("p_mode" "text", "p_variation" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_seed TEXT;
    v_nonce TEXT;
    v_nonce_hash TEXT;
    v_session_id UUID;
    v_question_codes JSONB;
    v_question_count INTEGER;
    v_sequence_hash TEXT;
    v_algorithm_version TEXT := 'server-sequence-v1';
    v_rules_version INTEGER := 1;
    v_expires_at TIMESTAMPTZ := NOW() + INTERVAL '45 minutes';
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_mode NOT IN ('world', 'continent') THEN
        RAISE EXCEPTION 'Invalid challenge mode';
    END IF;

    v_question_count := private.challenge_question_count(p_mode, p_variation);
    v_seed := encode(extensions.gen_random_bytes(16), 'hex');
    v_question_codes := private.challenge_build_question_codes(p_mode, p_variation, v_seed);
    PERFORM private.challenge_validate_question_codes(p_mode, p_variation, v_question_codes);
    v_sequence_hash := private.challenge_sequence_hash(p_mode, p_variation, v_question_codes, v_rules_version, v_algorithm_version);

    v_nonce := encode(extensions.gen_random_bytes(32), 'hex');
    v_nonce_hash := encode(extensions.digest(v_nonce, 'sha256'), 'hex');

    INSERT INTO private.challenge_base_match_sessions (
        user_id,
        session_nonce_hash,
        mode,
        variation,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        sequence_hash,
        rules_version,
        allow_hearts,
        expires_at
    )
    VALUES (
        v_user_id,
        v_nonce_hash,
        p_mode,
        p_variation,
        v_seed,
        v_algorithm_version,
        v_question_codes,
        v_question_count,
        v_sequence_hash,
        v_rules_version,
        FALSE,
        v_expires_at
    )
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'base_match_session_id', v_session_id,
        'session_id', v_session_id,
        'nonce', v_nonce,
        'expires_at', v_expires_at,
        'config', jsonb_build_object(
            'mode', p_mode,
            'variation', p_variation,
            'seed', v_seed,
            'algorithm_version', v_algorithm_version,
            'question_codes', v_question_codes,
            'question_count', v_question_count,
            'sequence_hash', v_sequence_hash,
            'rules_version', v_rules_version,
            'allow_hearts', FALSE
        )
    );
END;
$$;


ALTER FUNCTION "public"."start_challenge_base_match"("p_mode" "text", "p_variation" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_challenge_session"("p_challenge_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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
    v_fallback_seed TEXT;
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

    v_fallback_seed := encode(extensions.gen_random_bytes(16), 'hex');

    UPDATE private.challenge_configs cc
    SET seed = COALESCE(NULLIF(cc.seed, ''), v_fallback_seed),
        algorithm_version = CASE
            WHEN COALESCE(NULLIF(cc.algorithm_version, ''), '') = '' THEN 'server-sequence-v1'
            ELSE cc.algorithm_version
        END,
        question_codes = private.challenge_build_question_codes(
            v_challenge.mode,
            v_challenge.variation,
            COALESCE(NULLIF(cc.seed, ''), v_fallback_seed)
        ),
        sequence_hash = NULL
    WHERE cc.challenge_id = v_challenge.id
      AND COALESCE(
        jsonb_array_length(
            CASE
                WHEN jsonb_typeof(cc.question_codes) = 'array' THEN cc.question_codes
                ELSE '[]'::jsonb
            END
        ),
        0
      ) = 0;

    INSERT INTO private.challenge_configs (
        challenge_id,
        seed,
        algorithm_version,
        question_codes,
        question_count,
        sequence_hash,
        rules_version,
        allow_hearts,
        scoring
    )
    VALUES (
        v_challenge.id,
        v_fallback_seed,
        'server-sequence-v1',
        private.challenge_build_question_codes(
            v_challenge.mode,
            v_challenge.variation,
            v_fallback_seed
        ),
        private.challenge_question_count(v_challenge.mode, v_challenge.variation),
        NULL,
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

    UPDATE private.challenge_configs cc
    SET sequence_hash = private.challenge_sequence_hash(
        v_challenge.mode,
        v_challenge.variation,
        cc.question_codes,
        cc.rules_version,
        cc.algorithm_version
    )
    WHERE cc.challenge_id = v_challenge.id
      AND cc.sequence_hash IS NULL;

    SELECT jsonb_build_object(
        'mode', v_challenge.mode,
        'variation', v_challenge.variation,
        'seed', cc.seed,
        'algorithm_version', cc.algorithm_version,
        'question_codes', cc.question_codes,
        'question_count', cc.question_count,
        'sequence_hash', cc.sequence_hash,
        'rules_version', cc.rules_version,
        'allow_hearts', cc.allow_hearts,
        'scoring', cc.scoring
    )
    INTO v_config_snapshot
    FROM private.challenge_configs cc
    WHERE cc.challenge_id = v_challenge.id;

    PERFORM private.challenge_validate_question_codes(
        v_challenge.mode,
        v_challenge.variation,
        v_config_snapshot->'question_codes'
    );

    v_client_config := v_config_snapshot - 'scoring';

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


ALTER FUNCTION "public"."start_challenge_session"("p_challenge_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_challenge_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'private', 'auth'
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


ALTER FUNCTION "public"."submit_challenge_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_ranked_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'private', 'public', 'auth'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce_hash TEXT;
    v_session_id UUID;
    v_session_mode TEXT;
    v_session_variation TEXT;
    v_result_id UUID;
    v_calculated_score INTEGER;
    v_calculated_accuracy NUMERIC;
    v_stage TEXT := 'start';
    v_error_state TEXT;
BEGIN
    v_stage := 'auth';
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_stage := 'hash_nonce';
    v_nonce_hash := encode(extensions.digest(p_nonce, 'sha256'), 'hex');

    v_stage := 'load_session';
    SELECT s.id, s.mode, s.variation
    INTO v_session_id, v_session_mode, v_session_variation
    FROM private.ranked_game_sessions s
    WHERE s.session_nonce_hash = v_nonce_hash
      AND s.user_id = v_user_id
      AND s.status = 'created'
    FOR UPDATE;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Invalid session or already used';
    END IF;

    v_stage := 'check_expiration';
    IF EXISTS (
        SELECT 1
        FROM private.ranked_game_sessions s
        WHERE s.id = v_session_id
          AND s.expires_at < NOW()
    ) THEN
        UPDATE private.ranked_game_sessions
        SET status = 'expired'
        WHERE id = v_session_id;

        RAISE EXCEPTION 'Session expired';
    END IF;

    v_stage := 'validate_numbers';
    IF (p_correct + p_wrong + p_skipped) != p_total OR p_total <= 0 THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    v_stage := 'calculate_score';
    v_calculated_score := p_correct;
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    v_stage := 'insert_game_results';
    INSERT INTO public.game_results (
        event_id,
        user_id,
        ranked_session_id,
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
        p_event_id,
        v_user_id,
        v_session_id,
        v_calculated_score,
        p_correct,
        p_total,
        v_calculated_accuracy,
        p_time_ms,
        FALSE,
        TRUE,
        'verified',
        NOW()
    )
    RETURNING id INTO v_result_id;

    v_stage := 'complete_session_status';
    UPDATE private.ranked_game_sessions
    SET status = 'completed'
    WHERE id = v_session_id;

    RETURN jsonb_build_object(
        'result_id', v_result_id,
        'status', 'verified',
        'mode', v_session_mode,
        'variation', v_session_variation
    );
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_error_state = RETURNED_SQLSTATE;

    RAISE EXCEPTION USING
        ERRCODE = v_error_state,
        MESSAGE = format('submit_ranked_result failed at %s [%s]', v_stage, v_error_state),
        DETAIL = NULL,
        HINT = 'Check session nonce/status/expiration and remote table constraints.';
END;
$$;


ALTER FUNCTION "public"."submit_ranked_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "private"."challenge_base_match_sessions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "session_nonce_hash" "text" NOT NULL,
    "mode" "text" NOT NULL,
    "variation" "text" NOT NULL,
    "seed" "text" NOT NULL,
    "algorithm_version" "text" DEFAULT 'server-sequence-v1'::"text" NOT NULL,
    "question_codes" "jsonb" NOT NULL,
    "question_count" integer NOT NULL,
    "sequence_hash" "text" NOT NULL,
    "rules_version" integer DEFAULT 1 NOT NULL,
    "allow_hearts" boolean DEFAULT false NOT NULL,
    "status" "text" DEFAULT 'created'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "result_id" "uuid",
    "challenge_id" "uuid",
    "event_id" "text",
    "idempotency_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "challenge_base_match_sessions_status_check" CHECK (("status" = ANY (ARRAY['created'::"text", 'completed'::"text", 'expired'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "challenge_base_question_codes_array" CHECK (("jsonb_typeof"("question_codes") = 'array'::"text")),
    CONSTRAINT "challenge_base_question_count_positive" CHECK (("question_count" > 0))
);


ALTER TABLE "private"."challenge_base_match_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "private"."challenge_configs" (
    "challenge_id" "uuid" NOT NULL,
    "seed" "text" NOT NULL,
    "algorithm_version" "text" DEFAULT 'challenge-v1'::"text" NOT NULL,
    "question_codes" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "question_count" integer NOT NULL,
    "rules_version" integer DEFAULT 1 NOT NULL,
    "allow_hearts" boolean DEFAULT false NOT NULL,
    "scoring" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sequence_hash" "text",
    "base_match_id" "uuid",
    CONSTRAINT "challenge_configs_question_codes_array" CHECK (("jsonb_typeof"("question_codes") = 'array'::"text")),
    CONSTRAINT "challenge_configs_question_count_positive" CHECK (("question_count" > 0))
);


ALTER TABLE "private"."challenge_configs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "private"."challenge_sessions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "challenge_id" "uuid" NOT NULL,
    "participant_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "session_nonce_hash" "text" NOT NULL,
    "config_snapshot" "jsonb" NOT NULL,
    "status" "text" DEFAULT 'created'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "result_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "challenge_sessions_status_check" CHECK (("status" = ANY (ARRAY['created'::"text", 'completed'::"text", 'expired'::"text", 'cancelled'::"text", 'rejected'::"text"])))
);


ALTER TABLE "private"."challenge_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "private"."ranked_game_sessions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "session_nonce_hash" "text" NOT NULL,
    "mode" "text" NOT NULL,
    "variation" "text" NOT NULL,
    "status" "public"."session_status_t" DEFAULT 'created'::"public"."session_status_t",
    "expires_at" timestamp with time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "private"."ranked_game_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "private"."supporter_entitlements" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "public"."supporter_status_t" DEFAULT 'pending'::"public"."supporter_status_t",
    "product_id" "text" NOT NULL,
    "source" "public"."entitlement_source_t" DEFAULT 'google_play'::"public"."entitlement_source_t",
    "granted_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "private"."supporter_entitlements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."challenge_participants" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "challenge_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "status" "text" DEFAULT 'accepted'::"text" NOT NULL,
    "accepted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "result_id" "uuid",
    "event_id" "text",
    "score" integer,
    "correct_answers" integer,
    "wrong_answers" integer,
    "skipped_answers" integer,
    "total_questions" integer,
    "accuracy" numeric(5,2),
    "elapsed_time_ms" integer,
    "best_streak" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "challenge_participants_math" CHECK ((("total_questions" IS NULL) OR ("correct_answers" IS NULL) OR ("wrong_answers" IS NULL) OR ("skipped_answers" IS NULL) OR ((("correct_answers" + "wrong_answers") + "skipped_answers") = "total_questions"))),
    CONSTRAINT "challenge_participants_role_check" CHECK (("role" = ANY (ARRAY['creator'::"text", 'opponent'::"text"]))),
    CONSTRAINT "challenge_participants_role_valid" CHECK (("role" = ANY (ARRAY['creator'::"text", 'opponent'::"text"]))),
    CONSTRAINT "challenge_participants_status_check" CHECK (("status" = ANY (ARRAY['accepted'::"text", 'playing'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."challenge_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."challenges" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "creator_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "mode" "text" NOT NULL,
    "variation" "text" NOT NULL,
    "idempotency_key" "text",
    "status" "public"."challenge_status_t" DEFAULT 'open'::"public"."challenge_status_t",
    "expires_at" timestamp with time zone DEFAULT ("now"() + '7 days'::interval),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "config" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "rules_version" integer DEFAULT 1 NOT NULL,
    "allow_hearts" boolean DEFAULT false NOT NULL,
    "cancelled_at" timestamp with time zone
);


ALTER TABLE "public"."challenges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."game_results" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "event_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "ranked_session_id" "uuid",
    "score" integer DEFAULT 0,
    "correct_answers" integer NOT NULL,
    "total_questions" integer NOT NULL,
    "accuracy" numeric(5,2) NOT NULL,
    "elapsed_time_ms" integer NOT NULL,
    "hearts_used" boolean DEFAULT false,
    "is_ranked" boolean DEFAULT false,
    "verification_status" "public"."verification_status_t" DEFAULT 'unverified'::"public"."verification_status_t",
    "received_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."game_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "nickname" "text" NOT NULL,
    "country_code" character(2) DEFAULT 'BR'::"bpchar",
    "avatar_key" "text",
    "privacy_settings" "jsonb" DEFAULT '{"show_detailed_stats": false}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "nickname_length" CHECK ((("char_length"("nickname") >= 3) AND ("char_length"("nickname") <= 24)))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."global_rankings" WITH ("security_invoker"='false') AS
 WITH "normalized_results" AS (
         SELECT "gr"."user_id",
            COALESCE(("to_jsonb"("rgs".*) ->> 'mode'::"text"), ("to_jsonb"("gr".*) ->> 'mode'::"text"), ("to_jsonb"("gr".*) ->> 'game_mode'::"text"), ("to_jsonb"("gr".*) ->> 'ranking_mode'::"text")) AS "ranking_mode",
            COALESCE(("to_jsonb"("rgs".*) ->> 'variation'::"text"), ("to_jsonb"("gr".*) ->> 'variation'::"text"), ("to_jsonb"("gr".*) ->> 'ranking_variation'::"text")) AS "variation",
            COALESCE((NULLIF(("to_jsonb"("rgs".*) ->> 'rules_version'::"text"), ''::"text"))::integer, (NULLIF(("to_jsonb"("gr".*) ->> 'rules_version'::"text"), ''::"text"))::integer, 1) AS "rules_version",
            COALESCE((NULLIF(("to_jsonb"("gr".*) ->> 'score'::"text"), ''::"text"))::integer, 0) AS "score",
            COALESCE((NULLIF(("to_jsonb"("gr".*) ->> 'correct_answers'::"text"), ''::"text"))::integer, (NULLIF(("to_jsonb"("gr".*) ->> 'correct'::"text"), ''::"text"))::integer, (NULLIF(("to_jsonb"("gr".*) ->> 'score'::"text"), ''::"text"))::integer, 0) AS "correct_answers",
            COALESCE((NULLIF(("to_jsonb"("gr".*) ->> 'elapsed_time_ms'::"text"), ''::"text"))::integer, (NULLIF(("to_jsonb"("gr".*) ->> 'time_ms'::"text"), ''::"text"))::integer, (NULLIF(("to_jsonb"("gr".*) ->> 'duration_ms'::"text"), ''::"text"))::integer, 0) AS "elapsed_time_ms",
            COALESCE((NULLIF(("to_jsonb"("gr".*) ->> 'best_streak'::"text"), ''::"text"))::integer, 0) AS "best_streak",
            COALESCE((NULLIF(("to_jsonb"("gr".*) ->> 'created_at'::"text"), ''::"text"))::timestamp with time zone, (NULLIF(("to_jsonb"("gr".*) ->> 'received_at'::"text"), ''::"text"))::timestamp with time zone, "now"()) AS "created_at"
           FROM ("public"."game_results" "gr"
             LEFT JOIN "private"."ranked_game_sessions" "rgs" ON (("rgs"."id" = "gr"."ranked_session_id")))
          WHERE ((COALESCE((NULLIF(("to_jsonb"("gr".*) ->> 'is_ranked'::"text"), ''::"text"))::boolean, ("gr"."ranked_session_id" IS NOT NULL)) = true) AND (COALESCE(NULLIF(("to_jsonb"("gr".*) ->> 'verification_status'::"text"), ''::"text"), 'verified'::"text") = 'verified'::"text") AND (COALESCE((NULLIF(("to_jsonb"("gr".*) ->> 'hearts_used'::"text"), ''::"text"))::boolean, false) = false))
        ), "best_results" AS (
         SELECT "normalized_results"."user_id",
            "normalized_results"."ranking_mode",
            "normalized_results"."variation",
            "normalized_results"."rules_version",
            "normalized_results"."score",
            "normalized_results"."correct_answers",
            "normalized_results"."elapsed_time_ms",
            "normalized_results"."best_streak",
            "normalized_results"."created_at" AS "achieved_at",
            "row_number"() OVER (PARTITION BY "normalized_results"."user_id", "normalized_results"."ranking_mode", "normalized_results"."variation", "normalized_results"."rules_version" ORDER BY "normalized_results"."score" DESC, "normalized_results"."correct_answers" DESC, "normalized_results"."elapsed_time_ms", "normalized_results"."best_streak" DESC, "normalized_results"."created_at") AS "result_priority"
           FROM "normalized_results"
          WHERE ("normalized_results"."ranking_mode" IS NOT NULL)
        )
 SELECT "br"."user_id",
    "br"."ranking_mode" AS "mode",
    "br"."variation",
    "br"."rules_version",
    "br"."score",
    "br"."correct_answers",
    "br"."elapsed_time_ms",
    "br"."best_streak",
    "br"."achieved_at",
    "p"."nickname",
    "p"."country_code",
    "public"."check_is_supporter"("br"."user_id") AS "is_supporter"
   FROM ("best_results" "br"
     JOIN "public"."profiles" "p" ON (("p"."id" = "br"."user_id")))
  WHERE ("br"."result_priority" = 1);


ALTER VIEW "public"."global_rankings" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."supporter_status" AS
 SELECT "id" AS "user_id",
    (EXISTS ( SELECT 1
           FROM "private"."supporter_entitlements"
          WHERE (("supporter_entitlements"."user_id" = "p"."id") AND ("supporter_entitlements"."status" = 'active'::"public"."supporter_status_t")))) AS "is_supporter"
   FROM "public"."profiles" "p";


ALTER VIEW "public"."supporter_status" OWNER TO "postgres";


ALTER TABLE ONLY "private"."challenge_base_match_sessions"
    ADD CONSTRAINT "challenge_base_match_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "private"."challenge_base_match_sessions"
    ADD CONSTRAINT "challenge_base_match_sessions_session_nonce_hash_key" UNIQUE ("session_nonce_hash");



ALTER TABLE ONLY "private"."challenge_configs"
    ADD CONSTRAINT "challenge_configs_pkey" PRIMARY KEY ("challenge_id");



ALTER TABLE ONLY "private"."challenge_sessions"
    ADD CONSTRAINT "challenge_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "private"."challenge_sessions"
    ADD CONSTRAINT "challenge_sessions_session_nonce_hash_key" UNIQUE ("session_nonce_hash");



ALTER TABLE ONLY "private"."ranked_game_sessions"
    ADD CONSTRAINT "ranked_game_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "private"."ranked_game_sessions"
    ADD CONSTRAINT "ranked_game_sessions_session_nonce_hash_key" UNIQUE ("session_nonce_hash");



ALTER TABLE ONLY "private"."supporter_entitlements"
    ADD CONSTRAINT "supporter_entitlements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "private"."supporter_entitlements"
    ADD CONSTRAINT "supporter_entitlements_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."challenge_participants"
    ADD CONSTRAINT "challenge_participants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."challenge_participants"
    ADD CONSTRAINT "challenge_participants_unique_user" UNIQUE ("challenge_id", "user_id");



ALTER TABLE ONLY "public"."challenges"
    ADD CONSTRAINT "challenges_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."challenges"
    ADD CONSTRAINT "challenges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."game_results"
    ADD CONSTRAINT "game_results_event_id_key" UNIQUE ("event_id");



ALTER TABLE ONLY "public"."game_results"
    ADD CONSTRAINT "game_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



CREATE UNIQUE INDEX "idx_challenge_base_event" ON "private"."challenge_base_match_sessions" USING "btree" ("event_id") WHERE ("event_id" IS NOT NULL);



CREATE UNIQUE INDEX "idx_challenge_base_idempotency" ON "private"."challenge_base_match_sessions" USING "btree" ("user_id", "idempotency_key") WHERE ("idempotency_key" IS NOT NULL);



CREATE INDEX "idx_challenge_base_nonce" ON "private"."challenge_base_match_sessions" USING "btree" ("session_nonce_hash");



CREATE INDEX "idx_challenge_base_user_created" ON "private"."challenge_base_match_sessions" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_challenge_sessions_nonce" ON "private"."challenge_sessions" USING "btree" ("session_nonce_hash");



CREATE UNIQUE INDEX "idx_challenge_sessions_one_created_per_participant" ON "private"."challenge_sessions" USING "btree" ("participant_id") WHERE ("status" = 'created'::"text");



CREATE INDEX "idx_challenge_sessions_participant" ON "private"."challenge_sessions" USING "btree" ("participant_id", "status");



CREATE UNIQUE INDEX "challenge_participants_one_creator" ON "public"."challenge_participants" USING "btree" ("challenge_id") WHERE ("role" = 'creator'::"text");



CREATE UNIQUE INDEX "challenge_participants_one_opponent" ON "public"."challenge_participants" USING "btree" ("challenge_id") WHERE ("role" = 'opponent'::"text");



CREATE INDEX "idx_challenge_participants_challenge" ON "public"."challenge_participants" USING "btree" ("challenge_id");



CREATE UNIQUE INDEX "idx_challenge_participants_event" ON "public"."challenge_participants" USING "btree" ("event_id") WHERE ("event_id" IS NOT NULL);



CREATE UNIQUE INDEX "idx_challenge_participants_result" ON "public"."challenge_participants" USING "btree" ("result_id") WHERE ("result_id" IS NOT NULL);



CREATE INDEX "idx_challenge_participants_user" ON "public"."challenge_participants" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_challenges_code" ON "public"."challenges" USING "btree" ("code");



CREATE UNIQUE INDEX "idx_challenges_code_unique" ON "public"."challenges" USING "btree" ("code");



CREATE INDEX "idx_challenges_creator_created" ON "public"."challenges" USING "btree" ("creator_id", "created_at" DESC);



CREATE UNIQUE INDEX "idx_challenges_creator_idempotency" ON "public"."challenges" USING "btree" ("creator_id", "idempotency_key") WHERE ("idempotency_key" IS NOT NULL);



CREATE INDEX "idx_challenges_status_expires" ON "public"."challenges" USING "btree" ("status", "expires_at");



ALTER TABLE ONLY "private"."challenge_base_match_sessions"
    ADD CONSTRAINT "challenge_base_match_sessions_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "public"."challenges"("id");



ALTER TABLE ONLY "private"."challenge_base_match_sessions"
    ADD CONSTRAINT "challenge_base_match_sessions_result_id_fkey" FOREIGN KEY ("result_id") REFERENCES "public"."game_results"("id");



ALTER TABLE ONLY "private"."challenge_base_match_sessions"
    ADD CONSTRAINT "challenge_base_match_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "private"."challenge_configs"
    ADD CONSTRAINT "challenge_configs_base_match_id_fkey" FOREIGN KEY ("base_match_id") REFERENCES "private"."challenge_base_match_sessions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "private"."challenge_configs"
    ADD CONSTRAINT "challenge_configs_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "public"."challenges"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "private"."challenge_sessions"
    ADD CONSTRAINT "challenge_sessions_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "public"."challenges"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "private"."challenge_sessions"
    ADD CONSTRAINT "challenge_sessions_participant_id_fkey" FOREIGN KEY ("participant_id") REFERENCES "public"."challenge_participants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "private"."challenge_sessions"
    ADD CONSTRAINT "challenge_sessions_result_id_fkey" FOREIGN KEY ("result_id") REFERENCES "public"."game_results"("id");



ALTER TABLE ONLY "private"."challenge_sessions"
    ADD CONSTRAINT "challenge_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "private"."ranked_game_sessions"
    ADD CONSTRAINT "ranked_game_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "private"."supporter_entitlements"
    ADD CONSTRAINT "supporter_entitlements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."challenge_participants"
    ADD CONSTRAINT "challenge_participants_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "public"."challenges"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."challenge_participants"
    ADD CONSTRAINT "challenge_participants_result_id_fkey" FOREIGN KEY ("result_id") REFERENCES "public"."game_results"("id");



ALTER TABLE ONLY "public"."challenge_participants"
    ADD CONSTRAINT "challenge_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."challenges"
    ADD CONSTRAINT "challenges_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."game_results"
    ADD CONSTRAINT "game_results_ranked_session_id_fkey" FOREIGN KEY ("ranked_session_id") REFERENCES "private"."ranked_game_sessions"("id");



ALTER TABLE ONLY "public"."game_results"
    ADD CONSTRAINT "game_results_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE "private"."challenge_base_match_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "challenge_base_select_own" ON "private"."challenge_base_match_sessions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "private"."challenge_configs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "private"."challenge_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "challenge_sessions_select_own" ON "private"."challenge_sessions" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "private"."ranked_game_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "private"."supporter_entitlements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Acesso público" ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Update próprio" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."challenge_participants" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "challenge_participants_select_own" ON "public"."challenge_participants" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."challenges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."game_results" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "private" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";






















































































































































REVOKE ALL ON FUNCTION "private"."challenge_build_question_codes"("p_mode" "text", "p_variation" "text", "p_seed" "text") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."challenge_country_catalog"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."challenge_public_status"("p_challenge_id" "uuid") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."challenge_question_count"("p_mode" "text", "p_variation" "text") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."challenge_sequence_hash"("p_mode" "text", "p_variation" "text", "p_question_codes" "jsonb", "p_rules_version" integer, "p_algorithm_version" "text") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."challenge_validate_question_codes"("p_mode" "text", "p_variation" "text", "p_question_codes" "jsonb") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."challenge_winner_payload"("p_challenge_id" "uuid") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."generate_challenge_code"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."accept_challenge"("p_challenge_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."accept_challenge"("p_challenge_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_challenge"("p_challenge_code" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_challenge"("p_challenge_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_challenge"("p_challenge_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_challenge"("p_challenge_code" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_is_supporter"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_is_supporter"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_is_supporter"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_challenge"("p_mode" "text", "p_variation" "text", "p_idemp_key" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_challenge"("p_mode" "text", "p_variation" "text", "p_idemp_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_challenge"("p_mode" "text", "p_variation" "text", "p_idemp_key" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_challenge_from_completed_match"("p_base_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer, "p_idemp_key" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_challenge_from_completed_match"("p_base_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer, "p_idemp_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_challenge_from_completed_match"("p_base_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer, "p_idemp_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_ranked_session"("p_mode" "text", "p_variation" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_ranked_session"("p_mode" "text", "p_variation" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_ranked_session"("p_mode" "text", "p_variation" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ensure_profile"("p_nickname" "text", "p_country" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_profile"("p_nickname" "text", "p_country" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_profile"("p_nickname" "text", "p_country" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_challenge_preview"("p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_challenge_preview"("p_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_challenge_preview"("p_code" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_challenge_result"("p_challenge_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_challenge_result"("p_challenge_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_challenge_result"("p_challenge_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_daily_challenge_quota"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_daily_challenge_quota"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_daily_challenge_quota"() TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_my_challenges"("p_status" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_my_challenges"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_my_challenges"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."normalize_challenge_code"("p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."normalize_challenge_code"("p_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_challenge_code"("p_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."start_challenge_base_match"("p_mode" "text", "p_variation" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."start_challenge_base_match"("p_mode" "text", "p_variation" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_challenge_base_match"("p_mode" "text", "p_variation" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."start_challenge_session"("p_challenge_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."start_challenge_session"("p_challenge_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_challenge_session"("p_challenge_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."submit_challenge_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."submit_challenge_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_challenge_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."submit_ranked_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."submit_ranked_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_ranked_result"("p_nonce" "text", "p_event_id" "text", "p_correct" integer, "p_wrong" integer, "p_skipped" integer, "p_total" integer, "p_time_ms" integer, "p_streak" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";


















GRANT ALL ON TABLE "public"."challenge_participants" TO "service_role";



GRANT ALL ON TABLE "public"."challenges" TO "service_role";



GRANT ALL ON TABLE "public"."game_results" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."global_rankings" TO "service_role";
GRANT SELECT ON TABLE "public"."global_rankings" TO "authenticated";



GRANT ALL ON TABLE "public"."supporter_status" TO "anon";
GRANT ALL ON TABLE "public"."supporter_status" TO "authenticated";
GRANT ALL ON TABLE "public"."supporter_status" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































