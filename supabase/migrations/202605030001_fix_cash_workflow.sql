-- Fix cash/deposit/batch workflow:
--
-- 1. Create teller_pending_deposit_batches(p_school_id)
--    This function was referenced by teller_home_rows and teller_school_deposit_snapshot
--    (migration 011) but was never defined.  Without it the teller sees no pending
--    batches and the deposit form is broken.
--
-- 2. Fix principal_school_outstanding_deposit_detail()
--    Previously it summed ALL outstanding teacher_coll amounts (identical to
--    funds_on_site).  Per spec, "principal deposit due" must only reflect money
--    that has already been submitted to a dep_batch (status SUBMITTED / FLAGGED /
--    PARTIALLY_DEPOSITED) so it matches the teller's pending deposit view.
--
-- Business rules (from spec):
--   • Batch  = money submitted to a batch that has not yet been deposited
--   • Deposited = money fully processed by the teller (Posted events)
--   • Remain = money collected but not yet in any batch
--   • Principal "Deposit Due" = teller "Pending Deposit"
--             = expected_amount for active batches (SUBMITTED/FLAGGED/PARTIALLY_DEPOSITED)
--   • Money already DEPOSITED cannot move back to Batch or Remain
--   • CANCELLED batches are permanently blocked

-- ============================================================
-- 1. teller_pending_deposit_batches(p_school_id)
-- ============================================================
-- Returns one row per batch that is pending deposit for the given school.
-- Only returns batches with status SUBMITTED, FLAGGED, or PARTIALLY_DEPOSITED
-- that still have a remaining (undeposited) balance > 0.
--
-- Columns consumed by Dart (teller_repo.dart / fetchPendingDepositBatches):
--   batch_id, week_start, week_end,
--   deposit_due       (= expected_amount, the full batch total),
--   deposited_amount  (= sum of Posted applied_amount for this batch),
--   remaining_amount  (= deposit_due - deposited_amount)
--
-- Columns consumed by teller_home_rows / teller_school_deposit_snapshot (SQL):
--   deposit_due, deposited_amount, remaining_amount

