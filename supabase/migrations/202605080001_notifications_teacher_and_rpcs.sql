-- =============================================================
-- Migration: teacher notifications + notification RPCs
--
-- Principles applied:
--   • Open/Closed  – extends notify_withdrawal_change and
--     request_withdrawal WITHOUT touching their existing logic
--   • Single Responsibility – each function does exactly one job
--   • DRY  – teacher lookup is inlined; re-uses existing helpers
--   • Separation of Concerns – DB layer owns all notification writes;
--     Flutter layer only reads via RPCs
-- =============================================================

-- -----------------------------------------------------------
-- 1. Extend notify_withdrawal_change to also notify the teacher
--    when a withdrawal status changes (Approved, Declined, etc.)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_withdrawal_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public' -- NOSONAR(plsql:S1192)
AS $function$
DECLARE
  c_entity_type  CONSTANT text := 'withdrawal_req';
  c_notif_title  CONSTANT text := 'Withdrawal Update';
  v_student_user uuid;
  v_teacher_user uuid;
  v_student_name text;
  rec            record;
  v_title        text;
  v_msg          text;
BEGIN
  IF tg_op <> 'UPDATE'
     OR new.status_id IS NULL
     OR new.status_id = old.status_id
  THEN
    RETURN new;
  END IF;

  -- Resolve student's auth user_id
  SELECT u.user_id
    INTO v_student_user
    FROM public.student s
    JOIN public."user" u ON u.user_id = s.user_id
   WHERE s.student_id = new.student_id;

  -- Resolve student's display name for richer teacher message
  SELECT trim(coalesce(u.first_name,'') || ' ' || coalesce(u.last_name,''))
    INTO v_student_name
    FROM public.student s
    JOIN public."user" u ON u.user_id = s.user_id
   WHERE s.student_id = new.student_id;

  -- Resolve the teacher who owns this class / school (teacher_id on withdrawal_req if present,
  -- else the teacher linked to the student's current class)
  SELECT u.user_id
    INTO v_teacher_user
    FROM public.student s
    JOIN public.student_class sc
      ON sc.student_id = s.student_id
     AND sc.start_date  <= current_date
     AND (sc.end_date IS NULL OR sc.end_date >= current_date)
    JOIN public.teacher t ON t.school_id = s.school_id
    JOIN public."user"  u ON u.user_id   = t.user_id
   WHERE s.student_id = new.student_id
   ORDER BY sc.start_date DESC
   LIMIT 1;

  SELECT name INTO v_title FROM public.tx_stat WHERE status_id = new.status_id;
  v_msg := format('Withdrawal %s: $%s', v_title, coalesce(new.amount, 0));

  -- Notify student
  IF v_student_user IS NOT NULL THEN
    INSERT INTO public.notification(user_id, title, message, entity_type, entity_id)
    VALUES (v_student_user, c_notif_title, v_msg, c_entity_type, new.request_id);
  END IF;

  -- Notify guardians
  FOR rec IN
    SELECT g.user_id
      FROM public.student_guardian sg
      JOIN public.guardian g ON g.guardian_id = sg.guardian_id
     WHERE sg.student_id = new.student_id
  LOOP
    INSERT INTO public.notification(user_id, title, message, entity_type, entity_id)
    VALUES (rec.user_id, c_notif_title, v_msg, c_entity_type, new.request_id);
  END LOOP;

  -- Notify teacher (new — Open/Closed: added after existing paths, no changes above)
  IF v_teacher_user IS NOT NULL THEN
    INSERT INTO public.notification(user_id, title, message, entity_type, entity_id)
    VALUES (
      v_teacher_user,
      c_notif_title,
      format('Withdrawal for %s %s: $%s', v_student_name, v_title, coalesce(new.amount, 0)),
      c_entity_type,
      new.request_id
    );
  END IF;

  RETURN new;
END;
$function$;

-- -----------------------------------------------------------
-- 2. Extend request_withdrawal to also notify the teacher
--    when a new withdrawal request is submitted.
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_withdrawal(
  p_student_id uuid,
  p_amount     numeric,
  p_reason     text    DEFAULT NULL,
  p_notes      text    DEFAULT NULL
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public' -- NOSONAR(plsql:S1192)
AS $function$
DECLARE
  c_entity_type  CONSTANT text := 'withdrawal_req';
  c_notif_title  CONSTANT text := 'Withdrawal Request';
  v_request_id   uuid;
  v_pending      uuid;
  v_account_id   uuid;
  v_balance      numeric;
  v_student_name text;
  v_teacher_user uuid;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid amount';
  END IF;

  IF NOT (
    public.is_admin()
    OR EXISTS (
      SELECT 1
        FROM public.student s
       WHERE s.student_id = p_student_id
         AND s.user_id = auth.uid()
    )
  ) THEN
    RAISE EXCEPTION 'Not permitted' USING ERRCODE = '42501';
  END IF;

  SELECT sa.account_id, COALESCE(sa.closing_bal, 0)::numeric
    INTO v_account_id, v_balance
    FROM public.student s
    JOIN public.student_acc sa ON sa.student_id = s.student_id
   WHERE s.student_id = p_student_id
     AND COALESCE(sa.is_active, true) = true
   ORDER BY sa.created_at DESC NULLS LAST
   LIMIT 1;

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'Active account not found';
  END IF;

  IF p_amount > v_balance THEN
    RAISE EXCEPTION 'Amount exceeds available balance';
  END IF;

  SELECT public.id_of_tx_stat('PENDING') INTO v_pending;

  INSERT INTO public.withdrawal_req (
    student_id, account_id, amount, status_id,
    requested_at, notes, reason, updated_by
  )
  VALUES (
    p_student_id, v_account_id, p_amount, v_pending,
    now(), p_notes, p_reason, auth.uid()
  )
  RETURNING request_id INTO v_request_id;

  -- Resolve student name for messages
  SELECT trim(coalesce(u.first_name,'') || ' ' || coalesce(u.last_name,''))
    INTO v_student_name
    FROM public.student s
    JOIN public."user" u ON u.user_id = s.user_id
   WHERE s.student_id = p_student_id;

  -- Notify guardians (existing behaviour preserved)
  INSERT INTO public.notification (user_id, title, message, entity_type, entity_id)
  SELECT
    g.user_id,
    c_notif_title,
    format('Please review a withdrawal request for %s.', v_student_name),
    c_entity_type,
    v_request_id
  FROM public.student_guardian sg
  JOIN public.guardian g ON g.guardian_id = sg.guardian_id
  WHERE sg.student_id = p_student_id;

  -- Notify teacher (new — Open/Closed: appended after guardian block)
  SELECT u.user_id
    INTO v_teacher_user
    FROM public.student s
    JOIN public.student_class sc
      ON sc.student_id = s.student_id
     AND sc.start_date  <= current_date
     AND (sc.end_date IS NULL OR sc.end_date >= current_date)
    JOIN public.teacher t ON t.school_id = s.school_id
    JOIN public."user"  u ON u.user_id   = t.user_id
   WHERE s.student_id = p_student_id
   ORDER BY sc.start_date DESC
   LIMIT 1;

  IF v_teacher_user IS NOT NULL THEN
    INSERT INTO public.notification (user_id, title, message, entity_type, entity_id)
    VALUES (
      v_teacher_user,
      c_notif_title,
      format('%s has submitted a withdrawal request for $%s.', v_student_name, p_amount),
      c_entity_type,
      v_request_id
    );
  END IF;

  RETURN v_request_id;
END;
$function$;

-- -----------------------------------------------------------
-- 3. RPC: my_notifications — current user's inbox (newest first)
--    Single Responsibility: only reads notifications for caller
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_notifications(p_limit int DEFAULT 50)
 RETURNS TABLE(
   notification_id uuid,
   title           text,
   message         text,
   is_read         boolean,
   entity_type     text,
   entity_id       uuid,
   created_at      timestamptz
 )
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public' -- NOSONAR(plsql:S1192)
AS $function$
  SELECT
    notification_id,
    title,
    message,
    is_read,
    entity_type,
    entity_id,
    created_at
  FROM public.notification
  WHERE user_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 50), 1);
$function$;

REVOKE EXECUTE ON FUNCTION public.my_notifications(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_notifications(int) TO authenticated;

-- -----------------------------------------------------------
-- 4. RPC: mark_notification_read — marks one notification read
--    (KISS: intentionally minimal, no bulk-read for now)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public' -- NOSONAR(plsql:S1192)
AS $function$
  UPDATE public.notification
     SET is_read = true
   WHERE notification_id = p_notification_id
     AND user_id          = auth.uid();
$function$;

REVOKE EXECUTE ON FUNCTION public.mark_notification_read(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;

-- -----------------------------------------------------------
-- 5. RPC: mark_all_notifications_read — marks all unread as read
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public' -- NOSONAR(plsql:S1192)
AS $function$
  UPDATE public.notification
     SET is_read = true
   WHERE user_id  = auth.uid()
     AND is_read  = false;
$function$;

REVOKE EXECUTE ON FUNCTION public.mark_all_notifications_read() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;
