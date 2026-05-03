-- admin_transaction_report: flexible transaction report for the admin reports screen.
--
-- Returns one row per transaction for type IN ('all','deposit','withdrawal') or
-- a single aggregate row for type = 'count'.
--
-- No SECURITY DEFINER: runs as the calling user so the database's own RLS
-- policies on each joined table gate access naturally.

create or replace function public.admin_transaction_report(
  p_from              timestamptz  default null,
  p_to                timestamptz  default null,
  p_school_id         uuid         default null,
  p_class_id          uuid         default null,
  p_teacher_name_like text         default null,
  p_student_name_like text         default null,
  p_type              text         default 'all',
  p_limit             int          default 5000
)
returns table (
  transaction_id     uuid,
  created_at         timestamptz,
  tx_type            text,
  amount             numeric,
  school_id          uuid,
  school_name        text,
  class_id           uuid,
  class_name         text,
  teacher_id         uuid,
  teacher_first_name text,
  teacher_last_name  text,
  student_id         uuid,
  student_first_name text,
  student_last_name  text,
  -- aggregate columns (non-null only when p_type = 'count')
  transaction_count  bigint,
  total_amount       numeric
)
language sql
stable
as $$
  with _tx as (
    select
      t.transaction_id,
      t.created_at,
      tt.name                    as tx_type,
      t.amount::numeric          as amount,
      s.school_id,
      s.name                     as school_name,
      sc.class_id,
      sc.name                    as class_name,
      te.teacher_id,
      tu.first_name              as teacher_first_name,
      tu.last_name               as teacher_last_name,
      st.student_id,
      su.first_name              as student_first_name,
      su.last_name               as student_last_name
    from      public.transactions  t
    join      public.tx_type  tt  on tt.type_id    = t.type_id
    left join public.teacher  te  on te.teacher_id = t.teacher_id
    left join public.user     tu  on tu.user_id    = te.user_id
    left join public.student  st  on st.student_id = t.student_id
    left join public.user     su  on su.user_id    = st.user_id
    left join public.school   s   on s.school_id   = coalesce(st.school_id, te.school_id)
    left join lateral (
      select stc2.class_id
      from public.student_class stc2
      where stc2.student_id = st.student_id
        and stc2.start_date <= t.created_at::date
        and (stc2.end_date is null or stc2.end_date >= t.created_at::date)
      order by stc2.start_date desc
      limit 1
    ) stc on true
    left join public.class    sc  on sc.class_id   = stc.class_id
    where
      (p_from             is null or t.created_at   >= p_from)
      and (p_to           is null or t.created_at   <= p_to)
      and (p_school_id    is null or coalesce(st.school_id, te.school_id) = p_school_id)
      and (p_class_id     is null or stc.class_id    = p_class_id)
      and (p_teacher_name_like is null
           or tu.first_name ilike '%' || p_teacher_name_like || '%'
           or tu.last_name  ilike '%' || p_teacher_name_like || '%'
           or (tu.first_name || ' ' || coalesce(tu.last_name, ''))
              ilike '%' || p_teacher_name_like || '%')
      and (p_student_name_like is null
           or su.first_name ilike '%' || p_student_name_like || '%'
           or su.last_name  ilike '%' || p_student_name_like || '%'
           or (su.first_name || ' ' || coalesce(su.last_name, ''))
              ilike '%' || p_student_name_like || '%')
      and (
        p_type in ('all', 'count')
        or (p_type = 'deposit'    and lower(tt.name) like '%deposit%')
        or (p_type = 'withdrawal' and lower(tt.name) like '%withdrawal%')
      )
  )

  select
    null::uuid        as transaction_id,
    null::timestamptz as created_at,
    'count'::text     as tx_type,
    null::numeric     as amount,
    null::uuid        as school_id,
    null::text        as school_name,
    null::uuid        as class_id,
    null::text        as class_name,
    null::uuid        as teacher_id,
    null::text        as teacher_first_name,
    null::text        as teacher_last_name,
    null::uuid        as student_id,
    null::text        as student_first_name,
    null::text        as student_last_name,
    count(*)          as transaction_count,
    coalesce(sum(amount), 0) as total_amount
  from _tx
  where p_type = 'count'

  union all

  select
    transaction_id,
    created_at,
    tx_type,
    amount,
    school_id,
    school_name,
    class_id,
    class_name,
    teacher_id,
    teacher_first_name,
    teacher_last_name,
    student_id,
    student_first_name,
    student_last_name,
    null::bigint  as transaction_count,
    null::numeric as total_amount
  from _tx
  where p_type != 'count'
  order by created_at desc nulls last
  limit p_limit;
$$;

grant execute on function public.admin_transaction_report(
  timestamptz, timestamptz, uuid, uuid, text, text, text, int
) to authenticated;
