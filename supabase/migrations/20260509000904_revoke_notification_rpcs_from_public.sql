-- -----------------------------------------------------------
-- Security fix: revoke EXECUTE on notification RPCs from PUBLIC.
--
-- PostgreSQL grants EXECUTE to PUBLIC by default when a function is
-- created.  The original migration only added GRANT TO authenticated
-- without revoking from PUBLIC, which allowed the anon (unauthenticated)
-- role to invoke these RPCs.  Although every query is gated on
-- auth.uid() (returning no data for unauthenticated callers), exposure
-- to unauthenticated invocation is unnecessary and should be removed.
-- -----------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.my_notifications(int)            FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mark_notification_read(uuid)     FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mark_all_notifications_read()    FROM PUBLIC;
