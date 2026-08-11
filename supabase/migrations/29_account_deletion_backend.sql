-- 29. Secure account deletion backend
--
-- Local-only until reviewed and applied deliberately.
--
-- Design:
-- - The client never sends a user_id to choose the account being deleted.
-- - The Edge Function validates the JWT, runs public.validate_account_deletion_request()
--   under the user's JWT, then deletes the Supabase Auth user with the Admin API.
-- - The real data cleanup is a BEFORE DELETE trigger on auth.users, so cleanup
--   and Auth deletion commit or roll back together.
-- - Shared completed challenge history is preserved only as anonymous metrics.
-- - Open/in-progress data is cancelled or removed; it is never marked completed.

CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON SCHEMA private FROM anon;
REVOKE ALL ON SCHEMA private FROM authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

-- A challenge can involve another player. If the creator deletes their account,
-- preserving the other player's completed/challenge history requires the
-- creator link to become NULL instead of cascading the whole challenge away.
ALTER TABLE public.challenges
  ALTER COLUMN creator_id DROP NOT NULL;

DO $$
DECLARE
    v_constraint RECORD;
BEGIN
    FOR v_constraint IN
        SELECT con.conname
        FROM pg_catalog.pg_constraint con
        JOIN pg_catalog.pg_attribute att
          ON att.attrelid = con.conrelid
         AND att.attnum = ANY(con.conkey)
        WHERE con.conrelid = 'public.challenges'::regclass
          AND con.contype = 'f'
          AND con.confrelid = 'auth.users'::regclass
          AND att.attname = 'creator_id'
    LOOP
        EXECUTE format('ALTER TABLE public.challenges DROP CONSTRAINT %I', v_constraint.conname);
    END LOOP;
END;
$$;

ALTER TABLE public.challenges
  ADD CONSTRAINT challenges_creator_id_fkey
  FOREIGN KEY (creator_id)
  REFERENCES auth.users(id)
  ON DELETE SET NULL;

-- A completed participant row contains copied result metrics used by the other
-- participant's challenge result screen. For completed shared challenges, keep
-- those metrics but remove the account identifier.
ALTER TABLE public.challenge_participants
  ALTER COLUMN user_id DROP NOT NULL;

DO $$
DECLARE
    v_constraint RECORD;
BEGIN
    FOR v_constraint IN
        SELECT con.conname
        FROM pg_catalog.pg_constraint con
        JOIN pg_catalog.pg_attribute att
          ON att.attrelid = con.conrelid
         AND att.attnum = ANY(con.conkey)
        WHERE con.conrelid = 'public.challenge_participants'::regclass
          AND con.contype = 'f'
          AND con.confrelid = 'auth.users'::regclass
          AND att.attname = 'user_id'
    LOOP
        EXECUTE format('ALTER TABLE public.challenge_participants DROP CONSTRAINT %I', v_constraint.conname);
    END LOOP;
END;
$$;

ALTER TABLE public.challenge_participants
  ADD CONSTRAINT challenge_participants_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE SET NULL;

-- Purchases and entitlements may be needed for refund, restore, support, audit,
-- and fraud-prevention flows. Detach them from the deleted account instead of
-- cascading them away. These blocks are guarded because older local/remote
-- schemas may not have every billing table yet.
DO $$
DECLARE
    v_constraint RECORD;
