-- Phase 3 hotfix: keep dashboard-level deposited funds separate from
-- outstanding deposit-detail rows.
--
-- The principal dashboard top card may show all posted school deposits.
-- These detail RPCs instead describe only the currently outstanding/on-site
-- deposit obligation, so historical posted deposits do not appear as
-- "Deposited" inside the detail cards.

create or replace function public.principal_school_outstanding_deposit_detail()
returns table (
  school_id uuid,
  deposit_due numeric,
  deposited numeric,
  difference numeric
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
  ),
  outstanding as (
    select
      tc.school_id,
      sum(
        greatest(
          tc.amount::numeric - coalesce((
            select sum(i.applied_amount)::numeric
            from public.cu_dep_event_item i
            join public.cu_dep_event e
              on e.dep_event_id = i.dep_event_id
             and e.status = 'Posted'
            where i.collection_id = tc.collection_id
          ), 0),
          0
        )
      )::numeric as outstanding_amount
    from public.teacher_coll tc
    cross join scope s
    where tc.amount > 0
      and (
        s.is_admin
        or (
          s.principal_school_id is not null
          and tc.school_id = s.principal_school_id
        )
      )
    group by tc.school_id
  )
  select
    coalesce(o.school_id, s.principal_school_id) as school_id,
    coalesce(o.outstanding_amount, 0)::numeric(12,2) as deposit_due,
    0::numeric(12,2) as deposited,
    coalesce(o.outstanding_amount, 0)::numeric(12,2) as difference
  from scope s
  left join outstanding o
    on o.school_id = s.principal_school_id
  where s.is_admin or s.principal_school_id is not null;
$$;

create or replace function public.principal_teacher_outstanding_deposit_detail(
  p_teacher_id uuid default null
)
returns table (
  school_id uuid,
  teacher_id uuid,
  deposit_due numeric,
  deposited numeric,
  difference numeric
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
  ),
  outstanding as (
    select
      tc.school_id,
      case when p_teacher_id is null then null::uuid else tc.teacher_id end as teacher_id,
      sum(
        greatest(
          tc.amount::numeric - coalesce((
            select sum(i.applied_amount)::numeric
            from public.cu_dep_event_item i
            join public.cu_dep_event e
              on e.dep_event_id = i.dep_event_id
             and e.status = 'Posted'
            where i.collection_id = tc.collection_id
          ), 0),
          0
        )
      )::numeric as outstanding_amount
    from public.teacher_coll tc
    cross join scope s
    where tc.amount > 0
      and (p_teacher_id is null or tc.teacher_id = p_teacher_id)
      and (
        s.is_admin
        or (
          s.principal_school_id is not null
          and tc.school_id = s.principal_school_id
        )
      )
    group by tc.school_id, case when p_teacher_id is null then null::uuid else tc.teacher_id end
  )
  select
    coalesce(o.school_id, s.principal_school_id) as school_id,
    coalesce(o.teacher_id, p_teacher_id) as teacher_id,
    coalesce(o.outstanding_amount, 0)::numeric(12,2) as deposit_due,
    0::numeric(12,2) as deposited,
    coalesce(o.outstanding_amount, 0)::numeric(12,2) as difference
  from scope s
  left join outstanding o
    on o.school_id = s.principal_school_id
  where s.is_admin or s.principal_school_id is not null;
$$;

grant execute on function public.principal_school_outstanding_deposit_detail() to authenticated;
grant execute on function public.principal_teacher_outstanding_deposit_detail(uuid) to authenticated;

notify pgrst, 'reload schema';
