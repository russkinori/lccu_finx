-- Phase 2 hardening: principal read RPCs used by the Flutter client.
-- These functions keep principal-scoped financial/student reads on the backend.

create or replace function public.principal_school_account_balance(
  p_school_id uuid default null
)
returns numeric
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with scope as (
    select
      public.is_admin() as is_admin,
      public.current_principal_school_id() as principal_school_id,
      coalesce(p_school_id, public.current_principal_school_id()) as requested_school_id
  )
  select coalesce(sum(sa.closing_bal), 0)::numeric
  from public.school_acc sa
  cross join scope s
  where sa.school_id = s.requested_school_id
    and (
      s.is_admin
      or (
        s.principal_school_id is not null
        and sa.school_id = s.principal_school_id
      )
    );
$$;

create or replace function public.principal_student_balance(
  p_student_id uuid
)
returns numeric
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with scope as (
    select
      public.is_admin() as is_admin,
      public.current_principal_school_id() as principal_school_id
  )
  select coalesce((
    select sa.closing_bal::numeric
    from public.student s
    join public.student_acc sa
      on sa.student_id = s.student_id
    cross join scope sc
    where s.student_id = p_student_id
      and coalesce(sa.is_active, true) = true
      and (
        sc.is_admin
        or (
          sc.principal_school_id is not null
          and s.school_id = sc.principal_school_id
        )
      )
    order by sa.created_at desc nulls last
    limit 1
  ), 0)::numeric;
$$;

create or replace function public.principal_reconcile_week_data(
  p_week_start date default null
)
returns table (
  school_id uuid,
  teacher_id uuid,
  week_start date,
  week_end date,
  collected_amount numeric,
  batched_amount numeric,
  deposited_amount numeric,
  batched_pending_amount numeric,
  remaining_amount numeric,
  recon_status text
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with scope as (
    select
      public.is_admin() as is_admin,
      public.current_principal_school_id() as principal_school_id
  )
  select
    v.school_id,
    v.teacher_id,
    v.week_start,
    v.week_end,
    v.collected_amount,
    v.batched_amount,
    v.deposited_amount,
    v.batched_pending_amount,
    v.remaining_amount,
    v.recon_status
  from public.v_principal_reconcile_week v
  cross join scope s
  where (p_week_start is null or v.week_start = p_week_start)
    and (
      s.is_admin
      or (
        s.principal_school_id is not null
        and v.school_id = s.principal_school_id
      )
    )
  order by v.week_start desc, v.teacher_id;
$$;

create or replace function public.principal_teacher_deposit_history(
  p_teacher_id uuid default null,
  p_limit integer default 200
)
returns table (
  dep_event_id uuid,
  school_id uuid,
  teacher_id uuid,
  teacher_name text,
  deposit_date timestamptz,
  amount numeric,
  status text,
  batch_id uuid,
  week_start date,
  week_end date
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with scope as (
    select
      public.is_admin() as is_admin,
      public.current_principal_school_id() as principal_school_id
  )
  select
    v.dep_event_id,
    v.school_id,
    v.teacher_id,
    v.teacher_name,
    v.deposit_date,
    v.amount,
    v.status,
    v.batch_id,
    v.week_start,
    v.week_end
  from public.v_teacher_deposit_history v
  cross join scope s
  where (p_teacher_id is null or v.teacher_id = p_teacher_id)
    and (
      s.is_admin
      or (
        s.principal_school_id is not null
        and v.school_id = s.principal_school_id
      )
    )
  order by v.deposit_date desc
  limit greatest(coalesce(p_limit, 200), 1);
$$;

grant execute on function public.principal_school_account_balance(uuid) to authenticated;
grant execute on function public.principal_student_balance(uuid) to authenticated;
grant execute on function public.principal_reconcile_week_data(date) to authenticated;
grant execute on function public.principal_teacher_deposit_history(uuid, integer) to authenticated;
