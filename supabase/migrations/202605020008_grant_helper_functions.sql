-- Grant EXECUTE on all helper/predicate functions used in RLS policies and
-- SECURITY DEFINER RPCs to the authenticated role.
-- Without these grants, any RLS policy that calls e.g. is_admin() will throw
-- "permission denied for function is_admin" when evaluated for a non-postgres role.

grant execute on function public.is_admin()                          to authenticated;
grant execute on function public.is_admin(uuid)                      to authenticated;
grant execute on function public.is_teller()                         to authenticated;
grant execute on function public.has_role(text)                      to authenticated;
grant execute on function public.is_me(uuid)                         to authenticated;
grant execute on function public.is_guardian_of_student(uuid)        to authenticated;
grant execute on function public.is_teacher_of_student(uuid)         to authenticated;
grant execute on function public.is_principal_of_student(uuid)       to authenticated;
grant execute on function public.is_student_self(uuid)               to authenticated;
grant execute on function public.is_current_guardian_of(uuid)        to authenticated;
grant execute on function public.can_view_guardian_as_staff(uuid)    to authenticated;
grant execute on function public.current_app_user_id()               to authenticated;
grant execute on function public.current_teacher_id()                to authenticated;
grant execute on function public.current_teacher_school_id()         to authenticated;
grant execute on function public.current_principal_id()              to authenticated;
grant execute on function public.current_principal_school_id()       to authenticated;
grant execute on function public.current_teller_id()                 to authenticated;
grant execute on function public.current_teller_branch_id()          to authenticated;
grant execute on function public.fn_current_user_id()                to authenticated;
grant execute on function public.fn_current_teacher_id()             to authenticated;
grant execute on function public.fn_current_guardian_id()            to authenticated;
