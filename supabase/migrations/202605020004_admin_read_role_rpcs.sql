-- Admin read/role RPCs for client hardening.
-- These functions are SECURITY DEFINER but explicitly require public.is_admin().

create or replace function public.admin_role_id_by_name(p_role_name text)
returns uuid
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  select case
    when public.is_admin() then (
      select r.role_id
      from public.role r
      where lower(r.role_name) = lower(p_role_name)
      limit 1
    )
    else null::uuid
  end;
$$;

create or replace function public.admin_user_role_names(p_user_id uuid)
returns text[]
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  select case
    when public.is_admin() then coalesce(array_agg(r.role_name order by r.role_name), '{}'::text[])
    else '{}'::text[]
  end
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = p_user_id;
$$;

create or replace function public.admin_assign_role(p_user_id uuid, p_role_name text)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
declare
  v_role_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  select r.role_id into v_role_id
  from public.role r
  where lower(r.role_name) = lower(p_role_name)
  limit 1;

  if v_role_id is null then
    raise exception 'Role % not found', p_role_name;
  end if;

  insert into public.user_role(user_role_id, user_id, role_id, created_at)
  values (gen_random_uuid(), p_user_id, v_role_id, now())
  on conflict (user_id, role_id) do nothing;
end;
$$;

create or replace function public.admin_remove_role(p_user_id uuid, p_role_name text)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
declare
  v_role_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  select r.role_id into v_role_id
  from public.role r
  where lower(r.role_name) = lower(p_role_name)
  limit 1;

  if v_role_id is null then
    return;
  end if;

  delete from public.user_role
  where user_id = p_user_id
    and role_id = v_role_id;
end;
$$;

create or replace function public.admin_schools_lookup()
returns table(school_id uuid, name text, level uuid)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  select s.school_id, s.name, s."Level" as level
  from public.school s
  where public.is_admin()
  order by s.name;
$$;

create or replace function public.admin_classes_for_school(p_school_id uuid)
returns table(class_id uuid, name text, level_id uuid)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with selected_school as (
    select s."Level" as level_id
    from public.school s
    where s.school_id = p_school_id
    limit 1
  )
  select c.class_id, c.name, c.level_id
  from public.class c
  where public.is_admin()
    and (
      (select level_id from selected_school) is null
      or c.level_id = (select level_id from selected_school)
    )
  order by c.name;
$$;

create or replace function public.admin_guardian_types_lookup()
returns table(type_id uuid, name text)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  select gt.type_id, gt.name
  from public.guardian_type gt
  where public.is_admin()
  order by gt.name;
$$;

create or replace function public.admin_credit_unions_lookup()
returns table(branch_id uuid, branch text)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  select cb.branch_id, cb.branch
  from public.cu_branch cb
  where public.is_admin()
  order by cb.branch;
$$;

