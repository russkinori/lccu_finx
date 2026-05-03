-- Phase 3 fix: teller pending_deposit must only reflect principal-submitted dep_batch rows.
--
-- Correct workflow:
--   1. Teachers collect cash → teacher_coll rows are created
--   2. Principal reconciles and submits → dep_batch record created (submit_dep_batch RPC)
--   3. Only AFTER step 2 should the teller see a pending deposit / disparity
--
-- Root cause: teller_home_rows and teller_school_deposit_snapshot both called
-- teller_school_deposit_summary() which sums teacher_coll amounts directly,
-- so teller saw money as "pending" before the principal had submitted any batch.
--
-- Fix: replace teller_school_deposit_summary() calls with sums from
-- teller_pending_deposit_batches(), which reads the dep_batch table (submitted batches only).

create or replace function public.teller_home_rows(
  p_week_start timestamptz,
  p_week_end timestamptz
)
returns table(
  school_id uuid,
  school_name text,
  account_balance numeric,
  pending_deposit numeric,
  latest_discrepancy numeric
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
as $function$
  with me as (
    select t.teller_id
    from public.teller t
    where t.user_id = auth.uid()
    limit 1
  ),
  balances as (
    select
      sa.school_id,
      coalesce(sum(sa.closing_bal), 0)::numeric as account_balance
    from me
    join public.school_acc sa
      on true
    group by sa.school_id
  )
  select
    s.school_id,
    s.name                                       as school_name,
    coalesce(b.account_balance, 0)::numeric      as account_balance,
    -- pending_deposit: total principal has committed to bring in (sum of deposit_due
    -- across all submitted-but-not-yet-fully-posted batches for this school)
    coalesce((
      select sum(pb.deposit_due)
      from public.teller_pending_deposit_batches(s.school_id) pb
    ), 0)::numeric                               as pending_deposit,
    -- latest_discrepancy: amount still outstanding (deposit_due minus already posted)
    coalesce((
      select sum(pb.remaining_amount)
      from public.teller_pending_deposit_batches(s.school_id) pb
    ), 0)::numeric                               as latest_discrepancy
  from me
  join public.school s
    on true
  left join balances b
    on b.school_id = s.school_id
  order by s.name;
$function$;


create or replace function public.teller_school_deposit_snapshot(
  p_school_id uuid,
  p_week_start timestamptz,   -- kept for API compatibility; no longer used
  p_week_end   timestamptz    -- kept for API compatibility; no longer used
)
returns table(
  deposit_due numeric,
  deposited   numeric,
  discrepancy numeric
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
as $function$
  with me as (
    select t.teller_id
    from public.teller t
    where t.user_id = auth.uid()
    limit 1
  ),
  batch_summary as (
    select
      coalesce(sum(pb.deposit_due),        0)::numeric as deposit_due,
      coalesce(sum(pb.deposited_amount),   0)::numeric as deposited,
      coalesce(sum(pb.remaining_amount),   0)::numeric as discrepancy
    from public.teller_pending_deposit_batches(p_school_id) pb
  )
  -- cross join with me ensures an empty result for non-teller callers
  select bs.deposit_due, bs.deposited, bs.discrepancy
  from me
  cross join batch_summary bs;
$function$;

-- Grant EXECUTE on submit_dep_batch to authenticated.
-- The function is pre-existing (not in these migrations) but was never
-- explicitly granted, causing "permission denied" when the principal calls
-- it directly via the PostgREST RPC endpoint.
-- DO block avoids needing the exact argument-type signature.
do $$
declare
  fn_rec record;
begin
  for fn_rec in
    select oid, pg_get_function_arguments(oid) as args
    from pg_proc
    where proname = 'submit_dep_batch'
      and pronamespace = 'public'::regnamespace
  loop
    execute format(
      'grant execute on function public.submit_dep_batch(%s) to authenticated',
      fn_rec.args
    );
  end loop;
end;
$$;
