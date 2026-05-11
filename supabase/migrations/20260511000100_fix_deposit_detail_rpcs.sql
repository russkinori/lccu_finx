-- ============================================================
-- Fix deposit detail RPCs
--
-- 1. teller_pending_deposit_batches(p_school_id)
--    Add dep_batch.note to the returned columns so tellers can
--    see the principal's submission note alongside each batch.
--
-- 2. principal_school_outstanding_deposit_detail()
--    Include DEPOSITED batches from the current ISO week in the
--    school card totals.  Previously DEPOSITED batches were
--    excluded, so the card under-counted deposit_due by the
--    amount of any fully-deposited batch from the same week.
--
--    New rule:
--      • Always include SUBMITTED / FLAGGED / PARTIALLY_DEPOSITED
--        (any week, so carry-overs are captured)
--      • Also include DEPOSITED batches whose week_start equals
--        the current ISO week Monday
--    → deposit_due  = cumulative batch total for the week
--    → deposited    = SUM of all Posted applied_amount for those batches
--    → difference   = deposit_due − deposited
--
-- 3. principal_last_teacher_deposit_detail(p_teacher_id)
--    • When p_teacher_id IS NULL (All Teachers view):
--        Find the most recently submitted dep_batch for the
--        current ISO week.  This shows the pending batch even
--        before the teller has acted:
--          deposit_due  = batch.expected_amount
--          deposited    = SUM posted applied_amount for that batch (0 if none)
--          difference   = deposit_due − deposited if deposited > 0, else 0
--    • When p_teacher_id IS NOT NULL (specific teacher):
--        Keep existing behaviour — find the most recent Posted
--        cu_dep_event for that teacher; show batch expected_amount
--        vs event amount.
-- ============================================================

-- ============================================================
-- 1. teller_pending_deposit_batches — add note column
--    Must DROP before recreating because the return type changes.
-- ============================================================
DROP FUNCTION IF EXISTS public.teller_pending_deposit_batches(uuid);

CREATE OR REPLACE FUNCTION public.teller_pending_deposit_batches(p_school_id uuid)
RETURNS TABLE(
  batch_id         uuid,
  week_start       date,
  week_end         date,
  deposit_due      numeric,
  deposited_amount numeric,
  remaining_amount numeric,
  note             text
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
    )::numeric                                                            AS remaining_amount,
    COALESCE(b.note, '')                                                  AS note
  FROM public.dep_batch b
  LEFT JOIN posted_by_batch p ON p.batch_id = b.batch_id
  WHERE b.school_id = p_school_id
    AND b.status IN ('SUBMITTED', 'FLAGGED', 'PARTIALLY_DEPOSITED') -- NOSONAR (S1192: batch status literals required in each function scope)
    AND COALESCE(b.expected_amount, 0) > COALESCE(p.posted_amount, 0)
  ORDER BY b.week_start DESC, b.batch_id;
$$;

