-- Fix principal_last_teacher_deposit_detail semantics.
--
-- Previous version used cu_dep_event.amount (the event's total payout, which
-- can span multiple batches) as "deposited", which produced wrong disparity
-- figures when one deposit event covers multiple batches.
--
-- Correct semantics per spec:
--   deposit_due = dep_batch.expected_amount  (status = 'DEPOSITED')
--   deposited   = SUM(cu_dep_event_batch.applied_amount) for that batch_id
--   difference  = deposit_due - deposited   (teller disparity)
--
-- Only batches with at least one matching cu_dep_event_batch row are returned
-- (INNER JOIN enforces this). The most recently deposited batch is used.

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
  -- Most recent DEPOSITED batch that has at least one cu_dep_event_batch row,
  -- optionally filtered to events deposited by a specific teacher.
  last_batch AS (
    SELECT
      b.batch_id,
      b.school_id,
      b.expected_amount,
      MAX(e.posted_at)                                                     AS deposit_date,
      (array_agg(e.deposited_by_teacher_id ORDER BY e.posted_at DESC))[1] AS batch_teacher_id
    FROM   public.dep_batch          b
    CROSS JOIN scope                 s
    -- INNER JOIN: only batches that have a record in cu_dep_event_batch
    JOIN   public.cu_dep_event_batch eb ON eb.batch_id    = b.batch_id
    JOIN   public.cu_dep_event       e  ON e.dep_event_id = eb.dep_event_id
    WHERE  b.status = 'DEPOSITED'
      AND  (p_teacher_id IS NULL OR e.deposited_by_teacher_id = p_teacher_id)
      AND  (
             s.is_admin
             OR (s.principal_school_id IS NOT NULL AND b.school_id = s.principal_school_id)
           )
    GROUP BY b.batch_id, b.school_id, b.expected_amount
    ORDER BY MAX(e.posted_at) DESC
    LIMIT 1
  ),
  -- Sum all applied_amount rows for that batch (one event may partially apply)
  batch_applied AS (
    SELECT
      eb.batch_id,
      SUM(eb.applied_amount) AS applied_total
    FROM   public.cu_dep_event_batch eb
    JOIN   last_batch lb ON lb.batch_id = eb.batch_id
    GROUP BY eb.batch_id
  ),
  -- Resolve name from the representative teacher on that batch
  batch_teacher AS (
    SELECT
      t.teacher_id,
      TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) AS teacher_name
    FROM   last_batch     lb
    JOIN   public.teacher t ON t.teacher_id = lb.batch_teacher_id
    JOIN   public."user"  u ON u.user_id    = t.user_id
  )
  SELECT
    bt.teacher_id,
    bt.teacher_name,
    lb.deposit_date,
    COALESCE(lb.expected_amount, 0)::numeric(12,2)                                   AS deposit_due,
    COALESCE(ba.applied_total,   0)::numeric(12,2)                                   AS deposited,
    (COALESCE(lb.expected_amount, 0) - COALESCE(ba.applied_total, 0))::numeric(12,2) AS difference
  FROM      last_batch    lb
  LEFT JOIN batch_applied ba ON ba.batch_id = lb.batch_id
  LEFT JOIN batch_teacher bt ON true;
$$;

GRANT  EXECUTE ON FUNCTION public.principal_last_teacher_deposit_detail(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.principal_last_teacher_deposit_detail(uuid) FROM PUBLIC;