BEGIN
    IF to_regclass('private.supporter_entitlements') IS NOT NULL THEN
        ALTER TABLE private.supporter_entitlements
          ALTER COLUMN user_id DROP NOT NULL,
          ADD COLUMN IF NOT EXISTS deleted_user_hash TEXT,
          ADD COLUMN IF NOT EXISTS account_deleted_at TIMESTAMPTZ,
          ADD COLUMN IF NOT EXISTS revocation_reason TEXT,
          ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ,
          ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

        FOR v_constraint IN
            SELECT con.conname
            FROM pg_catalog.pg_constraint con
            JOIN pg_catalog.pg_attribute att
              ON att.attrelid = con.conrelid
             AND att.attnum = ANY(con.conkey)
            WHERE con.conrelid = 'private.supporter_entitlements'::regclass
              AND con.contype = 'f'
              AND con.confrelid = 'auth.users'::regclass
              AND att.attname = 'user_id'
        LOOP
            EXECUTE format('ALTER TABLE private.supporter_entitlements DROP CONSTRAINT %I', v_constraint.conname);
        END LOOP;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_constraint
            WHERE conrelid = 'private.supporter_entitlements'::regclass
              AND conname = 'supporter_entitlements_user_id_fkey'
        ) THEN
            ALTER TABLE private.supporter_entitlements
              ADD CONSTRAINT supporter_entitlements_user_id_fkey
              FOREIGN KEY (user_id)
              REFERENCES auth.users(id)
              ON DELETE SET NULL;
        END IF;
    END IF;

    IF to_regclass('private.purchases') IS NOT NULL THEN
        ALTER TABLE private.purchases
          ALTER COLUMN user_id DROP NOT NULL,
          ALTER COLUMN purchase_token DROP NOT NULL,
          ADD COLUMN IF NOT EXISTS deleted_user_hash TEXT,
          ADD COLUMN IF NOT EXISTS account_deleted_at TIMESTAMPTZ;

        FOR v_constraint IN
            SELECT con.conname
            FROM pg_catalog.pg_constraint con
            JOIN pg_catalog.pg_attribute att
              ON att.attrelid = con.conrelid
             AND att.attnum = ANY(con.conkey)
            WHERE con.conrelid = 'private.purchases'::regclass
              AND con.contype = 'f'
              AND con.confrelid = 'auth.users'::regclass
              AND att.attname = 'user_id'
        LOOP
            EXECUTE format('ALTER TABLE private.purchases DROP CONSTRAINT %I', v_constraint.conname);
        END LOOP;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_constraint
            WHERE conrelid = 'private.purchases'::regclass
              AND conname = 'purchases_user_id_fkey'
        ) THEN
            ALTER TABLE private.purchases
              ADD CONSTRAINT purchases_user_id_fkey
              FOREIGN KEY (user_id)
              REFERENCES auth.users(id)
              ON DELETE SET NULL;
        END IF;
    END IF;
END;
$$;

DROP FUNCTION IF EXISTS public.request_account_deletion();

CREATE OR REPLACE FUNCTION public.validate_account_deletion_request()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_request_id UUID := extensions.uuid_generate_v4();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- This preflight is intentionally non-mutating. The irreversible cleanup is
    -- performed by the auth.users delete trigger in the same transaction as the
    -- Admin API user deletion.
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('flag-game-delete-account:' || v_user_id::TEXT));

    RETURN jsonb_build_object(
        'ok', TRUE,
        'request_id', v_request_id,
        'requires_auth_delete', TRUE
    );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_account_deletion_request() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_account_deletion_request() FROM anon;
REVOKE ALL ON FUNCTION public.validate_account_deletion_request() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.validate_account_deletion_request() TO authenticated;