GRANT EXECUTE ON FUNCTION public.teller_pending_deposit_batches(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.teller_pending_deposit_batches(uuid) FROM PUBLIC;

-- ============================================================
-- 2. principal_school_outstanding_deposit_detail — add current-week
--    DEPOSITED batches so the card reflects the full weekly total.
-- ============================================================
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
                                       AND e.status = 'Posted' -- NOSONAR (status value required in each function scope)
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
    WHERE (
        -- All pending batches from any week (captures carry-overs)
        b.status IN ('SUBMITTED', 'FLAGGED', 'PARTIALLY_DEPOSITED') -- NOSONAR (S1192: batch status literals required in each function scope)
        OR
        -- Fully-deposited batches from the current ISO week so the
        -- school card shows the complete weekly cumulative total.
        (b.status = 'DEPOSITED' AND b.week_start = date_trunc('week', CURRENT_DATE)::date) -- NOSONAR (S1192: batch status literals required in each function scope)
      )
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

GRANT EXECUTE ON FUNCTION public.principal_school_outstanding_deposit_detail() TO authenticated;

-- ============================================================
-- 3. principal_last_teacher_deposit_detail — show most-recent
--    batch when no teacher filter (ALL view).
-- ============================================================
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

  -- ──────────────────────────────────────────────────────────
  -- PATH A: specific teacher requested
  -- Find the most recent Posted cu_dep_event for that teacher
  -- and show the associated batch expected_amount as deposit_due.
  -- ──────────────────────────────────────────────────────────
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
    WHERE e.status = 'Posted' -- NOSONAR (status value required in each function scope)
      AND p_teacher_id IS NOT NULL
      AND e.deposited_by_teacher_id = p_teacher_id
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
  ),

  -- ──────────────────────────────────────────────────────────
  -- PATH B: all teachers (p_teacher_id IS NULL)
  -- Find the most recently submitted dep_batch for the current
  -- ISO week.  Show its expected_amount as deposit_due and the
  -- sum of any Posted applied_amounts as deposited (0 if the
  -- teller hasn't acted yet).  difference is 0 when there are
  -- no Posted events (pending state); otherwise deposit_due - deposited.
  -- ──────────────────────────────────────────────────────────
  recent_batch AS (
    SELECT
      b.batch_id,
      b.school_id,
      COALESCE(b.expected_amount, 0)::numeric                        AS deposit_due,
      COALESCE(b.submitted_at, b.created_at)                        AS sort_time
    FROM public.dep_batch b
    CROSS JOIN scope s
    WHERE p_teacher_id IS NULL
      AND b.week_start = date_trunc('week', CURRENT_DATE)::date
      AND b.status NOT IN ('CANCELLED', 'NO_DEPOSIT_REQUIRED') -- NOSONAR (S1192: batch status literals required in each function scope)
      AND COALESCE(b.expected_amount, 0) > 0
      AND (
        s.is_admin
        OR (s.principal_school_id IS NOT NULL AND b.school_id = s.principal_school_id)
      )
    ORDER BY sort_time DESC
    LIMIT 1
  ),
  applied_to_recent AS (
    SELECT COALESCE(SUM(eb.applied_amount), 0)::numeric AS applied_total
    FROM recent_batch rb
    JOIN public.cu_dep_event_batch eb ON eb.batch_id    = rb.batch_id
    JOIN public.cu_dep_event       e  ON e.dep_event_id = eb.dep_event_id
                                     AND e.status = 'Posted' -- NOSONAR (status value required in each function scope)
  ),
  -- Last teacher who deposited for this batch (display only — may be NULL
  -- if the teller hasn't acted yet for this batch).
  last_depositor AS (
    SELECT
      e.deposited_by_teacher_id                                             AS teacher_id,
      TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) AS teacher_name,
      e.posted_at                                                           AS deposit_date
    FROM recent_batch rb
    JOIN public.cu_dep_event_batch eb ON eb.batch_id    = rb.batch_id
    JOIN public.cu_dep_event       e  ON e.dep_event_id = eb.dep_event_id
                                     AND e.status = 'Posted' -- NOSONAR (status value required in each function scope)
    JOIN public.teacher            t  ON t.teacher_id   = e.deposited_by_teacher_id
    JOIN public."user"             u  ON u.user_id       = t.user_id
    ORDER BY e.posted_at DESC
    LIMIT 1
  )

  -- ── PATH A result ─────────────────────────────────────────
  SELECT
    le.teacher_id,
    le.teacher_name,
    le.deposit_date,
    COALESCE(bf.deposit_due, le.deposited)::numeric(12,2)                   AS deposit_due,
    le.deposited::numeric(12,2)                                             AS deposited,
    (COALESCE(bf.deposit_due, le.deposited) - le.deposited)::numeric(12,2) AS difference
  FROM last_event le
  LEFT JOIN batch_for_event bf ON bf.dep_event_id = le.dep_event_id

  UNION ALL

  -- ── PATH B result ─────────────────────────────────────────
  SELECT
    ld.teacher_id,
    ld.teacher_name,
    ld.deposit_date,
    rb.deposit_due::numeric(12,2)                                          AS deposit_due,
    ar.applied_total::numeric(12,2)                                        AS deposited,
    CASE
      WHEN ar.applied_total > 0
        THEN (rb.deposit_due - ar.applied_total)::numeric(12,2)
      ELSE 0::numeric(12,2)
    END                                                                    AS difference
  FROM recent_batch rb
  CROSS JOIN applied_to_recent ar
  LEFT JOIN last_depositor ld ON true;
$$;

GRANT EXECUTE ON FUNCTION public.principal_last_teacher_deposit_detail(uuid) TO authenticated;
