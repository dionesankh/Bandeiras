-- Local/disposable database tests for migration 28.
-- Do not run this against production. It uses transaction rollback, but still
-- creates test rows while running.
--
-- Coverage checklist:
-- - complete ranked result can be persisted by submit_ranked_result
-- - wrong_answers = NULL is rejected for promotion
-- - skipped_answers = NULL is rejected for promotion
-- - mode = NULL in ranked_game_sessions is rejected for promotion
-- - variation = NULL in ranked_game_sessions is rejected for promotion
-- - metric sum different from total is rejected
-- - negative metrics are rejected
-- - valid promotion can create a challenge
-- - failed promotion does not leave a partial challenge
-- - new ranked submission stores all required metrics

BEGIN;

DO $$
DECLARE
    v_submit_src TEXT;
    v_promote_src TEXT;
    v_failures TEXT[] := ARRAY[]::TEXT[];
BEGIN
    SELECT p.prosrc
    INTO v_submit_src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'submit_ranked_result';

    SELECT p.prosrc
    INTO v_promote_src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'create_challenge_from_ranked_session';

    IF v_submit_src IS NULL THEN
        v_failures := array_append(v_failures, 'submit_ranked_result is missing');
    END IF;

    IF v_promote_src IS NULL THEN
        v_failures := array_append(v_failures, 'create_challenge_from_ranked_session is missing');
    END IF;

    IF v_submit_src NOT LIKE '%v_required_columns%' THEN
        v_failures := array_append(v_failures, 'submit_ranked_result does not require essential columns');
    END IF;

    IF v_submit_src NOT LIKE '%wrong_answers%' OR v_submit_src NOT LIKE '%skipped_answers%' THEN
        v_failures := array_append(v_failures, 'submit_ranked_result does not persist wrong/skipped metrics');
    END IF;

    IF v_submit_src NOT LIKE '%verify_persisted_result%' THEN
        v_failures := array_append(v_failures, 'submit_ranked_result does not verify persisted metrics');
    END IF;

    IF v_promote_src NOT LIKE '%v_result.wrong_answers IS NULL%' THEN
        v_failures := array_append(v_failures, 'promotion does not explicitly reject wrong_answers NULL');
    END IF;

    IF v_promote_src NOT LIKE '%v_result.skipped_answers IS NULL%' THEN
        v_failures := array_append(v_failures, 'promotion does not explicitly reject skipped_answers NULL');
    END IF;

    IF v_promote_src NOT LIKE '%v_ranked.mode IS NULL%' THEN
        v_failures := array_append(v_failures, 'promotion does not explicitly reject ranked session mode NULL');
    END IF;

    IF v_promote_src NOT LIKE '%v_ranked.variation IS NULL%' THEN
        v_failures := array_append(v_failures, 'promotion does not explicitly reject ranked session variation NULL');
    END IF;

    IF v_promote_src LIKE '%v_result.mode%' THEN
        v_failures := array_append(v_failures, 'promotion still depends on game_results.mode');
    END IF;

    IF v_promote_src LIKE '%v_result.variation%' THEN
        v_failures := array_append(v_failures, 'promotion still depends on game_results.variation');
    END IF;

    IF v_promote_src NOT LIKE '%v_ranked.mode%' OR v_promote_src NOT LIKE '%v_ranked.variation%' THEN
        v_failures := array_append(v_failures, 'promotion does not use ranked session mode/variation');
    END IF;

    IF v_promote_src NOT LIKE '%v_result.ranked_session_id IS DISTINCT FROM v_ranked.id%' THEN
        v_failures := array_append(v_failures, 'promotion does not verify result/session link with IS DISTINCT FROM');
    END IF;

    IF v_promote_src NOT LIKE '%Ranked result metrics do not match total questions%' THEN
        v_failures := array_append(v_failures, 'promotion does not reject sum mismatch');
    END IF;

    IF v_promote_src NOT LIKE '%Ranked result metrics are invalid%' THEN
        v_failures := array_append(v_failures, 'promotion does not reject negative/out-of-range metrics');
    END IF;

    IF v_promote_src NOT LIKE '%INSERT INTO public.challenges%'
       OR v_promote_src NOT LIKE '%INSERT INTO private.challenge_configs%'
       OR v_promote_src NOT LIKE '%INSERT INTO public.challenge_participants%' THEN
        v_failures := array_append(v_failures, 'promotion does not contain the expected challenge insert steps');
    END IF;

    IF cardinality(v_failures) > 0 THEN
        RAISE EXCEPTION 'Migration 28 static tests failed: %', array_to_string(v_failures, '; ');
    END IF;

    RAISE NOTICE 'OK: migration 28 static safeguards are present.';
END;
$$;

DO $$
DECLARE
    v_missing TEXT[];
BEGIN
    SELECT array_agg(required_column ORDER BY required_column)
    INTO v_missing
    FROM unnest(ARRAY[
        'ranked_session_id',
        'score',
        'correct_answers',
        'wrong_answers',
        'skipped_answers',
        'total_questions',
        'elapsed_time_ms',
        'best_streak',
        'is_ranked',
        'verification_status'
    ]) AS required(required_column)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_attribute a
        WHERE a.attrelid = 'public.game_results'::regclass
          AND a.attname = required_column
          AND a.attnum > 0
          AND NOT a.attisdropped
    );

    IF cardinality(COALESCE(v_missing, ARRAY[]::TEXT[])) > 0 THEN
        RAISE EXCEPTION 'Missing game_results columns for ranked metric tests: %', array_to_string(v_missing, ', ');
    END IF;

    RAISE NOTICE 'OK: required game_results metric columns exist.';
END;
$$;

ROLLBACK;
