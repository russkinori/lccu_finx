-- Adds current_user_role_names() so every authenticated user can resolve
-- their own roles at login without requiring admin access.
-- This is the self-scoped counterpart to admin_user_role_names(p_user_id).

create or replace function public.current_user_role_names()
returns text[]
language sql
stable
security definer
set search_path to 'pg_catalog', 'public'
as $$
  -- SECURITY DEFINER (owned by postgres) already bypasses RLS.
  -- Intentionally no `set row_security to off` — the WHERE clause
  -- hard-scopes results to the calling user only; no user-controlled
  -- parameters means no injection risk.
  select coalesce(
    array_agg(r.role_name order by r.role_name),
    '{}'::text[]
  )
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = auth.uid();
$$;

grant execute on function public.current_user_role_names() to authenticated;