create or replace function public.admin_user_profiles(
  p_user_id uuid default null,
  p_search text default null,
  p_role text default null,
  p_school_id uuid default null,
  p_is_active boolean default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table(
  user_id uuid,
  first_name text,
  last_name text,
  email text,
  gender text,
  title text,
  created_at timestamptz,
  updated_at timestamptz,
  is_active boolean,
  role_names text[],
  school_id uuid,
  school_name text,
  class_id uuid,
  class_name text,
  guardian_type_id uuid,
  credit_union_id uuid,
  mobile text,
  address text,
  date_of_birth date,
  guardian_user_id uuid,
  guardian_link_count bigint,
  guardian_type_source text,
  student_guardian_link_count bigint,
  student_has_primary_guardian boolean,
  student_guardian_selection_note text
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with base as (
    select
      u.user_id,
      u.first_name,
      u.last_name,
      u.email,
      gdr.name as gender,
      coalesce(t.title, p.title, te.title, g.title, a.title) as title,
      u.created_at,
      u.updated_at,
      coalesce(u.is_active, true) as is_active,
      coalesce(array_agg(distinct r.role_name) filter (where r.role_name is not null), '{}'::text[]) as role_names,
      s.student_id,
      g.guardian_id,
      coalesce(s.school_id, t.school_id, p.school_id) as school_id,
      sch.name as school_name,
      sc_cur.class_id,
      cls.name as class_name,
      s.date_of_birth,
      te.branch_id as credit_union_id,
      g.mobile,
      concat_ws(', ', nullif(addr.post_off,''), nullif(addr.town,''), nullif(addr.district,''), nullif(addr.zip,'')) as address
    from public."user" u
    left join public.gender gdr on gdr.gender_id = u.gender_id
    left join public.user_role ur on ur.user_id = u.user_id
    left join public.role r on r.role_id = ur.role_id
    left join public.student s on s.user_id = u.user_id
    left join public.teacher t on t.user_id = u.user_id
    left join public.principal p on p.user_id = u.user_id
    left join public.teller te on te.user_id = u.user_id
    left join public.guardian g on g.user_id = u.user_id
    left join public.admin a on a.user_id = u.user_id
    left join public.address addr on addr.address_id = g.address_id
    left join public.school sch on sch.school_id = coalesce(s.school_id, t.school_id, p.school_id)
    left join lateral (
      select sc.class_id
      from public.student_class sc
      where sc.student_id = s.student_id
        and (sc.end_date is null or sc.end_date >= current_date)
      order by sc.start_date desc
      limit 1
    ) sc_cur on true
    left join public.class cls on cls.class_id = sc_cur.class_id
    where public.is_admin()
      and (p_user_id is null or u.user_id = p_user_id)
      and (p_is_active is null or coalesce(u.is_active, true) = p_is_active)
      and (
        p_search is null or p_search = ''
        or u.first_name ilike '%' || p_search || '%'
        or u.last_name ilike '%' || p_search || '%'
        or u.email ilike '%' || p_search || '%'
      )
      and (
        p_role is null or p_role = ''
        or exists (
          select 1
          from public.user_role ur2
          join public.role r2 on r2.role_id = ur2.role_id
          where ur2.user_id = u.user_id
            and lower(r2.role_name) = lower(p_role)
        )
      )
      and (
        p_school_id is null
        or coalesce(s.school_id, t.school_id, p.school_id) = p_school_id
      )
    group by
      u.user_id, u.first_name, u.last_name, u.email, gdr.name,
      t.title, p.title, te.title, g.title, a.title,
      u.created_at, u.updated_at, u.is_active,
      s.student_id, g.guardian_id,
      s.school_id, t.school_id, p.school_id, sch.name,
      sc_cur.class_id, cls.name, s.date_of_birth, te.branch_id,
      g.mobile, addr.post_off, addr.town, addr.district, addr.zip
    order by u.first_name, u.last_name, u.email
    limit greatest(coalesce(p_limit, 50), 1)
    offset greatest(coalesce(p_offset, 0), 0)
  ), student_guardian_choice as (
    select
      b.user_id,
      sg.guardian_id,
      gg.user_id as guardian_user_id,
      sg.type_id as guardian_type_id,
      sg.is_primary,
      count(*) over (partition by b.user_id) as link_count,
      bool_or(coalesce(sg.is_primary, false)) over (partition by b.user_id) as has_primary,
      row_number() over (
        partition by b.user_id
        order by coalesce(sg.is_primary, false) desc, sg.created_at desc nulls last, sg.sg_id desc
      ) as rn
    from base b
    join public.student_guardian sg on sg.student_id = b.student_id
    join public.guardian gg on gg.guardian_id = sg.guardian_id
  ), guardian_link_choice as (
    select
      b.user_id,
      sg.type_id as guardian_type_id,
      sg.is_primary,
      count(*) over (partition by b.user_id) as link_count,
      row_number() over (
        partition by b.user_id
        order by coalesce(sg.is_primary, false) desc, sg.created_at desc nulls last, sg.sg_id desc
      ) as rn
    from base b
    join public.student_guardian sg on sg.guardian_id = b.guardian_id
  )
  select
    b.user_id,
    b.first_name,
    b.last_name,
    b.email,
    b.gender,
    b.title,
    b.created_at,
    b.updated_at,
    b.is_active,
    b.role_names,
    b.school_id,
    b.school_name,
    b.class_id,
    b.class_name,
    coalesce(glc.guardian_type_id, sgc.guardian_type_id) as guardian_type_id,
    b.credit_union_id,
    b.mobile,
    nullif(b.address, '') as address,
    b.date_of_birth,
    sgc.guardian_user_id,
    glc.link_count as guardian_link_count,
    case when glc.guardian_type_id is null then null when coalesce(glc.is_primary, false) then 'primary' else 'first' end as guardian_type_source,
    sgc.link_count as student_guardian_link_count,
    sgc.has_primary as student_has_primary_guardian,
    case
      when sgc.guardian_user_id is null then null
      when coalesce(sgc.is_primary, false) then 'Primary guardian selected.'
      else 'Most recent guardian link selected.'
    end as student_guardian_selection_note
  from base b
  left join student_guardian_choice sgc on sgc.user_id = b.user_id and sgc.rn = 1
  left join guardian_link_choice glc on glc.user_id = b.user_id and glc.rn = 1;
$$;

create or replace function public.admin_school_deposits_report(
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_school_id uuid default null,
  p_type text default 'all',
  p_limit integer default 5000
)
returns table(
  dep_event_id uuid,
  school_id uuid,
  school_name text,
  posted_at timestamptz,
  amount double precision,
  status text,
  deposited_by_teacher_id uuid,
  posted_by_teller_id uuid,
  transaction_count bigint,
  total_amount double precision
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  with rows as (
    select
      e.dep_event_id,
      e.school_id,
      s.name as school_name,
      e.posted_at,
      e.amount,
      e.status,
      e.deposited_by_teacher_id,
      e.posted_by_teller_id
    from public.cu_dep_event e
    left join public.school s on s.school_id = e.school_id
    where public.is_admin()
      and e.status = 'Posted'
      and (p_from is null or e.posted_at >= p_from)
      and (p_to is null or e.posted_at <= p_to)
      and (p_school_id is null or e.school_id = p_school_id)
    order by e.posted_at desc
    limit greatest(coalesce(p_limit, 5000), 1)
  ), totals as (
    select count(*)::bigint as c, coalesce(sum(amount), 0)::double precision as s
    from rows
  )
  select
    r.dep_event_id,
    r.school_id,
    r.school_name,
    r.posted_at,
    r.amount,
    r.status,
    r.deposited_by_teacher_id,
    r.posted_by_teller_id,
    case when p_type = 'count' then t.c else null::bigint end as transaction_count,
    case when p_type = 'count' then t.s else null::double precision end as total_amount
  from rows r
  cross join totals t
  where coalesce(p_type, 'all') <> 'count'
  union all
  select
    null::uuid,
    p_school_id,
    null::text,
    null::timestamptz,
    null::double precision,
    null::text,
    null::uuid,
    null::uuid,
    t.c,
    t.s
  from totals t
  where coalesce(p_type, 'all') = 'count';
$$;

create or replace function public.user_names_by_ids(p_user_ids uuid[])
returns table(user_id uuid, first_name text, last_name text)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
set row_security to 'off'
as $$
  select u.user_id, u.first_name, u.last_name
  from public."user" u
  where u.user_id = any(p_user_ids)
    and (
      public.is_admin()
      or u.user_id = auth.uid()
      or exists (
        select 1
        from public.teacher t
        where t.user_id = auth.uid()
      )
      or exists (
        select 1
        from public.principal p
        where p.user_id = auth.uid()
      )
    );
$$;
