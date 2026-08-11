-- 25. Remote history alignment and security hardening
--
-- Local-only until reviewed and applied deliberately.
-- Purpose:
-- - align the remote schema that already contains objects from migrations 23/24;
-- - tighten grants that were confirmed too broad in the remote audit;
-- - fix submit_ranked_result expiration handling without relying on an UPDATE
--   that would be rolled back by a following RAISE EXCEPTION;
-- - restore profile RPCs used by the frontend when absent.
--
-- This migration is intentionally idempotent and does not delete user data.

CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON SCHEMA private FROM anon;
REVOKE ALL ON SCHEMA private FROM authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

REVOKE CREATE ON SCHEMA public FROM anon;
REVOKE CREATE ON SCHEMA public FROM authenticated;

-- Keep migration 24 columns present on remotes where 24 was only partially applied.
ALTER TABLE IF EXISTS private.challenge_configs
  ADD COLUMN IF NOT EXISTS sequence_hash TEXT,
  ADD COLUMN IF NOT EXISTS base_match_id UUID;

DO $$
BEGIN
    IF to_regclass('private.challenge_base_match_sessions') IS NOT NULL
       AND to_regclass('private.challenge_configs') IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM pg_constraint
           WHERE conname = 'challenge_configs_base_match_id_fkey'
             AND conrelid = 'private.challenge_configs'::regclass
       ) THEN
        ALTER TABLE private.challenge_configs
          ADD CONSTRAINT challenge_configs_base_match_id_fkey
          FOREIGN KEY (base_match_id)
          REFERENCES private.challenge_base_match_sessions(id)
          ON DELETE SET NULL;
    END IF;
END;
$$;

-- Direct table/view grants: the frontend reads and updates only the
-- authenticated user's own profile. Public profile reads go through
-- get_public_profile instead of direct table access.
REVOKE ALL ON TABLE public.profiles FROM PUBLIC;
REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.profiles FROM authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT UPDATE (nickname, country_code, avatar_key, privacy_settings)
  ON TABLE public.profiles TO authenticated;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público" ON public.profiles;
DROP POLICY IF EXISTS "Update próprio" ON public.profiles;
DROP POLICY IF EXISTS "Perfis visíveis para todos" ON public.profiles;
DROP POLICY IF EXISTS "Dono edita campos permitidos" ON public.profiles;
DROP POLICY IF EXISTS profiles_select_public ON public.profiles;
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;

CREATE POLICY profiles_select_own
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY profiles_update_own
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

REVOKE ALL ON TABLE public.supporter_status FROM PUBLIC;
REVOKE ALL ON TABLE public.supporter_status FROM anon;
REVOKE ALL ON TABLE public.supporter_status FROM authenticated;

REVOKE ALL ON TABLE public.global_rankings FROM PUBLIC;
REVOKE ALL ON TABLE public.global_rankings FROM anon;
REVOKE ALL ON TABLE public.global_rankings FROM authenticated;
GRANT SELECT ON TABLE public.global_rankings TO authenticated;

REVOKE ALL ON TABLE public.challenges FROM PUBLIC;
REVOKE ALL ON TABLE public.challenges FROM anon;
REVOKE ALL ON TABLE public.challenges FROM authenticated;
REVOKE ALL ON TABLE public.challenge_participants FROM PUBLIC;
REVOKE ALL ON TABLE public.challenge_participants FROM anon;
REVOKE ALL ON TABLE public.challenge_participants FROM authenticated;
REVOKE ALL ON TABLE public.game_results FROM PUBLIC;
REVOKE ALL ON TABLE public.game_results FROM anon;
REVOKE ALL ON TABLE public.game_results FROM authenticated;

REVOKE ALL ON TABLE private.supporter_entitlements FROM PUBLIC;
REVOKE ALL ON TABLE private.supporter_entitlements FROM anon;
REVOKE ALL ON TABLE private.supporter_entitlements FROM authenticated;
REVOKE ALL ON TABLE private.ranked_game_sessions FROM PUBLIC;
REVOKE ALL ON TABLE private.ranked_game_sessions FROM anon;
REVOKE ALL ON TABLE private.ranked_game_sessions FROM authenticated;
REVOKE ALL ON TABLE private.challenge_configs FROM PUBLIC;
REVOKE ALL ON TABLE private.challenge_configs FROM anon;
REVOKE ALL ON TABLE private.challenge_configs FROM authenticated;
REVOKE ALL ON TABLE private.challenge_sessions FROM PUBLIC;
REVOKE ALL ON TABLE private.challenge_sessions FROM anon;
REVOKE ALL ON TABLE private.challenge_sessions FROM authenticated;
REVOKE ALL ON TABLE private.challenge_base_match_sessions FROM PUBLIC;
REVOKE ALL ON TABLE private.challenge_base_match_sessions FROM anon;
REVOKE ALL ON TABLE private.challenge_base_match_sessions FROM authenticated;