CREATE OR REPLACE FUNCTION public.teller_pending_deposit_batches(p_school_id uuid)
RETURNS TABLE(
  batch_id         uuid,
  week_start       date,
  week_end         date,
  deposit_due      numeric,
  deposited_amount numeric,
  remaining_amount numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public' -- NOSONAR (search_path literal required by PostgreSQL DDL)
AS $$
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
    b.week_start,
    b.week_end,
    COALESCE(b.expected_amount,  0)::numeric                              AS deposit_due,
    COALESCE(p.posted_amount,    0)::numeric                              AS deposited_amount,
    GREATEST(
      COALESCE(b.expected_amount, 0) - COALESCE(p.posted_amount, 0), 0
    )::numeric                                                            AS remaining_amount
  FROM public.dep_batch b
  LEFT JOIN posted_by_batch p ON p.batch_id = b.batch_id
  WHERE b.school_id = p_school_id
    AND b.status IN ('SUBMITTED', 'FLAGGED', 'PARTIALLY_DEPOSITED') -- NOSONAR (S1192: batch status literals required in each function scope)
    AND COALESCE(b.expected_amount, 0) > COALESCE(p.posted_amount, 0)
  ORDER BY b.week_start DESC, b.batch_id;
$$;

GRANT EXECUTE ON FUNCTION public.teller_pending_deposit_batches(uuid) TO authenticated;

-- ============================================================
-- 2. principal_school_outstanding_deposit_detail()
-- ============================================================
-- Old version summed raw teacher_coll amounts (all undeposited collections),
-- which is the same number as principal_funds_on_site — not what the spec
-- describes as "Deposit Due".
--
-- New version sums dep_batch rows so that:
--   deposit_due  = total expected across all active batches for this school
--   deposited    = total already Posted against those batches
--   difference   = deposit_due - deposited  (= remaining to be deposited)
--
-- This aligns principal "Deposit Due" with teller "Pending Deposit"
-- (both derive from the same dep_batch expected_amount).

CREATE OR REPLACE FUNCTION public.principal_school_outstanding_deposit_detail()
RETURNS TABLE(
  school_id    uuid,
  deposit_due  numeric,
  deposited    numeric,
  difference   numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
SET row_security TO 'off'
AS $$
  WITH scope AS (
    SELECT
      public.is_admin()                        AS is_admin,
      public.current_principal_school_id()     AS principal_school_id
  ),
  posted_by_batch AS (
    SELECT eb.batch_id,
           SUM(eb.applied_amount) AS posted_amount
    FROM   public.cu_dep_event_batch eb
    JOIN   public.cu_dep_event       e  ON e.dep_event_id = eb.dep_event_id
                                       AND e.status = 'Posted'
    GROUP BY eb.batch_id
  ),
  batch_totals AS (
    SELECT
      b.school_id,
      COALESCE(SUM(b.expected_amount),   0)::numeric AS deposit_due,
      COALESCE(SUM(p.posted_amount),     0)::numeric AS deposited
    FROM public.dep_batch b
    CROSS JOIN scope s
    LEFT JOIN posted_by_batch p ON p.batch_id = b.batch_id
    WHERE b.status IN ('SUBMITTED', 'FLAGGED', 'PARTIALLY_DEPOSITED') -- NOSONAR (S1192: batch status literals required in each function scope)
      AND COALESCE(b.expected_amount, 0) > 0
      AND (
        s.is_admin
        OR (
          s.principal_school_id IS NOT NULL
          AND b.school_id = s.principal_school_id
        )
      )
    GROUP BY b.school_id
  )
  SELECT
    COALESCE(bt.school_id, s.principal_school_id)        AS school_id,
    COALESCE(bt.deposit_due, 0)::numeric(12,2)           AS deposit_due,
    COALESCE(bt.deposited,   0)::numeric(12,2)           AS deposited,
    GREATEST(
      COALESCE(bt.deposit_due, 0) - COALESCE(bt.deposited, 0),
      0
    )::numeric(12,2)                                     AS difference
  FROM scope s
  LEFT JOIN batch_totals bt
    ON bt.school_id = s.principal_school_id
  WHERE s.is_admin OR s.principal_school_id IS NOT NULL;
$$;

-- ============================================================
-- 3. principal_last_teacher_deposit_detail(p_teacher_id)
-- ============================================================
-- Returns the details of the most recent Posted deposit event for the school
-- (optionally filtered to a specific teacher).
-- Used by the Teacher Deposit Details card to show last-deposit figures:
--   deposit_due  = dep_batch expected_amount  (what was batched)
--   deposited    = cu_dep_event amount        (what the teller posted)
--   difference   = deposit_due - deposited    (discrepancy)

CREATE OR REPLACE FUNCTION public.principal_last_teacher_deposit_detail(
  p_teacher_id uuid DEFAULT NULL
)
RETURNS TABLE(
  teacher_id   uuid,
  teacher_name text,
  deposit_date timestamptz,
  deposit_due  numeric,
  deposited    numeric,
  difference   numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
SET row_security TO 'off'
AS $$
  WITH scope AS (
    SELECT
      public.is_admin()                    AS is_admin,
      public.current_principal_school_id() AS principal_school_id
  ),
  last_event AS (
    SELECT
      e.dep_event_id,
      e.school_id,
      e.deposited_by_teacher_id                                             AS teacher_id,
      TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) AS teacher_name,
      e.posted_at                                                           AS deposit_date,
      COALESCE(e.amount, 0)::numeric                                        AS deposited
    FROM public.cu_dep_event e
    JOIN public.teacher t ON t.teacher_id = e.deposited_by_teacher_id
    JOIN public."user"  u ON u.user_id    = t.user_id
    CROSS JOIN scope s
    WHERE e.status = 'Posted'
      AND (p_teacher_id IS NULL OR e.deposited_by_teacher_id = p_teacher_id)
      AND (
        s.is_admin
        OR (s.principal_school_id IS NOT NULL AND e.school_id = s.principal_school_id)
      )
    ORDER BY e.posted_at DESC
    LIMIT 1
  ),
  batch_for_event AS (
    SELECT
      eb.dep_event_id,
      COALESCE(b.expected_amount, 0)::numeric AS deposit_due
    FROM last_event le
    JOIN public.cu_dep_event_batch eb ON eb.dep_event_id = le.dep_event_id
    JOIN public.dep_batch           b  ON b.batch_id     = eb.batch_id
    ORDER BY b.week_start
    LIMIT 1
  )
  SELECT
    le.teacher_id,
    le.teacher_name,
    le.deposit_date,
    COALESCE(bf.deposit_due, le.deposited)::numeric(12,2)                  AS deposit_due,
    le.deposited::numeric(12,2)                                            AS deposited,
    (COALESCE(bf.deposit_due, le.deposited) - le.deposited)::numeric(12,2) AS difference
  FROM last_event le
  LEFT JOIN batch_for_event bf ON bf.dep_event_id = le.dep_event_id;
$$;

GRANT EXECUTE ON FUNCTION public.principal_last_teacher_deposit_detail(uuid) TO authenticated;

-- ============================================================
-- 4. Fix v_principal_reconcile_week column semantics
-- ============================================================
-- Money flows strictly ONE WAY:  Remain → Batch → Deposited
--   • Once money enters a batch it NEVER returns to Remain.
--   • Once money is Deposited it NEVER returns to Batch or Remain.
--   • Only CANCELLED batches release money back — those items reappear in
--     Remain so the principal can re-batch them.
--
-- Column semantics:
--   Batch    (batched_pending_amount)
--            = amount committed to any active batch minus what's been Posted
--            = what the teller still owes on existing batches
--   Deposited (deposited_amount)
--            = sum of Posted event items against this teacher's collections
--   Remain   (remaining_amount)
--            = collected − total_batched   (never put in any non-cancelled batch)
--            = money available for the principal to submit in a NEW batch
--   Total Deposit Amount (Dart: SUM remaining_amount)
--            = money the principal CAN submit right now
--
-- Statuses included in "batched" CTE:
--   OPEN, SUBMITTED, FLAGGED, PARTIALLY_DEPOSITED, DEPOSITED, NO_DEPOSIT_REQUIRED
--   Excluded: CANCELLED  ← returns items to Remain for re-batching
--
-- Example: collected=$65, all in one PARTIALLY_DEPOSITED batch, $25 Posted
--   batched_amount       = $65
--   deposited_amount     = $25
--   batched_pending_amount (Batch)  = $40  (teller still owes $40 on that batch)
--   remaining_amount       (Remain) = $0   (nothing to submit to a new batch)
--   Total Deposit Amount            = $0   (submit button disabled — correct)
--
-- The $40 outstanding shows on the principal home "School Deposit Details" card
-- as the Difference column (Deposit Due $65 − Deposited $25 = $40).

CREATE OR REPLACE VIEW public.v_principal_reconcile_week AS
WITH coll AS (
  SELECT
    tc.school_id,
    tc.teacher_id,
    tc.week_start,
    tc.week_end,
    tc.collection_id,
    (tc.amount)::numeric AS collected_amount
  FROM public.teacher_coll tc
  WHERE tc.amount > 0
),
batched AS (
  -- All non-cancelled batches. Money committed here NEVER returns to Remain.
  -- CANCELLED is excluded so those items reappear in Remain (re-batchable).
  SELECT
    tc.school_id,
    tc.teacher_id,
    tc.week_start,
    tc.week_end,
    SUM(di.amount)::numeric AS batched_amount
  FROM public.dep_item di
  JOIN public.teacher_coll tc ON tc.collection_id = di.collection_id
  JOIN public.dep_batch     b  ON b.batch_id       = di.batch_id
  WHERE b.status NOT IN ('CANCELLED')
  GROUP BY tc.school_id, tc.teacher_id, tc.week_start, tc.week_end
),
deposited AS (
  SELECT
    tc.school_id,
    tc.teacher_id,
    tc.week_start,
    tc.week_end,
    COALESCE(
      SUM(i.applied_amount) FILTER (WHERE e.status = 'Posted'),
      0
    )::numeric AS deposited_amount
  FROM public.teacher_coll tc
  LEFT JOIN public.cu_dep_event_item i ON i.collection_id = tc.collection_id
  LEFT JOIN public.cu_dep_event      e ON e.dep_event_id  = i.dep_event_id
  WHERE tc.amount > 0
  GROUP BY tc.school_id, tc.teacher_id, tc.week_start, tc.week_end
)
SELECT
  c.school_id,
  c.teacher_id,
  c.week_start,
  c.week_end,
  SUM(c.collected_amount)::numeric(12,2)                                     AS collected_amount,
  COALESCE(b.batched_amount, 0)::numeric(12,2)                               AS batched_amount,
  COALESCE(d.deposited_amount, 0)::numeric(12,2)                             AS deposited_amount,
  -- Batch column: what the teller still owes on existing batches
  GREATEST(
    COALESCE(b.batched_amount, 0) - COALESCE(d.deposited_amount, 0),
    0
  )::numeric(12,2)                                                            AS batched_pending_amount,
  -- Remain column: never committed to any batch; available for a new batch
  GREATEST(
    SUM(c.collected_amount) - COALESCE(b.batched_amount, 0),
    0
  )::numeric(12,2)                                                            AS remaining_amount,
  CASE
    WHEN COALESCE(d.deposited_amount, 0) >= SUM(c.collected_amount)
      THEN 'DEPOSITED'
    WHEN COALESCE(b.batched_amount, 0) > 0
     AND COALESCE(d.deposited_amount, 0) > 0
      THEN 'PARTIALLY_DEPOSITED' -- NOSONAR (S1192: batch status literals required in each function scope)
    WHEN COALESCE(b.batched_amount, 0) > 0
      THEN 'BATCHED'
    ELSE 'PENDING'
  END AS recon_status
FROM coll c
LEFT JOIN batched   b ON b.school_id  = c.school_id
                      AND b.teacher_id = c.teacher_id
                      AND b.week_start = c.week_start
                      AND b.week_end   = c.week_end
LEFT JOIN deposited d ON d.school_id  = c.school_id
                      AND d.teacher_id = c.teacher_id
                      AND d.week_start = c.week_start
                      AND d.week_end   = c.week_end
GROUP BY c.school_id, c.teacher_id, c.week_start, c.week_end,
         b.batched_amount, d.deposited_amount;
