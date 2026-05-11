-- Fix: teacher_home_metrics funds_in_hand should decrease when collections are
-- batched by the principal, not only when the credit union deposit is Posted.
--
-- Root cause: the previous implementation only subtracted amounts from
-- cu_dep_event_item WHERE cu_dep_event.status = 'Posted'.  This meant the
-- teacher still saw the full collected amount as "in hand" while it was sitting
-- in a dep_batch being reconciled or submitted to the teller.
--
-- Fix: replace the `deposited` CTE (which read cu_dep_event_item) with a
-- `batched` CTE that reads dep_item joined to dep_batch. Any collection that
-- has been assigned to a non-cancelled batch is no longer in the teacher's
-- custody — it is with the principal / in transit to the credit union.
-- CANCELLED batches are excluded so those collections correctly return to the
-- teacher's funds-in-hand total.

CREATE OR REPLACE FUNCTION public.teacher_home_metrics(
  p_class_id  uuid DEFAULT NULL::uuid,
  p_student_id uuid DEFAULT NULL::uuid
)
RETURNS TABLE(
  teacher_id           uuid,
  school_id            uuid,
  funds_in_hand        numeric,
  account_balance_total numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT t.teacher_id, t.school_id
    FROM public.teacher t
    WHERE t.user_id = auth.uid()
    LIMIT 1
  ),
  current_class AS (
    SELECT DISTINCT ON (sc.student_id)
      sc.student_id,
      sc.class_id
    FROM public.student_class sc
    WHERE sc.start_date <= current_date
      AND (sc.end_date IS NULL OR sc.end_date >= current_date)
    ORDER BY sc.student_id, sc.start_date DESC
  ),
  scoped_students AS (
    SELECT s.student_id
    FROM me
    JOIN public.student s
      ON s.school_id = me.school_id
    LEFT JOIN current_class cc
      ON cc.student_id = s.student_id
    WHERE (p_class_id IS NULL OR cc.class_id = p_class_id)
      AND (p_student_id IS NULL OR s.student_id = p_student_id)
  ),
  collected AS (
    -- All cash the teacher has taken in from students.
    SELECT COALESCE(SUM(tc.amount), 0)::numeric AS collected_total
    FROM me
    JOIN public.teacher_coll tc ON tc.teacher_id = me.teacher_id
  ),
  batched AS (
    -- Money assigned to any non-cancelled dep_batch is no longer held by the
    -- teacher — it has been taken by the principal for deposit.
    SELECT COALESCE(SUM(di.amount), 0)::numeric AS batched_total
    FROM me
    JOIN public.teacher_coll tc  ON tc.teacher_id  = me.teacher_id
    JOIN public.dep_item      di  ON di.collection_id = tc.collection_id
    JOIN public.dep_batch     db  ON db.batch_id      = di.batch_id
                                 AND db.status        <> 'CANCELLED'
  ),
  balances AS (
    SELECT COALESCE(SUM(sa.closing_bal), 0)::numeric AS account_balance_total
    FROM scoped_students ss
    JOIN public.student_acc sa ON sa.student_id = ss.student_id
    WHERE COALESCE(sa.is_active, true) = true
  )
  SELECT
    me.teacher_id,
    me.school_id,
    GREATEST(
      COALESCE(c.collected_total, 0) - COALESCE(b.batched_total, 0),
      0
    )::numeric AS funds_in_hand,
    COALESCE(bal.account_balance_total, 0)::numeric AS account_balance_total
  FROM me
  CROSS JOIN collected  c
  CROSS JOIN batched    b
  CROSS JOIN balances   bal;
$function$;

-- Re-grant execute to authenticated (SECURITY DEFINER functions need explicit grants)
GRANT EXECUTE ON FUNCTION public.teacher_home_metrics(uuid, uuid) TO authenticated;
