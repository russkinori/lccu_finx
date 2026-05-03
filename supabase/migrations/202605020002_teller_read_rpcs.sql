-- Phase 2 hardening: move teller read paths behind RPCs.
-- Existing write RPCs remain unchanged: teller_post_school_deposit_event and teller_post_school_payout.

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
  ),
  pending as (
    select
      s.school_id,
      coalesce(s.pending_deposit, 0)::numeric as pending_deposit
    from public.teller_school_deposit_summary() s
  ),
  deposited as (
    select
      e.school_id,
      coalesce(sum(e.amount), 0)::numeric as deposited_amount
    from me
    join public.cu_dep_event e
      on true
    where e.status = 'Posted'
      and e.posted_at >= p_week_start
      and e.posted_at <= p_week_end
    group by e.school_id
  )
  select
    s.school_id,
    s.name as school_name,
    coalesce(b.account_balance, 0)::numeric as account_balance,
    coalesce(p.pending_deposit, 0)::numeric as pending_deposit,
    greatest(
      coalesce(p.pending_deposit, 0) - coalesce(d.deposited_amount, 0),
      0
    )::numeric as latest_discrepancy
  from me
  join public.school s
    on true
  left join balances b
    on b.school_id = s.school_id
  left join pending p
    on p.school_id = s.school_id
  left join deposited d
    on d.school_id = s.school_id
  order by s.name;
$function$;

create or replace function public.teller_school_deposit_snapshot(
  p_school_id uuid,
  p_week_start timestamptz,
  p_week_end timestamptz
)
returns table(
  deposit_due numeric,
  deposited numeric,
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
  due as (
    select coalesce(s.pending_deposit, 0)::numeric as deposit_due
    from public.teller_school_deposit_summary() s
    where s.school_id = p_school_id
  ),
  dep as (
    select coalesce(sum(e.amount), 0)::numeric as deposited
    from me
    join public.cu_dep_event e
      on true
    where e.school_id = p_school_id
      and e.status = 'Posted'
      and e.posted_at >= p_week_start
      and e.posted_at <= p_week_end
  )
  select
    coalesce((select d.deposit_due from due d limit 1), 0)::numeric as deposit_due,
    coalesce((select dep.deposited from dep limit 1), 0)::numeric as deposited,
    greatest(
      coalesce((select d.deposit_due from due d limit 1), 0)
        - coalesce((select dep.deposited from dep limit 1), 0),
      0
    )::numeric as discrepancy
  from me;
$function$;

create or replace function public.teller_deposit_events_list(
  p_from timestamptz,
  p_to timestamptz,
  p_school_id uuid default null,
  p_teacher_id uuid default null,
  p_limit integer default 5000
)
returns table(
  school_id uuid,
  teacher_id uuid,
  posted_by_teller_id uuid,
  posted_at timestamptz,
  amount numeric,
  discrepancy numeric,
  status text,
  notes text
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
  )
  select
    e.school_id,
    e.deposited_by_teacher_id as teacher_id,
    e.posted_by_teller_id,
    e.posted_at,
    coalesce(e.amount, 0)::numeric as amount,
    0::numeric as discrepancy,
    e.status,
    coalesce(e.notes, '') as notes
  from me
  join public.cu_dep_event e
    on true
  where e.posted_at >= p_from
    and e.posted_at <= p_to
    and (p_school_id is null or e.school_id = p_school_id)
    and (p_teacher_id is null or e.deposited_by_teacher_id = p_teacher_id)
  order by e.posted_at desc
  limit least(greatest(coalesce(p_limit, 5000), 1), 5000);
$function$;

create or replace function public.teller_school_payouts_list(
  p_from timestamptz,
  p_to timestamptz,
  p_school_id uuid default null,
  p_limit integer default 5000
)
returns table(
  school_id uuid,
  request_id uuid,
  posted_by_teller_id uuid,
  posted_at timestamptz,
  amount numeric,
  note text,
  requested_by_role text,
  requested_by_teacher_id uuid,
  requested_by_principal_id uuid
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
  )
  select
    p.school_id,
    p.request_id,
    p.posted_by_teller_id,
    p.posted_at,
    coalesce(p.amount, 0)::numeric as amount,
    coalesce(p.note, '') as note,
    p.requested_by_role,
    p.requested_by_teacher_id,
    p.requested_by_principal_id
  from me
  join public.cu_payout p
    on true
  where p.posted_at >= p_from
    and p.posted_at <= p_to
    and (p_school_id is null or p.school_id = p_school_id)
  order by p.posted_at desc
  limit least(greatest(coalesce(p_limit, 5000), 1), 5000);
$function$;

grant execute on function public.teller_home_rows(timestamptz, timestamptz) to authenticated;
grant execute on function public.teller_school_deposit_snapshot(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.teller_deposit_events_list(timestamptz, timestamptz, uuid, uuid, integer) to authenticated;
grant execute on function public.teller_school_payouts_list(timestamptz, timestamptz, uuid, integer) to authenticated;