ALTER TABLE IF EXISTS public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.game_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS private.supporter_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS private.ranked_game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS private.challenge_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS private.challenge_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS private.challenge_base_match_sessions ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.submit_ranked_result(
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
SET search_path = private, public, auth
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_nonce_hash TEXT;
    v_session_json JSONB;
    v_session_id UUID;
    v_result_id UUID;
    v_calculated_score INTEGER;
    v_calculated_accuracy NUMERIC;
    v_event_id TEXT;
    v_payload JSONB;
    v_columns TEXT;
    v_values TEXT;
    v_insert_sql TEXT;
    v_stage TEXT := 'start';
    v_error_state TEXT;
    v_error_message TEXT;
BEGIN
    v_stage := 'auth';
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    v_event_id := NULLIF(trim(p_event_id), '');
    IF v_event_id IS NULL THEN
        RAISE EXCEPTION 'Missing event_id';
    END IF;

    v_stage := 'validate_numbers';
    IF p_total IS NULL
       OR p_total <= 0
       OR p_correct IS NULL
       OR p_wrong IS NULL
       OR p_skipped IS NULL
       OR p_correct < 0
       OR p_wrong < 0
       OR p_skipped < 0
       OR (p_correct + p_wrong + p_skipped) <> p_total
       OR p_correct > p_total THEN
        RAISE EXCEPTION 'Inconsistent result numbers';
    END IF;

    IF p_time_ms IS NULL OR p_time_ms < 0 THEN
        RAISE EXCEPTION 'Invalid elapsed time';
    END IF;

    IF p_streak IS NULL OR p_streak < 0 OR p_streak > p_total THEN
        RAISE EXCEPTION 'Invalid streak';
    END IF;

    v_stage := 'hash_nonce';
    v_nonce_hash := encode(extensions.digest(p_nonce, 'sha256'), 'hex');

    v_stage := 'load_session';
    SELECT to_jsonb(s)
    INTO v_session_json
    FROM private.ranked_game_sessions s
    WHERE s.session_nonce_hash = v_nonce_hash
      AND s.user_id = v_user_id
      AND s.status = 'created'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid session or already used';
    END IF;

    v_session_id := (v_session_json->>'id')::UUID;

    v_stage := 'check_expiration';
    IF (v_session_json->>'expires_at')::TIMESTAMPTZ < NOW() THEN
        -- The expiration is authoritative by timestamp. Do not update status
        -- here and then raise, because the exception rolls back the update.
        RAISE EXCEPTION 'Session expired';
    END IF;

    v_stage := 'calculate_score';
    v_calculated_score := p_correct;
    v_calculated_accuracy := ROUND((p_correct::NUMERIC / p_total::NUMERIC) * 100, 2);

    v_stage := 'build_payload';
    v_payload := jsonb_build_object(
        'event_id', v_event_id,
        'user_id', v_user_id,
        'ranked_session_id', v_session_id,
        'mode', v_session_json->>'mode',
        'variation', v_session_json->>'variation',
        'rules_version', COALESCE(NULLIF(v_session_json->>'rules_version', '')::INTEGER, 1),
        'score', v_calculated_score,
        'correct_answers', p_correct,
        'wrong_answers', p_wrong,
        'skipped_answers', p_skipped,
        'total_questions', p_total,
        'accuracy', v_calculated_accuracy,
        'elapsed_time_ms', p_time_ms,
        'best_streak', p_streak,
        'hearts_used', FALSE,
        'is_ranked', TRUE,
        'verification_status', 'verified',
        'created_at', NOW(),
        'received_at', NOW()
    );

    v_stage := 'resolve_game_results_columns';
    SELECT
        string_agg(format('%I', a.attname), ', ' ORDER BY a.attnum),
        string_agg(
            format('($1->>%L)::%s', a.attname, format_type(a.atttypid, a.atttypmod)),
            ', ' ORDER BY a.attnum
        )
    INTO v_columns, v_values
    FROM pg_attribute a
    WHERE a.attrelid = 'public.game_results'::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND a.attname IN (
          'event_id',
          'user_id',
          'ranked_session_id',
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
          'created_at',
          'received_at'
      );

    IF v_columns IS NULL OR v_values IS NULL THEN
        RAISE EXCEPTION 'No compatible columns found in public.game_results';
    END IF;

    v_stage := 'insert_game_results';
    v_insert_sql := format(
        'INSERT INTO public.game_results (%s) VALUES (%s) RETURNING id',
        v_columns,
        v_values
    );

    EXECUTE v_insert_sql USING v_payload INTO v_result_id;

    v_stage := 'complete_session_status';
    UPDATE private.ranked_game_sessions
    SET status = 'completed'
    WHERE id = v_session_id;

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.ranked_game_sessions'::regclass
          AND attname = 'completed_at'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_stage := 'complete_session_completed_at';
        EXECUTE 'UPDATE private.ranked_game_sessions SET completed_at = NOW() WHERE id = $1'
        USING v_session_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'private.ranked_game_sessions'::regclass
          AND attname = 'result_id'
          AND attnum > 0
          AND NOT attisdropped
    ) THEN
        v_stage := 'complete_session_result_id';
        EXECUTE 'UPDATE private.ranked_game_sessions SET result_id = $1 WHERE id = $2'
        USING v_result_id, v_session_id;
    END IF;

    RETURN jsonb_build_object('result_id', v_result_id, 'status', 'verified');
EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
        v_error_state = RETURNED_SQLSTATE,
        v_error_message = MESSAGE_TEXT;

    RAISE EXCEPTION USING
        ERRCODE = v_error_state,
        MESSAGE = format(
            'submit_ranked_result failed at %s [%s]: %s',
            v_stage,
            v_error_state,
            v_error_message
        ),
        DETAIL = NULL,
        HINT = 'Check required columns, constraints, enum values, and session status.';
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_profile(p_target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_profile RECORD;
BEGIN
    SELECT
        p.id,
        p.nickname,
        p.country_code,
        p.avatar_key,
        p.created_at,
        public.check_is_supporter(p.id) AS is_supporter
    INTO v_profile
    FROM public.profiles p
    WHERE p.id = p_target_user_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    RETURN jsonb_build_object(
        'id', v_profile.id,
        'nickname', v_profile.nickname,
        'country_code', v_profile.country_code,
        'avatar_key', v_profile.avatar_key,
        'is_supporter', v_profile.is_supporter,
        'created_at', v_profile.created_at
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_supporter_profile_details(p_target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, auth
AS $$
DECLARE
    v_viewer_id UUID := auth.uid();
    v_is_viewer_supporter BOOLEAN;
    v_privacy JSONB;
BEGIN
    IF v_viewer_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT public.check_is_supporter(v_viewer_id)
    INTO v_is_viewer_supporter;

    SELECT privacy_settings
    INTO v_privacy
    FROM public.profiles
    WHERE id = p_target_user_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF v_viewer_id <> p_target_user_id
       AND NOT COALESCE(v_is_viewer_supporter, FALSE) THEN
        RAISE EXCEPTION 'Detailed stats are exclusive to supporters';
    END IF;

    IF v_viewer_id <> p_target_user_id
       AND NOT COALESCE((v_privacy->>'show_detailed_stats')::BOOLEAN, FALSE) THEN
        RAISE EXCEPTION 'This user has kept their statistics private';
    END IF;

    RETURN (
        SELECT jsonb_build_object(
            'total_games', COUNT(*),
            'total_score', COALESCE(SUM(score), 0),
            'avg_accuracy', COALESCE(ROUND(AVG(accuracy), 2), 0),
            'best_score', COALESCE(MAX(score), 0)
        )
        FROM public.game_results
        WHERE user_id = p_target_user_id
    );
END;
$$;

-- App RPC grants. Revocation is dynamic so partially present schemas do not fail.
DO $$
DECLARE
    v_signature TEXT;
    v_app_functions TEXT[] := ARRAY[
        'public.ensure_profile(text,text)',
        'public.create_ranked_session(text,text)',
        'public.submit_ranked_result(text,text,integer,integer,integer,integer,integer,integer)',
        'public.check_is_supporter(uuid)',
        'public.get_public_profile(uuid)',
        'public.get_supporter_profile_details(uuid)',
        'public.normalize_challenge_code(text)',
        'public.create_challenge(text,text,text)',
        'public.get_daily_challenge_quota()',
        'public.get_challenge_preview(text)',
        'public.accept_challenge(text)',
        'public.start_challenge_session(text)',
        'public.submit_challenge_result(text,text,integer,integer,integer,integer,integer,integer)',
        'public.cancel_challenge(text)',
        'public.get_challenge_result(uuid)',
        'public.list_my_challenges(text,integer,integer)',
        'public.start_challenge_base_match(text,text)',
        'public.create_challenge_from_completed_match(text,text,integer,integer,integer,integer,integer,integer,text)'
    ];
    v_private_functions TEXT[] := ARRAY[
        'private.generate_challenge_code()',
        'private.challenge_question_count(text,text)',
        'private.challenge_public_status(uuid)',
        'private.challenge_winner_payload(uuid)',
        'private.challenge_country_catalog()',
        'private.challenge_build_question_codes(text,text,text)',
        'private.challenge_sequence_hash(text,text,jsonb,integer,text)',
        'private.challenge_validate_question_codes(text,text,jsonb)'
    ];
BEGIN
    FOREACH v_signature IN ARRAY v_app_functions LOOP
        IF to_regprocedure(v_signature) IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', v_signature);
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', v_signature);
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM authenticated', v_signature);
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', v_signature);
        END IF;
    END LOOP;

    FOREACH v_signature IN ARRAY v_private_functions LOOP
        IF to_regprocedure(v_signature) IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', v_signature);
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', v_signature);
            EXECUTE format('REVOKE ALL ON FUNCTION %s FROM authenticated', v_signature);
        END IF;
    END LOOP;
END;
$$;

NOTIFY pgrst, 'reload schema';
