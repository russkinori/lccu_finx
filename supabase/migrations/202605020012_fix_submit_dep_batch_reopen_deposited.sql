-- Fix: allow principal to re-submit collections for a week whose dep_batch is
-- already DEPOSITED (e.g. late teacher entries added after the teller processed).
--
-- Root cause in old function:
--   The ON CONFLICT DO UPDATE intentionally kept status = 'DEPOSITED' when a
--   conflict was hit, then immediately raised an exception.  This blocked any
--   top-up submission for that week.
--
-- New behaviour:
--   • DEPOSITED batches are re-opened to SUBMITTED so the teller can process
--     the additional collections.
--   • CANCELLED batches remain permanently blocked (hard-blocked below).
--   • All other logic (dep_item upsert, teacher_coll status, recalc) is
--     identical to the original function.

create or replace function public.submit_dep_batch(
  p_school_id uuid,
  p_week_start date,
  p_note       text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_week_start date := p_week_start;
  v_week_end   date := p_week_start + 6;
  v_batch_id   uuid;
  v_expected   numeric;
BEGIN
  IF p_school_id IS NULL OR p_week_start IS NULL THEN
    RAISE EXCEPTION 'school_id and week_start are required';
  END IF;

  INSERT INTO public.dep_batch (
    batch_id,
    school_id,
    week_start,
    week_end,
    status,
    expected_amount,
    created_at,
    created_by,
    submitted_at,
    submitted_by,
    note
  )
  VALUES (
    gen_random_uuid(),
    p_school_id,
    v_week_start,
    v_week_end,
    'SUBMITTED',
    0,
    now(),
    auth.uid(),
    now(),
    auth.uid(),
    NULLIF(p_note, '')
  )
  ON CONFLICT (school_id, week_start, week_end)
  DO UPDATE SET
    -- Re-open DEPOSITED batches so additional (late) collections can be
    -- submitted.  Only CANCELLED is permanently blocked.
    status = CASE
      WHEN public.dep_batch.status = 'CANCELLED'
        THEN public.dep_batch.status
      ELSE 'SUBMITTED'
    END,
    submitted_at = CASE
      WHEN public.dep_batch.status = 'CANCELLED'
        THEN public.dep_batch.submitted_at
      ELSE now()
    END,
    submitted_by = CASE
      WHEN public.dep_batch.status = 'CANCELLED'
        THEN public.dep_batch.submitted_by
      ELSE auth.uid()
    END,
    note = CASE
      WHEN EXCLUDED.note IS NULL         THEN public.dep_batch.note
      WHEN public.dep_batch.note IS NULL THEN EXCLUDED.note
      ELSE public.dep_batch.note || E'\n' || EXCLUDED.note
    END
  RETURNING batch_id INTO v_batch_id;

  -- Hard-block only CANCELLED batches; DEPOSITED has been re-opened above.
  IF EXISTS (
    SELECT 1
    FROM public.dep_batch b
    WHERE b.batch_id = v_batch_id
      AND b.status   = 'CANCELLED'
  ) THEN
    RAISE EXCEPTION 'Cannot resubmit a batch that is already CANCELLED'
      USING errcode = 'P0001';
  END IF;

  -- Upsert dep_item rows for all positive teacher collections this week.
  -- Collections already in dep_item (from the prior DEPOSITED submission)
  -- are updated in-place; new (late) collections are inserted fresh.
  INSERT INTO public.dep_item (
    item_id,
    batch_id,
    collection_id,
    amount
  )
  SELECT
    gen_random_uuid(),
    v_batch_id,
    tc.collection_id,
    tc.amount
  FROM public.teacher_coll tc
  WHERE tc.school_id  = p_school_id
    AND tc.week_start = v_week_start
    AND tc.week_end   = v_week_end
    AND tc.amount > 0
  ON CONFLICT (collection_id)
  DO UPDATE SET
    batch_id = EXCLUDED.batch_id,
    amount   = EXCLUDED.amount;

  -- Mark batched collections.
  UPDATE public.teacher_coll tc
  SET
    status     = 'IN_BATCH',
    updated_at = now()
  WHERE tc.school_id  = p_school_id
    AND tc.week_start = v_week_start
    AND tc.week_end   = v_week_end
    AND tc.amount > 0
    AND EXISTS (
      SELECT 1
      FROM public.dep_item di
      WHERE di.batch_id      = v_batch_id
        AND di.collection_id = tc.collection_id
    );

  -- Mark zero-amount collections.
  UPDATE public.teacher_coll tc
  SET
    status     = 'NO_DEPOSIT_REQUIRED',
    updated_at = now()
  WHERE tc.school_id  = p_school_id
    AND tc.week_start = v_week_start
    AND tc.week_end   = v_week_end
    AND COALESCE(tc.amount, 0) <= 0
    AND tc.status IS DISTINCT FROM 'NO_DEPOSIT_REQUIRED';

  PERFORM public.recalc_deposit_batch_expected(v_batch_id);

  SELECT COALESCE(expected_amount, 0)
  INTO   v_expected
  FROM   public.dep_batch
  WHERE  batch_id = v_batch_id;

  IF COALESCE(v_expected, 0) <= 0 THEN
    UPDATE public.dep_batch
    SET status = 'NO_DEPOSIT_REQUIRED'
    WHERE batch_id = v_batch_id;

    RAISE EXCEPTION 'No positive teacher collections found for this school and week';
  END IF;

  RETURN v_batch_id;
END;
$function$;

-- Re-grant execute to authenticated (signature unchanged; re-grant is idempotent).
do $$
declare
  fn_rec record;
begin
  for fn_rec in
    select oid, pg_get_function_identity_arguments(oid) as args
    from   pg_proc
    where  proname        = 'submit_dep_batch'
      and  pronamespace   = 'public'::regnamespace
  loop
    execute format(
      'grant execute on function public.submit_dep_batch(%s) to authenticated',
      fn_rec.args
    );
  end loop;
end;
$$;