CREATE OR REPLACE FUNCTION private.handle_flag_game_auth_user_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID := OLD.id;
    v_deleted_results INTEGER := 0;
    v_deleted_ranked_sessions INTEGER := 0;
    v_deleted_challenge_sessions INTEGER := 0;
    v_deleted_base_sessions INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN OLD;
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('flag-game-delete-account:' || v_user_id::TEXT));

    -- Remove private identity links and detach billing records from the deleted
    -- account while retaining minimal purchase/support audit data.
    DELETE FROM private.player_identities
    WHERE user_id = v_user_id;

    IF to_regclass('private.supporter_entitlements') IS NOT NULL THEN
        UPDATE private.supporter_entitlements
        SET user_id = NULL,
            deleted_user_hash = encode(extensions.digest(v_user_id::TEXT, 'sha256'), 'hex'),
            account_deleted_at = COALESCE(account_deleted_at, NOW()),
            status = CASE
                WHEN status::TEXT IN ('active', 'pending') THEN 'revoked'
                ELSE status
            END,
            revoked_at = COALESCE(revoked_at, NOW()),
            revocation_reason = COALESCE(revocation_reason, 'account_deleted'),
            updated_at = NOW()
        WHERE user_id = v_user_id;
    END IF;

    IF to_regclass('private.purchases') IS NOT NULL THEN
        UPDATE private.purchases
        SET user_id = NULL,
            deleted_user_hash = encode(extensions.digest(v_user_id::TEXT, 'sha256'), 'hex'),
            account_deleted_at = COALESCE(account_deleted_at, NOW()),
            purchase_token = NULL,
            obfuscated_account_id = NULL,
            raw_response = NULL,
            updated_at = NOW()
        WHERE user_id = v_user_id;
    END IF;

    -- Private challenge sessions contain nonces/config snapshots and are not
    -- needed for public history after account deletion.
    DELETE FROM private.challenge_sessions
    WHERE user_id = v_user_id
       OR participant_id IN (
            SELECT id
            FROM public.challenge_participants
            WHERE user_id = v_user_id
       );
    GET DIAGNOSTICS v_deleted_challenge_sessions = ROW_COUNT;

    -- Break result/session references before deleting user-owned results.
    UPDATE private.ranked_game_sessions
    SET result_id = NULL
    WHERE user_id = v_user_id
       OR result_id IN (
            SELECT id
            FROM public.game_results
            WHERE user_id = v_user_id
       );

    UPDATE private.challenge_base_match_sessions
    SET result_id = NULL
    WHERE user_id = v_user_id
       OR result_id IN (
            SELECT id
            FROM public.game_results
            WHERE user_id = v_user_id
       );

    UPDATE public.challenge_participants
    SET result_id = NULL,
        event_id = NULL,
        updated_at = NOW()
    WHERE user_id = v_user_id;

    UPDATE public.game_results
    SET ranked_session_id = NULL
    WHERE user_id = v_user_id
       OR ranked_session_id IN (
            SELECT id
            FROM private.ranked_game_sessions
            WHERE user_id = v_user_id
       );

    -- Delete private sessions owned by the account. Challenge configs keep
    -- base_match_id nullable through the existing ON DELETE SET NULL FK.
    DELETE FROM private.challenge_base_match_sessions
    WHERE user_id = v_user_id;
    GET DIAGNOSTICS v_deleted_base_sessions = ROW_COUNT;

    DELETE FROM private.ranked_game_sessions
    WHERE user_id = v_user_id;
    GET DIAGNOSTICS v_deleted_ranked_sessions = ROW_COUNT;

    -- Delete all user-owned game results. Ranking rows disappear because
    -- public.global_rankings is derived from game_results joined to profiles.
    DELETE FROM public.game_results
    WHERE user_id = v_user_id;
    GET DIAGNOSTICS v_deleted_results = ROW_COUNT;

    -- Remove in-progress challenge participation. Do not invent completion,
    -- victory, defeat, or metrics for unfinished data.
    DELETE FROM public.challenge_participants
    WHERE user_id = v_user_id
      AND status::TEXT <> 'completed';

    -- Preserve completed shared challenge history as anonymous copied metrics.
    UPDATE public.challenge_participants
    SET user_id = NULL,
        result_id = NULL,
        event_id = NULL,
        updated_at = NOW()
    WHERE user_id = v_user_id
      AND status::TEXT = 'completed';

    -- Remove challenges that have no remaining participant account. This avoids
    -- keeping an ownerless challenge that only contains the deleted player's
    -- anonymized metrics.
    DELETE FROM public.challenges c
    WHERE c.creator_id = v_user_id
      AND NOT EXISTS (
          SELECT 1
          FROM public.challenge_participants cp
          WHERE cp.challenge_id = c.id
            AND cp.user_id IS NOT NULL
      );

    -- Preserve shared challenge shells but detach the deleted creator. Open
    -- ownerless challenges are cancelled so they cannot be accepted later.
    UPDATE public.challenges
    SET creator_id = NULL,
        status = CASE
            WHEN status::TEXT = 'open' THEN 'cancelled'
            ELSE status
        END,
        cancelled_at = CASE
            WHEN status::TEXT = 'open' THEN COALESCE(cancelled_at, NOW())
            ELSE cancelled_at
        END
    WHERE creator_id = v_user_id;

    -- Public profile and private auth-linked data are removed. The auth.users
    -- row itself will be deleted by the statement that fired this trigger.
    DELETE FROM public.profiles
    WHERE id = v_user_id;

    RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION private.handle_flag_game_auth_user_delete() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.handle_flag_game_auth_user_delete() FROM anon;
REVOKE ALL ON FUNCTION private.handle_flag_game_auth_user_delete() FROM authenticated;
GRANT EXECUTE ON FUNCTION private.handle_flag_game_auth_user_delete() TO service_role;

DROP TRIGGER IF EXISTS flag_game_before_auth_user_delete ON auth.users;

CREATE TRIGGER flag_game_before_auth_user_delete
BEFORE DELETE ON auth.users
FOR EACH ROW
EXECUTE FUNCTION private.handle_flag_game_auth_user_delete();

-- Make anonymized completed participants visible in challenge result payloads
-- without exposing a deleted user's UUID, nickname, country, email, playerId,
-- or any other account identifier. The app should translate deleted players
-- from is_deleted_player instead of relying on hard-coded database text.
CREATE OR REPLACE FUNCTION public.get_challenge_result(p_challenge_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_challenge RECORD;
    v_allowed BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    SELECT
        id,
        code,
        mode,
        variation,
        expires_at
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
                    'is_deleted_player', p.id IS NULL,
                    'nickname', CASE WHEN p.id IS NULL THEN NULL ELSE p.nickname END,
                    'country_code', CASE WHEN p.id IS NULL THEN NULL ELSE p.country_code END,
                    'avatar_key', CASE WHEN p.id IS NULL THEN NULL ELSE p.avatar_key END,
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
            LEFT JOIN public.profiles p ON p.id = cp.user_id
            WHERE cp.challenge_id = v_challenge.id
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_challenge_result(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_challenge_result(UUID) FROM anon;
REVOKE ALL ON FUNCTION public.get_challenge_result(UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_challenge_result(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
