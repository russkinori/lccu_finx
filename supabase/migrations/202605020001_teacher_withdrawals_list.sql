-- Teacher-scoped withdrawal history for the Flutter teacher workflow.
-- Deploy this before using the Phase 2 app package.

create or replace function public.teacher_withdrawals_list(
  p_class_id uuid default null,
  p_student_id uuid default null,
  p_limit integer default 500
)
returns table (
  request_id uuid,
  requested_at timestamptz,
  amount numeric,
  status text,
  student_id uuid,
  student_name text,
  class_id uuid,
  class_name text
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with me_teacher as (
    select t.teacher_id, t.school_id
    from public.teacher t
    where t.user_id = auth.uid()
    limit 1
  ),
  current_class as (
    select distinct on (sc.student_id)
      sc.student_id,
      sc.class_id
    from public.student_class sc
    where sc.start_date <= current_date
      and (sc.end_date is null or sc.end_date >= current_date)
    order by sc.student_id, sc.start_date desc
  )
  select
    wr.request_id,
    wr.requested_at,
    wr.amount::numeric,
    ts.name as status,
    s.student_id,
    trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')) as student_name,
    cc.class_id,
    c.name as class_name
  from me_teacher mt
  join public.student s
    on s.school_id = mt.school_id
  join public.withdrawal_req wr
    on wr.student_id = s.student_id
  join public.tx_stat ts
    on ts.status_id = wr.status_id
  join public."user" u
    on u.user_id = s.user_id
  left join current_class cc
    on cc.student_id = s.student_id
  left join public.class c
    on c.class_id = cc.class_id
  where (p_student_id is null or s.student_id = p_student_id)
    and (p_class_id is null or cc.class_id = p_class_id)
  order by wr.requested_at desc
  limit greatest(coalesce(p_limit, 500), 1);
$$;

grant execute on function public.teacher_withdrawals_list(uuid, uuid, integer) to authenticated;
