-- Fix: mutable search_path on handle_new_auth_user trigger function.
-- The linter flags functions that run with the caller's search_path because a
-- malicious schema object placed earlier in the path could intercept calls to
-- pg_catalog or public builtins (search_path injection).
--
-- ALTER FUNCTION … SET search_path pins the path for every invocation without
-- requiring the function body to be rewritten or the trigger to be recreated.

alter function public.handle_new_auth_user()
  set search_path to 'pg_catalog', 'public';
