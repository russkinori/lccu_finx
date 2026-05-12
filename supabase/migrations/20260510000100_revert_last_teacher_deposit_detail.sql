-- Revert: restore principal_last_teacher_deposit_detail to the version from
-- 202605030001_fix_cash_workflow.sql. The 20260509002000 migration broke this
-- by filtering only DEPOSITED batches, which caused an unrelated batch's
-- applied_amount to be returned instead of the correct last-event figures.

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

GRANT  EXECUTE ON FUNCTION public.principal_last_teacher_deposit_detail(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.principal_last_teacher_deposit_detail(uuid) FROM PUBLIC;
