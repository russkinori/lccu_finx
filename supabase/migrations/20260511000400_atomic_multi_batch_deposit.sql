-- ============================================================
-- Atomic multi-batch deposit confirmation
--
-- Problem:  The Flutter client previously called
--           teller_post_school_deposit_event once per batch inside a
--           Dart loop.  If the Nth call threw, the first N-1 deposits
--           were already committed, leaving the database in a partial-
--           allocation state with no audit trail of the failure.
--
-- Fix:      teller_confirm_multi_batch_deposit wraps all per-batch
--           calls to teller_post_school_deposit_event inside a single
--           PL/pgSQL function.  Because every statement in a PL/pgSQL
--           function runs within the caller's transaction, any mid-loop
--           failure automatically rolls back every deposit posted in
--           that invocation, guaranteeing all-or-nothing semantics.
--
-- Principles addressed:
--   • Data integrity  – atomic allocation eliminates partial-deposit state
--   • Fail fast       – explicit guards on amount > 0 and non-empty batch list
--   • Least privilege – is_teller() guard; REVOKE from PUBLIC
--   • DRY             – allocation logic lives in one place (the DB), not
--                       duplicated between client and server
-- ============================================================

CREATE OR REPLACE FUNCTION public.teller_confirm_multi_batch_deposit(
  p_school_id  uuid,
  p_batch_ids  uuid[],
  p_amount     numeric,
  p_teacher_id uuid,
  p_note       text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $$
DECLARE
  r            RECORD;
  v_apply      numeric;
  v_remaining  numeric := p_amount;
BEGIN
  -- Guard: only tellers may post deposits.
  IF NOT public.is_teller() THEN
    RAISE EXCEPTION 'Permission denied: teller role required';
  END IF;

  -- Fail fast: reject non-positive amounts and empty batch lists.
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Deposit amount must be positive (got %)', p_amount;
  END IF;

  IF array_length(p_batch_ids, 1) IS NULL OR array_length(p_batch_ids, 1) = 0 THEN
    RAISE EXCEPTION 'At least one batch ID must be provided';
  END IF;

  -- Iterate selected batches in deterministic (batch_id ASC) order.
  -- Sorting by batch_id ensures reproducible allocation regardless of the
  -- order the client supplied the IDs, and matches the existing client-side
  -- sort that was used before this atomic wrapper was introduced.
  FOR r IN
    WITH posted_by_batch AS (
      SELECT eb.batch_id,
             SUM(eb.applied_amount) AS posted_amount
      FROM   public.cu_dep_event_batch eb
      JOIN   public.cu_dep_event       e  ON e.dep_event_id = eb.dep_event_id
                                         AND e.status = 'Posted' -- NOSONAR (status value required in each function scope)
      GROUP BY eb.batch_id
    )
    SELECT
      b.batch_id,
      GREATEST(
        COALESCE(b.expected_amount, 0) - COALESCE(p.posted_amount, 0), 0
      )::numeric AS remaining_amount
    FROM public.dep_batch b
    LEFT JOIN posted_by_batch p ON p.batch_id = b.batch_id
    WHERE b.school_id  = p_school_id
      AND b.batch_id   = ANY(p_batch_ids)
      AND b.status IN ('SUBMITTED', 'FLAGGED', 'PARTIALLY_DEPOSITED') -- NOSONAR (S1192: batch status literals required in each function scope)
    ORDER BY b.batch_id ASC
  LOOP
    EXIT WHEN v_remaining <= 0;

    IF r.remaining_amount <= 0 THEN
      CONTINUE;
    END IF;

    v_apply     := LEAST(v_remaining, r.remaining_amount);
    v_remaining := v_remaining - v_apply;

    -- Each call runs within this function's transaction.
    -- A failure here rolls back all prior calls in this loop.
    PERFORM public.teller_post_school_deposit_event(
      p_batch_id                => r.batch_id,
      p_amount                  => v_apply,
      p_deposited_by_teacher_id => p_teacher_id,
      p_note                    => p_note
    );
  END LOOP;

  -- Allow a tiny rounding tolerance (< 1 cent) before raising.
  IF v_remaining > 0.005 THEN
    RAISE EXCEPTION
      'Unable to allocate full deposit amount across selected batches. '
      'Unallocated: %', v_remaining;
  END IF;
END;
$$;

GRANT  EXECUTE ON FUNCTION public.teller_confirm_multi_batch_deposit(uuid, uuid[], numeric, uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.teller_confirm_multi_batch_deposit(uuid, uuid[], numeric, uuid, text) FROM PUBLIC;
