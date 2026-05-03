-- Baseline functions: all public schema functions.
-- Uses CREATE OR REPLACE FUNCTION so safe to re-run on an existing DB.
-- Grouped by category for readability.
-- Note: some functions are also updated by later phase 2/3 migrations;
--       those migrations take precedence via CREATE OR REPLACE.


-- ============================================================
-- Auth/RLS helper predicates used in RLS policies and RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_view_guardian_as_staff(p_guardian_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with sg as (
    select sg.student_id
    from public.student_guardian sg
    where sg.guardian_id = p_guardian_id
  )
  select exists (
    select 1
    from sg
    join public.student s using (student_id)
    where
      -- teacher in same school
      exists (
        select 1 from public.teacher t
        where t.user_id = auth.uid()
          and t.school_id = s.school_id
      )
      or
      -- principal in same school
      exists (
        select 1 from public.principal p
        where p.user_id = auth.uid()
          and p.school_id = s.school_id
      )
  );
$function$;

CREATE OR REPLACE FUNCTION public.current_app_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select u.user_id from public."user" u where u.user_id = auth.uid() limit 1;$function$;

CREATE OR REPLACE FUNCTION public.current_principal_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select p.principal_id
  from public.principal p
  where p.user_id = (select auth.uid())
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.current_principal_school_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select p.school_id
  from public.principal p
  where p.user_id = (select auth.uid())
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.current_school_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$SELECT x.school_id FROM (
    SELECT t.school_id
    FROM public.teacher t
    JOIN public.user u ON u.user_id = t.user_id
    WHERE u.user_id = auth.uid()
    UNION
    SELECT p.school_id
    FROM public.principal p
    JOIN public.user u ON u.user_id = p.user_id
    WHERE u.user_id = auth.uid()
  ) x LIMIT 1$function$;

CREATE OR REPLACE FUNCTION public.current_teacher_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select t.teacher_id
  from public.teacher t
  where t.user_id = (select auth.uid())
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.current_teacher_school_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select t.school_id
  from public.teacher t
  where t.user_id = (select auth.uid())
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.current_teller_branch_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select t.branch_id
  from public.teller t
  where t.user_id = (select auth.uid())
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.current_teller_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select t.teller_id
  from public.teller t
  where t.user_id = (select auth.uid())
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.fn_current_guardian_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select g.guardian_id
  from public.guardian g
  join public."user" u on u.user_id = g.user_id
  where u.user_id = auth.uid()
  limit 1$function$;

CREATE OR REPLACE FUNCTION public.fn_current_teacher_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select t.teacher_id
  from public.teacher t
  join public."user" u on u.user_id = t.user_id
  where u.user_id = auth.uid()
  limit 1$function$;

CREATE OR REPLACE FUNCTION public.fn_current_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select u.user_id
  from public."user" u
  where u.user_id = auth.uid()
  limit 1$function$;

CREATE OR REPLACE FUNCTION public.has_role(role_name text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_role ur
    JOIN public.role r ON r.role_id = ur.role_id
    WHERE ur.user_id = auth.uid()
      AND lower(r.role_name) = lower(role_name)
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_admin(uid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_role ur
    JOIN public.role r ON r.role_id = ur.role_id
    WHERE ur.user_id = uid
      AND lower(r.role_name) = 'admin'
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select exists (
    select 1
    from public.admin a
    where a.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_current_guardian_of(p_student_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select exists (
    select 1
    from public.student_guardian sg
    join public.guardian g on g.guardian_id = sg.guardian_id
    where sg.student_id = p_student_id
      and g.user_id = current_app_user_id()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_guardian_of_student(p_student_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select exists (
    select 1
    from public.student_guardian sg
    join public.guardian g on g.guardian_id = sg.guardian_id
    where sg.student_id = p_student_id
      and g.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_me(p_user_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT p_user_id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.is_principal_of_student(p_student_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select exists (
    select 1
    from public.student s
    join public.principal p on p.school_id = s.school_id
    where s.student_id = p_student_id
      and p.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_student_self(p_student_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.student s
    WHERE s.student_id = p_student_id
      AND s.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_teacher_of_student(p_student_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select exists (
    select 1
    from public.student s
    join public.teacher t on t.school_id = s.school_id
    where s.student_id = p_student_id
      and t.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_teller()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select exists (
    select 1
    from public.teller t
    where t.user_id = (select auth.uid())
  );
$function$;

-- ============================================================
-- Trigger functions (invoked by triggers below)
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_txn_sync_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  -- If account_id missing, derive from student_id
  if new.account_id is null and new.student_id is not null then
    select sa.account_id into new.account_id
    from public.student_acc sa
    where sa.student_id = new.student_id
      and coalesce(sa.is_active, true) = true
    order by sa.created_at desc nulls last
    limit 1;
  end if;

  -- If student_id missing, derive from account_id
  if new.student_id is null and new.account_id is not null then
    select sa.student_id into new.student_id
    from public.student_acc sa
    where sa.account_id = new.account_id
    limit 1;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  -- Example: Assign a default role to a new user
  insert into public.user_roles (user_id, role)
  values (new.user_id, 'student');
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.id_of_tx_stat(p_name text)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT status_id FROM public.tx_stat WHERE name = p_name LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION public.id_of_tx_type(p_name text)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT type_id FROM public.tx_type WHERE name = p_name LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION public.notify_withdrawal_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_student_user uuid;
  rec record;
  v_title text;
  v_msg   text;
begin
  if tg_op <> 'UPDATE' or new.status_id is null or new.status_id = old.status_id then
    return new;
  end if;

  select u.user_id into v_student_user
  from public.student s join public."user" u on u.user_id = s.user_id
  where s.student_id = new.student_id;

  select name into v_title from public.tx_stat where status_id = new.status_id;
  v_msg := format('Withdrawal %s: $%s', v_title, coalesce(new.amount, 0));

  -- student
  if v_student_user is not null then
    insert into public.notification(user_id, title, message, entity_type, entity_id)
    values (v_student_user, 'Withdrawal Update', v_msg, 'withdrawal_req', new.request_id);
  end if;

  -- guardians
  for rec in
    select g.user_id
    from public.student_guardian sg
    join public.guardian g on g.guardian_id = sg.guardian_id
    where sg.student_id = new.student_id
  loop
    insert into public.notification(user_id, title, message, entity_type, entity_id)
    values (rec.user_id, 'Withdrawal Update', v_msg, 'withdrawal_req', new.request_id);
  end loop;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.recalc_batches_for_deposit_event(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  r record;
  v_batch_deposited numeric;
  v_expected numeric;
  v_new_status text;
BEGIN
  FOR r IN
    SELECT DISTINCT eb.batch_id
    FROM public.cu_dep_event_batch eb
    WHERE eb.dep_event_id = p_event_id
  LOOP
    SELECT COALESCE(b.expected_amount, 0)
    INTO v_expected
    FROM public.dep_batch b
    WHERE b.batch_id = r.batch_id;

    SELECT COALESCE(SUM(eb2.applied_amount), 0)::numeric
    INTO v_batch_deposited
    FROM public.cu_dep_event_batch eb2
    JOIN public.cu_dep_event e
      ON e.dep_event_id = eb2.dep_event_id
    WHERE eb2.batch_id = r.batch_id
      AND e.status = 'Posted';

    v_new_status :=
      CASE
        WHEN COALESCE(v_expected, 0) <= 0 THEN NULL
        WHEN v_batch_deposited >= v_expected THEN 'DEPOSITED'
        WHEN v_batch_deposited > 0 THEN 'PARTIALLY_DEPOSITED'
        ELSE 'SUBMITTED'
      END;

    IF v_new_status IS NOT NULL THEN
      UPDATE public.dep_batch b
      SET status = v_new_status
      WHERE b.batch_id = r.batch_id
        AND b.status IS DISTINCT FROM v_new_status;
    END IF;

    UPDATE public.teacher_coll tc
    SET
      status = CASE
        WHEN COALESCE(v_expected, 0) <= 0 THEN 'NO_DEPOSIT_REQUIRED'
        WHEN v_batch_deposited >= v_expected THEN 'DEPOSITED'
        WHEN v_batch_deposited > 0 THEN 'PARTIALLY_DEPOSITED'
        ELSE 'IN_BATCH'
      END,
      updated_at = now()
    FROM public.dep_item di
    WHERE di.collection_id = tc.collection_id
      AND di.batch_id = r.batch_id;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.recalc_cu_dep_event_batch(p_dep_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  -- remove existing allocations for this event
  DELETE FROM public.cu_dep_event_batch
  WHERE dep_event_id = p_dep_event_id;

  -- rebuild from event_item -> dep_item (collection -> batch)
  INSERT INTO public.cu_dep_event_batch (dep_event_id, batch_id, applied_amount)
  SELECT
    i.dep_event_id,
    di.batch_id,
    SUM(i.applied_amount)::numeric
  FROM public.cu_dep_event_item i
  JOIN public.dep_item di
    ON di.collection_id = i.collection_id
  WHERE i.dep_event_id = p_dep_event_id
  GROUP BY i.dep_event_id, di.batch_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.recalc_deposit_batch_expected(p_batch_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  update public.dep_batch b
  set expected_amount = coalesce(x.total, 0)
  from (
    select batch_id, sum(amount)::numeric as total
    from public.dep_item
    where batch_id = p_batch_id
    group by batch_id
  ) x
  where b.batch_id = p_batch_id
    and b.batch_id = x.batch_id;

  -- if no rows exist, force to 0
  update public.dep_batch
  set expected_amount = 0
  where batch_id = p_batch_id
    and not exists (select 1 from public.dep_item where batch_id = p_batch_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.recalc_school_closing_balance(p_school_id uuid, p_reason text DEFAULT 'AUTOMATED_RECALC'::text, p_source_table text DEFAULT NULL::text, p_source_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_opening_bal numeric := 0;
  v_total_deposits numeric := 0;
  v_total_payouts numeric := 0;
  v_old_balance numeric := 0;
  v_new_balance numeric := 0;
BEGIN
  IF p_school_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(opening_bal, 0), COALESCE(closing_bal, 0)
  INTO v_opening_bal, v_old_balance
  FROM public.school_acc
  WHERE school_id = p_school_id
  LIMIT 1;

  SELECT COALESCE(SUM(amount), 0)::numeric
  INTO v_total_deposits
  FROM public.cu_dep_event
  WHERE school_id = p_school_id
    AND status = 'Posted';

  SELECT COALESCE(SUM(amount), 0)::numeric
  INTO v_total_payouts
  FROM public.cu_payout
  WHERE school_id = p_school_id;

  v_new_balance :=
    COALESCE(v_opening_bal, 0)
    + COALESCE(v_total_deposits, 0)
    - COALESCE(v_total_payouts, 0);

  IF v_new_balance IS DISTINCT FROM v_old_balance THEN
    INSERT INTO public.balance_audit (
      school_id,
      old_balance,
      new_balance,
      delta,
      reason,
      source_table,
      source_id
    )
    VALUES (
      p_school_id,
      v_old_balance,
      v_new_balance,
      v_new_balance - v_old_balance,
      p_reason,
      p_source_table,
      p_source_id
    );

    UPDATE public.school_acc
    SET
      closing_bal = v_new_balance,
      updated_at = now()
    WHERE school_id = p_school_id;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.recalc_school_deposit_status(p_school_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  r record;
  v_deposited numeric;
  v_new_status text;
BEGIN
  FOR r IN
    SELECT
      b.batch_id,
      COALESCE(b.expected_amount, 0)::numeric AS expected_amount
    FROM public.dep_batch b
    WHERE b.school_id = p_school_id
      AND b.status <> 'CANCELLED'
  LOOP
    SELECT COALESCE(SUM(eb.applied_amount) FILTER (WHERE e.status = 'Posted'), 0)::numeric
    INTO v_deposited
    FROM public.cu_dep_event_batch eb
    JOIN public.cu_dep_event e
      ON e.dep_event_id = eb.dep_event_id
    WHERE eb.batch_id = r.batch_id;

    v_new_status :=
      CASE
        WHEN r.expected_amount <= 0 THEN NULL
        WHEN v_deposited >= r.expected_amount THEN 'DEPOSITED'
        WHEN v_deposited > 0 THEN 'PARTIALLY_DEPOSITED'
        ELSE NULL
      END;

    IF v_new_status IS NOT NULL THEN
      UPDATE public.dep_batch
      SET status = v_new_status
      WHERE batch_id = r.batch_id
        AND status IS DISTINCT FROM v_new_status;
    END IF;

    UPDATE public.teacher_coll tc
    SET
      status = CASE
        WHEN r.expected_amount <= 0 THEN 'NO_DEPOSIT_REQUIRED'
        WHEN v_deposited >= r.expected_amount THEN 'DEPOSITED'
        WHEN v_deposited > 0 THEN 'PARTIALLY_DEPOSITED'
        ELSE 'IN_BATCH'
      END,
      updated_at = now()
    FROM public.dep_item di
    WHERE di.batch_id = r.batch_id
      AND di.collection_id = tc.collection_id;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.recalc_student_closing_balance(p_account_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_opening_bal numeric := 0;
  v_deposits numeric := 0;
  v_withdrawals numeric := 0;
  v_posted_status_id uuid;
BEGIN
  -- Dynamically lookup POSTED status ID
  SELECT status_id INTO v_posted_status_id
  FROM public.tx_stat
  WHERE UPPER(name) = 'POSTED'
  LIMIT 1;

  IF v_posted_status_id IS NULL THEN
    RAISE EXCEPTION 'POSTED status not found in tx_stat table';
  END IF;

  -- Get opening balance
  SELECT COALESCE(opening_bal, 0)
  INTO v_opening_bal
  FROM public.student_acc
  WHERE account_id = p_account_id;

  IF NOT FOUND THEN
    RETURN; -- Account doesn't exist
  END IF;

  -- Sum POSTED DEPOSITS from transactions table
  SELECT COALESCE(SUM(t.amount), 0)
  INTO v_deposits
  FROM public.transactions t
  JOIN public.tx_type tt ON tt.type_id = t.type_id
  WHERE t.account_id = p_account_id
    AND t.status_id = v_posted_status_id
    AND UPPER(tt.name) = 'DEPOSIT';

  -- Sum POSTED WITHDRAWALS from transactions table
  SELECT COALESCE(SUM(t.amount), 0)
  INTO v_withdrawals
  FROM public.transactions t
  JOIN public.tx_type tt ON tt.type_id = t.type_id
  WHERE t.account_id = p_account_id
    AND t.status_id = v_posted_status_id
    AND UPPER(tt.name) = 'WITHDRAWAL';

  -- Update the closing balance: opening + deposits - withdrawals
  UPDATE public.student_acc
  SET closing_bal = v_opening_bal + v_deposits - v_withdrawals,
      updated_at = now()
  WHERE account_id = p_account_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.recalc_teacher_coll_for_week(p_teacher_id uuid, p_tx_date date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_school_id      uuid;
  v_week_start     date;
  v_week_end       date;
  v_amount         numeric;
  v_collection_id  uuid;
  v_status_default text := 'PENDING_TELLER_SCAN';
  v_slip_code      text;
begin
  if p_teacher_id is null or p_tx_date is null then
    return;
  end if;

  -- teacher -> school
  select school_id
    into v_school_id
  from public.teacher
  where teacher_id = p_teacher_id
  limit 1;

  if v_school_id is null then
    return;
  end if;

  -- Sunday-based week:
  -- extract(dow) returns 0=Sunday .. 6=Saturday
  v_week_start := (p_tx_date - extract(dow from p_tx_date)::int)::date;
  v_week_end   := v_week_start + 6;

  -- Net cash for Sun–Sat:
  -- sum(DEPOSIT) - sum(WITHDRAWAL), only POSTED
  select
    coalesce(
      sum(
        case
          when tt.name = 'DEPOSIT'    then t.amount
          when tt.name = 'WITHDRAWAL' then -t.amount
          else 0
        end
      ) filter (where ts.name = 'POSTED'),
      0
    )::numeric
  into v_amount
  from public.transactions t
  join public.tx_type tt on tt.type_id = t.type_id
  join public.tx_stat ts on ts.status_id = t.status_id
  where t.teacher_id = p_teacher_id
    and (t.created_at::date between v_week_start and v_week_end);

  -- Find existing weekly row
  select collection_id
    into v_collection_id
  from public.teacher_coll
  where teacher_id = p_teacher_id
    and school_id  = v_school_id
    and week_start = v_week_start
    and week_end   = v_week_end
  limit 1;

  if v_collection_id is null then
    -- generate a simple 16-char slip code without gen_random_bytes()
    v_slip_code := substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);

    insert into public.teacher_coll (
      collection_id,
      school_id,
      teacher_id,
      week_start,
      week_end,
      amount,
      slip_code,
      slip_hash,
      status,
      created_at
    )
    values (
      gen_random_uuid(),
      v_school_id,
      p_teacher_id,
      v_week_start,
      v_week_end,
      v_amount,
      v_slip_code,
      null,
      v_status_default,
      now()
    );
  else
    update public.teacher_coll
    set amount     = v_amount,
        updated_at = now()
    where collection_id = v_collection_id;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.recompute_student_closing_bal(p_account_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  -- Simply delegate to the corrected function for consistency
  PERFORM public.recalc_student_closing_balance(p_account_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$function$;

-- ============================================================
-- Utility / "me" identity RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.backfill_cu_dep_event_allocations(p_school_id uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  ev record;
  eb record;
BEGIN
  /*
    Non-FIFO, batch-driven backfill.

    Preconditions:
    - cu_dep_event_batch must be populated for events you want to allocate.
    - dep_item links collections to batches.

    Behavior:
    - If p_school_id is NULL: rebuild allocations for ALL schools.
    - If p_school_id is NOT NULL: rebuild allocations ONLY for that school.
  */

  -- 1) Delete ONLY items in-scope
  IF p_school_id IS NULL THEN
    DELETE FROM public.cu_dep_event_item;
  ELSE
    DELETE FROM public.cu_dep_event_item i
    USING public.cu_dep_event e
    WHERE e.dep_event_id = i.dep_event_id
      AND e.school_id = p_school_id;
  END IF;

  -- 2) Process events in-scope (Posted only)
  FOR ev IN
    SELECT e.dep_event_id, e.school_id, e.posted_at
    FROM public.cu_dep_event e
    WHERE e.status = 'Posted'
      AND (p_school_id IS NULL OR e.school_id = p_school_id)
    ORDER BY e.posted_at ASC, e.dep_event_id ASC
  LOOP
    -- Must have batch mappings; otherwise skip (no guessing = no FIFO)
    IF NOT EXISTS (
      SELECT 1
      FROM public.cu_dep_event_batch eb0
      WHERE eb0.dep_event_id = ev.dep_event_id
    ) THEN
      CONTINUE;
    END IF;

    -- 3) For each batch allocation row, allocate into collections in that batch (pro-rata)
    FOR eb IN
      SELECT eb1.batch_id, eb1.applied_amount::numeric AS applied_amount
      FROM public.cu_dep_event_batch eb1
      WHERE eb1.dep_event_id = ev.dep_event_id
      ORDER BY eb1.batch_id ASC
    LOOP

      WITH coll AS (
        SELECT
          tc.collection_id,
          tc.school_id,
          tc.amount::numeric AS collected_amount
        FROM public.dep_item di
        JOIN public.teacher_coll tc
          ON tc.collection_id = di.collection_id
        WHERE di.batch_id = eb.batch_id
          AND tc.school_id = ev.school_id
          AND tc.amount > 0
      ),
      outstanding AS (
        SELECT
          c.collection_id,
          GREATEST(
            c.collected_amount
            - COALESCE((
                SELECT SUM(i.applied_amount)
                FROM public.cu_dep_event_item i
                JOIN public.cu_dep_event e2
                  ON e2.dep_event_id = i.dep_event_id
                 AND e2.status = 'Posted'
                WHERE i.collection_id = c.collection_id
              ), 0),
            0
          ) AS outstanding_amount
        FROM coll c
      ),
      totals AS (
        SELECT COALESCE(SUM(outstanding_amount),0)::numeric AS total_outstanding
        FROM outstanding
        WHERE outstanding_amount > 0
      ),
      prorata AS (
        SELECT
          o.collection_id,
          o.outstanding_amount,
          (eb.applied_amount * (o.outstanding_amount / NULLIF(t.total_outstanding,0)))::numeric AS raw_apply
        FROM outstanding o
        CROSS JOIN totals t
        WHERE o.outstanding_amount > 0
      ),
      rounded AS (
        SELECT
          collection_id,
          outstanding_amount,
          LEAST(outstanding_amount, ROUND(raw_apply, 2))::numeric AS apply_amount
        FROM prorata
      ),
      sum_rounded AS (
        SELECT COALESCE(SUM(apply_amount),0)::numeric AS s
        FROM rounded
      ),
      adjusted AS (
        SELECT
          r.collection_id,
          CASE
            WHEN r.collection_id = (
              SELECT collection_id
              FROM rounded
              ORDER BY collection_id
              LIMIT 1
            )
            THEN LEAST(
              r.outstanding_amount,
              r.apply_amount + (eb.applied_amount - (SELECT s FROM sum_rounded))
            )
            ELSE r.apply_amount
          END AS final_apply
        FROM rounded r
      )
      INSERT INTO public.cu_dep_event_item(dep_event_id, collection_id, applied_amount)
      SELECT ev.dep_event_id, collection_id, final_apply
      FROM adjusted
      WHERE final_apply > 0;

    END LOOP;
  END LOOP;

END;
$function$;

CREATE OR REPLACE FUNCTION public.current_user_role_names()
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select coalesce(
    array_agg(r.role_name order by r.role_name),
    '{}'::text[]
  )
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.ensure_student_account(p_student_id uuid, p_school_id uuid, p_opening_bal numeric DEFAULT 0, p_acc_number text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_account_id uuid;
begin
  select sa.account_id
    into v_account_id
  from public.student_acc sa
  where sa.student_id = p_student_id
    and coalesce(sa.is_active,true) = true
  order by sa.created_at desc nulls last
  limit 1;

  if v_account_id is not null then
    return v_account_id;
  end if;

  insert into public.student_acc(
    account_id, student_id, school_id, opening_bal, created_at, updated_at, is_active, acc_number, closing_bal
  )
  values (
    gen_random_uuid(), p_student_id, p_school_id, coalesce(p_opening_bal,0), now(), now(), true,
    nullif(p_acc_number, ''), 0
  )
  returning account_id into v_account_id;

  -- your existing recompute logic will fill closing_bal via triggers; call explicitly as well:
  perform public.recalc_student_closing_balance(v_account_id);

  return v_account_id;
end
$function$;

CREATE OR REPLACE FUNCTION public.f_me()
 RETURNS SETOF "user"
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT *
  FROM public."user" u
  WHERE u.user_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION public.f_me_guardian()
 RETURNS SETOF guardian
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT g.* FROM public.guardian g WHERE g.user_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION public.f_me_role()
 RETURNS TABLE(role_id uuid, role_name text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT r.role_id, r.role_name
  FROM public.user_role ur
  JOIN public.role r ON r.role_id = ur.role_id
  WHERE ur.user_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION public.f_me_student()
 RETURNS SETOF student
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT s.*
  FROM public.student s
  WHERE s.user_id = auth.uid()
  ORDER BY s.created_at DESC
  LIMIT 1
$function$;

CREATE OR REPLACE FUNCTION public.f_me_teacher()
 RETURNS SETOF teacher
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT t.* FROM public.teacher t WHERE t.user_id = auth.uid()
$function$;

-- ============================================================
-- Admin RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_apply_user_profile(p_mode text, p_auth_user_id uuid, p_role text DEFAULT NULL::text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app_admin'
AS $function$DECLARE
  v_mode text := lower(coalesce(trim(p_mode), ''));
  v_role text := lower(coalesce(trim(p_role), coalesce_text_path(p_payload, ARRAY['role','role_name','roleName'])));

  v_email      text := coalesce_text_path(p_payload, ARRAY['email']);
  v_first_name text := coalesce_text_path(p_payload, ARRAY['first_name','firstName']);
  v_last_name  text := coalesce_text_path(p_payload, ARRAY['last_name','lastName']);

  -- NEW: gender + title handling
  v_gender_name text := nullif(trim(coalesce_text_path(p_payload, ARRAY['gender'])), '');
  v_gender_id   uuid;
  v_title       text := nullif(trim(coalesce_text_path(p_payload, ARRAY['title'])), '');

  v_school_id uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['school_id','schoolId']), 'school_id');
  v_class_id  uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['class_id','classId']), 'class_id');

  -- optional student account inputs
  v_acc_number       text := coalesce_text_path(p_payload, ARRAY['student_account_no','student_account_number','account_number','acc_number','accNumber']);
  v_opening_bal_text text := coalesce_text_path(p_payload, ARRAY['student_account_opening_balance','opening_balance','openingBal','opening_bal']);
  v_opening_bal      numeric;

  -- guardian link inputs
  v_guardian_user_id uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['guardian_user_id','guardianUserId','guardian_id','guardianId']), 'guardian_user_id');
  v_guardian_type_id uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['guardian_type_id','guardianTypeId']), 'guardian_type_id');

  -- dates + contact
  v_enrollment_date   text := coalesce_text_path(p_payload, ARRAY['enrollment_date','enrollmentDate']);
  v_date_of_birth     text := coalesce_text_path(p_payload, ARRAY['date_of_birth','dateOfBirth']);
  v_mobile            text := coalesce_text_path(p_payload, ARRAY['mobile','phone']);
  v_address_line      text := coalesce_text_path(p_payload, ARRAY['address','address_line','addressLine']);
  v_address_district  text := coalesce_text_path(p_payload, ARRAY['address_district','district']);
  v_address_zip       text := coalesce_text_path(p_payload, ARRAY['address_zip','zip']);
  v_is_primary        text := coalesce_text_path(p_payload, ARRAY['guardian_is_primary','guardianIsPrimary']);

  v_enrollment_date_value date;
  v_dob_value date;
  v_guardian_is_primary boolean := true;

  v_user public."user"%ROWTYPE;
  v_role_id uuid;

  v_student public.student%ROWTYPE;
  v_student_class public.student_class%ROWTYPE;
  v_student_class_id uuid;
  v_student_account_id uuid;

  v_guardian_link public.student_guardian%ROWTYPE;
  v_guardian_link_id uuid;
  v_guardian_target public.guardian%ROWTYPE;

  v_guardian_self public.guardian%ROWTYPE;
  v_guardian_address public.address%ROWTYPE;
  v_guardian_address_id uuid;

  v_teacher public.teacher%ROWTYPE;
  v_principal public.principal%ROWTYPE;
  v_teller public.teller%ROWTYPE;
  v_admin public.admin%ROWTYPE;

  -- teller branch input (optional unless creating a teller)
  v_branch_id uuid := try_uuid(
    coalesce_text_path(p_payload, ARRAY['credit_union_id','creditUnionId','branch_id','branchId']),
    'branch_id'
  );

  v_active_class_id uuid;
  v_effective_school_id uuid;
  v_effective_branch_id uuid;

  v_now timestamptz := now();
BEGIN
  IF v_mode NOT IN ('create','update','delete','reactivate') THEN
  RAISE EXCEPTION 'Unsupported admin_apply_user_profile mode: %', p_mode;
END IF;

  SELECT *
  INTO v_user
  FROM public."user"
  WHERE user_id = p_auth_user_id;

  IF v_mode = 'create' THEN
  IF v_email IS NULL THEN
    RAISE EXCEPTION 'Email is required for create';
  END IF;

  IF v_first_name IS NULL OR v_last_name IS NULL THEN
    RAISE EXCEPTION 'first_name and last_name are required for create operations';
  END IF;

ELSIF v_mode IN ('update', 'reactivate') THEN
  -- fall back to existing values when payload is partial
  v_email      := coalesce(v_email, v_user.email);
  v_first_name := coalesce(v_first_name, v_user.first_name);
  v_last_name  := coalesce(v_last_name, v_user.last_name);

  IF v_user.user_id IS NULL AND v_email IS NULL THEN
    RAISE EXCEPTION
      'Email is required for % when no existing public.user row exists',
      v_mode;
  END IF;
END IF;

  IF v_enrollment_date IS NOT NULL THEN
    BEGIN
      v_enrollment_date_value := to_date(v_enrollment_date, 'YYYY-MM-DD');
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Invalid enrollment_date value: "%"', v_enrollment_date;
    END;
  END IF;

  IF v_date_of_birth IS NOT NULL THEN
    BEGIN
      v_dob_value := to_date(v_date_of_birth, 'YYYY-MM-DD');
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Invalid date_of_birth value: "%"', v_date_of_birth;
    END;
  END IF;

  IF v_is_primary IS NOT NULL THEN
    v_guardian_is_primary := lower(v_is_primary) IN ('1','true','t','yes','y');
  END IF;

  IF v_opening_bal_text IS NOT NULL THEN
    BEGIN
      v_opening_bal := (v_opening_bal_text)::numeric;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Invalid opening balance value: "%"', v_opening_bal_text;
    END;
  END IF;

  -- Gender lookup (soft-fail: if unknown, keep NULL / existing)
  IF v_gender_name IS NOT NULL THEN
    SELECT g.gender_id
      INTO v_gender_id
    FROM public.gender g
    WHERE lower(g.name) = lower(v_gender_name)
    LIMIT 1;

    IF v_gender_id IS NULL THEN
      RAISE NOTICE 'Gender "%" not found in gender table; leaving gender_id unchanged', v_gender_name;
    END IF;
  END IF;

  -- DELETE
  IF v_mode = 'delete' THEN
  UPDATE public."user"
     SET is_active = false,
         updated_at = v_now
   WHERE user_id = p_auth_user_id;

  DELETE FROM public.user_role
   WHERE user_id = p_auth_user_id;

  RETURN jsonb_build_object(
    'user_id', p_auth_user_id,
    'deleted', true,
    'soft_deleted', true
  );
END IF;

  -- Upsert public.user (supports reactivate)
IF v_user.user_id IS NULL THEN
  INSERT INTO public."user"(
    user_id,
    email,
    first_name,
    last_name,
    gender_id,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    p_auth_user_id,
    v_email,
    v_first_name,
    v_last_name,
    v_gender_id,
    true,
    v_now,
    v_now
  )
  RETURNING * INTO v_user;
ELSE
  UPDATE public."user"
    SET email      = coalesce(v_email, email),
        first_name = coalesce(v_first_name, first_name),
        last_name  = coalesce(v_last_name, last_name),
        gender_id  = coalesce(v_gender_id, gender_id),
        is_active  = CASE
                       WHEN v_mode = 'reactivate' THEN true
                       ELSE is_active
                     END,
        updated_at = v_now
  WHERE user_id = p_auth_user_id
  RETURNING * INTO v_user;
END IF;

  -- user_role (assumes you have a unique constraint/index on (user_id, role_id) like before)
  IF v_role IS NOT NULL THEN
    SELECT role_id INTO v_role_id
    FROM public.role
    WHERE lower(role_name) = v_role
    LIMIT 1;

    IF v_role_id IS NULL THEN
      RAISE EXCEPTION 'Role "%" not found in public.role', v_role;
    END IF;

    INSERT INTO public.user_role(user_role_id, user_id, role_id, created_at)
    VALUES (gen_random_uuid(), p_auth_user_id, v_role_id, v_now)
    ON CONFLICT (user_id, role_id) DO NOTHING;
  END IF;

  -- STUDENT upsert
  SELECT * INTO v_student
  FROM public.student
  WHERE user_id = p_auth_user_id;

  IF v_student.student_id IS NULL AND v_role = 'student' THEN
    IF v_school_id IS NULL THEN
      RAISE EXCEPTION 'school_id is required when creating a student';
    END IF;

    INSERT INTO public.student(student_id, user_id, school_id, date_of_birth, enrollment_date, created_at, updated_at)
    VALUES (gen_random_uuid(), p_auth_user_id, v_school_id, v_dob_value, coalesce(v_enrollment_date_value, current_date), v_now, v_now)
    RETURNING * INTO v_student;

  ELSIF v_student.student_id IS NOT NULL THEN
    UPDATE public.student
      SET school_id        = coalesce(v_school_id, school_id),
          date_of_birth    = coalesce(v_dob_value, date_of_birth),
          enrollment_date  = coalesce(v_enrollment_date_value, enrollment_date),
          updated_at       = v_now
    WHERE student_id = v_student.student_id
    RETURNING * INTO v_student;
  END IF;

  -- ensure student account
  IF v_student.student_id IS NOT NULL THEN
    v_student_account_id := public.ensure_student_account(
      p_student_id  := v_student.student_id,
      p_school_id   := coalesce(v_school_id, v_student.school_id),
      p_opening_bal := v_opening_bal,
      p_acc_number  := v_acc_number
    );
  END IF;

  -- class link
  IF v_student.student_id IS NOT NULL THEN
    IF v_class_id IS NOT NULL THEN
      SELECT * INTO v_student_class
      FROM public.student_class
      WHERE student_id = v_student.student_id
        AND end_date IS NULL
      ORDER BY start_date DESC
      LIMIT 1;

      IF v_student_class.student_class_id IS NULL THEN
        INSERT INTO public.student_class(student_class_id, student_id, class_id, start_date)
        VALUES (gen_random_uuid(), v_student.student_id, v_class_id, current_date)
        RETURNING * INTO v_student_class;

      ELSIF v_student_class.class_id <> v_class_id THEN
        UPDATE public.student_class
          SET end_date = current_date
        WHERE student_class_id = v_student_class.student_class_id;

        INSERT INTO public.student_class(student_class_id, student_id, class_id, start_date)
        VALUES (gen_random_uuid(), v_student.student_id, v_class_id, current_date)
        RETURNING * INTO v_student_class;
      END IF;
    ELSE
      SELECT * INTO v_student_class
      FROM public.student_class
      WHERE student_id = v_student.student_id
        AND end_date IS NULL
      ORDER BY start_date DESC
      LIMIT 1;
    END IF;

    v_student_class_id := v_student_class.student_class_id;

    -- Link to guardian (optional)
    IF v_guardian_user_id IS NOT NULL THEN
      SELECT * INTO v_guardian_target
      FROM public.guardian
      WHERE user_id = v_guardian_user_id;

      IF v_guardian_target.guardian_id IS NULL THEN
        RAISE EXCEPTION 'Guardian with user_id % not found', v_guardian_user_id;
      END IF;

      SELECT * INTO v_guardian_link
      FROM public.student_guardian
      WHERE student_id = v_student.student_id
        AND guardian_id = v_guardian_target.guardian_id
      LIMIT 1;

      IF v_guardian_link.sg_id IS NULL THEN
        IF v_guardian_type_id IS NULL THEN
          RAISE EXCEPTION 'guardian_type_id is required when linking guardian % to student %',
            v_guardian_user_id, v_student.student_id;
        END IF;

        INSERT INTO public.student_guardian(
          sg_id, student_id, guardian_id, type_id, is_primary, created_at
        ) VALUES (
          gen_random_uuid(), v_student.student_id, v_guardian_target.guardian_id,
          v_guardian_type_id, v_guardian_is_primary, v_now
        ) RETURNING * INTO v_guardian_link;
      ELSE
        UPDATE public.student_guardian
          SET type_id    = coalesce(v_guardian_type_id, type_id),
              is_primary = coalesce(v_guardian_is_primary, is_primary)
        WHERE sg_id = v_guardian_link.sg_id
        RETURNING * INTO v_guardian_link;
      END IF;

      v_guardian_link_id := v_guardian_link.sg_id;
    END IF;
  END IF;

  -- GUARDIAN self upsert (adds title)
  SELECT * INTO v_guardian_self
  FROM public.guardian
  WHERE user_id = p_auth_user_id;

  IF v_role = 'guardian'
     OR v_guardian_self.guardian_id IS NOT NULL
     OR v_mobile IS NOT NULL
     OR v_address_line IS NOT NULL
     OR v_address_district IS NOT NULL
     OR v_address_zip IS NOT NULL
     OR v_title IS NOT NULL THEN

    IF v_guardian_self.guardian_id IS NULL THEN
      INSERT INTO public.guardian(guardian_id, user_id, mobile, title, created_at, updated_at)
      VALUES (gen_random_uuid(), p_auth_user_id, v_mobile, v_title, v_now, v_now)
      RETURNING * INTO v_guardian_self;
    ELSE
      UPDATE public.guardian
        SET mobile     = coalesce(v_mobile, mobile),
            title      = coalesce(v_title, title),
            updated_at = v_now
      WHERE guardian_id = v_guardian_self.guardian_id
      RETURNING * INTO v_guardian_self;
    END IF;

    -- address upsert (unchanged)
    IF v_address_line IS NOT NULL OR v_address_district IS NOT NULL OR v_address_zip IS NOT NULL THEN
      IF v_guardian_self.address_id IS NOT NULL THEN
        SELECT * INTO v_guardian_address
        FROM public.address
        WHERE address_id = v_guardian_self.address_id;
      END IF;

      IF v_guardian_address.address_id IS NULL THEN
        INSERT INTO public.address(address_id, post_off, district, zip, created_at, updated_at)
        VALUES (gen_random_uuid(), v_address_line, v_address_district, v_address_zip, v_now, v_now)
        RETURNING address_id INTO v_guardian_address_id;
      ELSE
        UPDATE public.address
          SET post_off   = coalesce(v_address_line, post_off),
              district   = coalesce(v_address_district, district),
              zip        = coalesce(v_address_zip, zip),
              updated_at = v_now
        WHERE address_id = v_guardian_address.address_id
        RETURNING address_id INTO v_guardian_address_id;
      END IF;

      UPDATE public.guardian
        SET address_id = v_guardian_address_id,
            updated_at = v_now
      WHERE guardian_id = v_guardian_self.guardian_id
      RETURNING * INTO v_guardian_self;
    END IF;
  END IF;

  -- TEACHER upsert (adds title; requires school_id only when creating teacher)
  IF v_role = 'teacher' THEN
    SELECT * INTO v_teacher
    FROM public.teacher
    WHERE user_id = p_auth_user_id;

    IF v_teacher.teacher_id IS NULL THEN
      IF v_school_id IS NULL THEN
        RAISE EXCEPTION 'school_id is required when creating a teacher';
      END IF;

      INSERT INTO public.teacher(teacher_id, user_id, school_id, title, created_at, updated_at)
      VALUES (gen_random_uuid(), p_auth_user_id, v_school_id, v_title, v_now, v_now)
      RETURNING * INTO v_teacher;
    ELSE
      UPDATE public.teacher
        SET school_id  = coalesce(v_school_id, school_id),
            title      = coalesce(v_title, title),
            updated_at = v_now
      WHERE teacher_id = v_teacher.teacher_id
      RETURNING * INTO v_teacher;
    END IF;
  ELSE
    -- still return existing record if it exists
    SELECT * INTO v_teacher FROM public.teacher WHERE user_id = p_auth_user_id LIMIT 1;
  END IF;

  -- PRINCIPAL upsert (adds title; requires school_id only when creating principal)
  IF v_role = 'principal' THEN
    SELECT * INTO v_principal
    FROM public.principal
    WHERE user_id = p_auth_user_id;

    IF v_principal.principal_id IS NULL THEN
      IF v_school_id IS NULL THEN
        RAISE EXCEPTION 'school_id is required when creating a principal';
      END IF;

      INSERT INTO public.principal(principal_id, user_id, school_id, title, created_at, updated_at)
      VALUES (gen_random_uuid(), p_auth_user_id, v_school_id, v_title, v_now, v_now)
      RETURNING * INTO v_principal;
    ELSE
      UPDATE public.principal
        SET school_id  = coalesce(v_school_id, school_id),
            title      = coalesce(v_title, title),
            updated_at = v_now
      WHERE principal_id = v_principal.principal_id
      RETURNING * INTO v_principal;
    END IF;
  ELSE
    SELECT * INTO v_principal FROM public.principal WHERE user_id = p_auth_user_id LIMIT 1;
  END IF;

  -- TELLER upsert (adds title; requires branch_id only when creating teller)
  IF v_role = 'teller' THEN
    SELECT * INTO v_teller
    FROM public.teller
    WHERE user_id = p_auth_user_id;

    IF v_teller.teller_id IS NULL THEN
      IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'credit_union_id (branch_id) is required when creating a teller';
      END IF;

      INSERT INTO public.teller(teller_id, user_id, branch_id, title, created_at, updated_at)
      VALUES (gen_random_uuid(), p_auth_user_id, v_branch_id, v_title, v_now, v_now)
      RETURNING * INTO v_teller;
    ELSE
      -- allow optional branch re-assignment if provided
      UPDATE public.teller
        SET branch_id  = coalesce(v_branch_id, branch_id),
            title      = coalesce(v_title, title),
            updated_at = v_now
      WHERE teller_id = v_teller.teller_id
      RETURNING * INTO v_teller;
    END IF;
  ELSE
    SELECT * INTO v_teller FROM public.teller WHERE user_id = p_auth_user_id LIMIT 1;
  END IF;

  -- ADMIN upsert (adds title)
  IF v_role = 'admin' THEN
    SELECT * INTO v_admin
    FROM public.admin
    WHERE user_id = p_auth_user_id
    LIMIT 1;

    IF v_admin.id IS NULL THEN
      INSERT INTO public.admin(user_id, title, created_at)
      VALUES (p_auth_user_id, v_title, v_now)
      RETURNING * INTO v_admin;
    ELSE
      UPDATE public.admin
        SET title = coalesce(v_title, title)
      WHERE id = v_admin.id
      RETURNING * INTO v_admin;
    END IF;
  ELSE
    SELECT * INTO v_admin FROM public.admin WHERE user_id = p_auth_user_id LIMIT 1;
  END IF;

  v_active_class_id := coalesce(v_student_class.class_id, v_class_id);
  v_effective_school_id := coalesce(v_student.school_id, v_teacher.school_id, v_principal.school_id, v_school_id);
  v_effective_branch_id := coalesce(v_teller.branch_id, null);

  RETURN jsonb_build_object(
    'user_id', v_user.user_id,
    'email', v_user.email,
    'first_name', v_user.first_name,
    'last_name', v_user.last_name,
    'role', v_role,

    'student_id', v_student.student_id,
    'student_class_id', v_student_class_id,
    'class_id', v_active_class_id,

    'guardian_id', coalesce(v_guardian_self.guardian_id, v_guardian_target.guardian_id),
    'guardian_user_id', v_guardian_user_id,
    'guardian_link_id', v_guardian_link_id,
    'guardian_type_id', coalesce(v_guardian_link.type_id, v_guardian_type_id),

    'teacher_id', v_teacher.teacher_id,
    'principal_id', v_principal.principal_id,
    'teller_id', v_teller.teller_id,

    'school_id', v_effective_school_id,
    'credit_union_id', v_effective_branch_id,

    'student_account_id', v_student_account_id
  );
END;$function$;

CREATE OR REPLACE FUNCTION public.admin_assign_role(p_user_id uuid, p_role_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_classes_for_school(p_school_id uuid)
 RETURNS TABLE(class_id uuid, name text, level_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_credit_unions_lookup()
 RETURNS TABLE(branch_id uuid, branch text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select cb.branch_id, cb.branch
  from public.cu_branch cb
  where public.is_admin()
  order by cb.branch;
$function$;

CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
 RETURNS TABLE(user_count bigint, school_count bigint, credit_union_count bigint, student_account_count bigint, total_student_account_value numeric, total_school_account_value numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET row_security TO 'off'
AS $function$
  select
    case when is_admin() then (select count(*) from public."user") else 0 end,
    case when is_admin() then (select count(*) from public.school) else 0 end,
    case when is_admin() then (select count(*) from public.cu_branch) else 0 end,
    case when is_admin() then (select count(*) from public.student_acc) else 0 end,
    case when is_admin() then (select coalesce(sum(sa.closing_bal),0)::numeric from public.student_acc sa) else 0 end,
    case when is_admin() then (select coalesce(sum(sc.closing_bal),0)::numeric from public.school_acc sc) else 0 end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_deactivate_user(p_auth_user_id uuid, p_reason text DEFAULT NULL::text, p_actor_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roles text[] := '{}'::text[];
  v_actor_user_id uuid;
begin
  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  v_actor_user_id := coalesce(p_actor_user_id, auth.uid());

  if v_actor_user_id is null then
    raise exception 'actor_user_id is required';
  end if;

  if v_actor_user_id = p_auth_user_id then
    raise exception 'You cannot deactivate your own account'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public."user" u
    where u.user_id = p_auth_user_id
  ) then
    raise exception 'User not found: %', p_auth_user_id;
  end if;

  select coalesce(array_agg(r.role_name order by r.role_name), '{}'::text[])
    into v_roles
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = p_auth_user_id;

  insert into public.user_deactivation_snapshot (
    user_id,
    prior_role_names,
    reason,
    deactivated_by,
    deactivated_at,
    reactivated_at
  )
  values (
    p_auth_user_id,
    v_roles,
    p_reason,
    v_actor_user_id,
    now(),
    null
  )
  on conflict (user_id) do update
    set prior_role_names = excluded.prior_role_names,
        reason = excluded.reason,
        deactivated_by = excluded.deactivated_by,
        deactivated_at = excluded.deactivated_at,
        reactivated_at = null;

  delete from public.user_role
  where user_id = p_auth_user_id;

  update public."user"
     set is_active = false,
         updated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'deactivated', true,
    'auth_user_id', p_auth_user_id,
    'prior_role_names', to_jsonb(v_roles),
    'actor_user_id', v_actor_user_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_deactivate_user(p_auth_user_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roles text[] := '{}';
begin
  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  if not exists (
    select 1
    from public."user" u
    where u.user_id = p_auth_user_id
  ) then
    raise exception 'User not found: %', p_auth_user_id;
  end if;

  select coalesce(array_agg(r.role_name order by r.role_name), '{}'::text[])
    into v_roles
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = p_auth_user_id;

  insert into public.user_deactivation_snapshot (
    user_id,
    prior_role_names,
    reason,
    deactivated_by,
    deactivated_at,
    reactivated_at
  )
  values (
    p_auth_user_id,
    v_roles,
    p_reason,
    auth.uid(),
    now(),
    null
  )
  on conflict (user_id) do update
    set prior_role_names = excluded.prior_role_names,
        reason = excluded.reason,
        deactivated_by = excluded.deactivated_by,
        deactivated_at = excluded.deactivated_at,
        reactivated_at = null;

  delete from public.user_role
  where user_id = p_auth_user_id;

  update public."user"
     set is_active = false,
         updated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'deactivated', true,
    'auth_user_id', p_auth_user_id,
    'prior_role_names', to_jsonb(v_roles)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_get_user_delete_guard(p_auth_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_student_id uuid;
  v_guardian_id uuid;
  v_teacher_id uuid;
  v_principal_id uuid;
  v_teller_id uuid;

  v_roles text[] := '{}';
  v_blockers jsonb := '[]'::jsonb;
  v_count bigint := 0;
begin
  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  if not exists (
    select 1
    from public."user" u
    where u.user_id = p_auth_user_id
  ) then
    return jsonb_build_object(
      'can_hard_delete', false,
      'auth_user_id', p_auth_user_id,
      'role_names', to_jsonb(v_roles),
      'blockers', jsonb_build_array(
        jsonb_build_object(
          'code', 'USER_NOT_FOUND',
          'message', 'User record not found.'
        )
      )
    );
  end if;

  select coalesce(array_agg(r.role_name order by r.role_name), '{}'::text[])
    into v_roles
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = p_auth_user_id;

  select s.student_id
    into v_student_id
  from public.student s
  where s.user_id = p_auth_user_id
  limit 1;

  select g.guardian_id
    into v_guardian_id
  from public.guardian g
  where g.user_id = p_auth_user_id
  limit 1;

  select t.teacher_id
    into v_teacher_id
  from public.teacher t
  where t.user_id = p_auth_user_id
  limit 1;

  select p.principal_id
    into v_principal_id
  from public.principal p
  where p.user_id = p_auth_user_id
  limit 1;

  select t.teller_id
    into v_teller_id
  from public.teller t
  where t.user_id = p_auth_user_id
  limit 1;

  -- -----------------------------
  -- Student blockers
  -- -----------------------------
  if v_student_id is not null then
    select count(*) into v_count
    from public.student_acc sa
    where sa.student_id = v_student_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'STUDENT_ACCOUNT_EXISTS',
          'count', v_count,
          'message', 'Student account records exist.'
        )
      );
    end if;

    select count(*) into v_count
    from public.transactions t
    where t.student_id = v_student_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'STUDENT_TRANSACTION_HISTORY',
          'count', v_count,
          'message', 'Student transaction history exists.'
        )
      );
    end if;

    select count(*) into v_count
    from public.withdrawal_req wr
    where wr.student_id = v_student_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'STUDENT_WITHDRAWAL_HISTORY',
          'count', v_count,
          'message', 'Student withdrawal request history exists.'
        )
      );
    end if;
  end if;

  -- -----------------------------
  -- Guardian blockers
  -- -----------------------------
  if v_guardian_id is not null then
    select count(*) into v_count
    from public.student_guardian sg
    where sg.guardian_id = v_guardian_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'GUARDIAN_LINKS_EXIST',
          'count', v_count,
          'message', 'Guardian is still linked to student records.'
        )
      );
    end if;

    select count(*) into v_count
    from public.withdrawal_req wr
    where wr.guardian_id = v_guardian_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'GUARDIAN_DECISION_HISTORY',
          'count', v_count,
          'message', 'Guardian approval/decision history exists.'
        )
      );
    end if;
  end if;

  -- -----------------------------
  -- Teacher blockers
  -- -----------------------------
  if v_teacher_id is not null then
    select count(*) into v_count
    from public.transactions t
    where t.teacher_id = v_teacher_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'TEACHER_TRANSACTION_HISTORY',
          'count', v_count,
          'message', 'Teacher transaction history exists.'
        )
      );
    end if;

    select count(*) into v_count
    from public.withdrawal_req wr
    where wr.teacher_id = v_teacher_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'TEACHER_WITHDRAWAL_HISTORY',
          'count', v_count,
          'message', 'Teacher withdrawal processing history exists.'
        )
      );
    end if;

    select count(*) into v_count
    from public.teacher_coll tc
    where tc.teacher_id = v_teacher_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'TEACHER_COLLECTION_HISTORY',
          'count', v_count,
          'message', 'Teacher collection history exists.'
        )
      );
    end if;

    select count(*) into v_count
    from public.cu_dep_event e
    where e.deposited_by_teacher_id = v_teacher_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'TEACHER_DEPOSIT_HISTORY',
          'count', v_count,
          'message', 'Teacher deposit attribution history exists.'
        )
      );
    end if;

    select count(*) into v_count
    from public.cu_payout p
    where p.requested_by_teacher_id = v_teacher_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'TEACHER_PAYOUT_HISTORY',
          'count', v_count,
          'message', 'Teacher payout request history exists.'
        )
      );
    end if;
  end if;

  -- -----------------------------
  -- Principal blockers
  -- -----------------------------
  if v_principal_id is not null then
    select count(*) into v_count
    from public.cu_payout p
    where p.requested_by_principal_id = v_principal_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'PRINCIPAL_PAYOUT_HISTORY',
          'count', v_count,
          'message', 'Principal payout request history exists.'
        )
      );
    end if;
  end if;

  -- -----------------------------
  -- Teller blockers
  -- -----------------------------
  if v_teller_id is not null then
    select count(*) into v_count
    from public.cu_dep_event e
    where e.posted_by_teller_id = v_teller_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'TELLER_DEPOSIT_HISTORY',
          'count', v_count,
          'message', 'Teller deposit posting history exists.'
        )
      );
    end if;

    select count(*) into v_count
    from public.cu_payout p
    where p.posted_by_teller_id = v_teller_id;

    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(
        jsonb_build_object(
          'code', 'TELLER_PAYOUT_HISTORY',
          'count', v_count,
          'message', 'Teller payout posting history exists.'
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'can_hard_delete', jsonb_array_length(v_blockers) = 0,
    'auth_user_id', p_auth_user_id,
    'role_names', to_jsonb(v_roles),
    'blockers', v_blockers
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_guardian_types_lookup()
 RETURNS TABLE(type_id uuid, name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select gt.type_id, gt.name
  from public.guardian_type gt
  where public.is_admin()
  order by gt.name;
$function$;

CREATE OR REPLACE FUNCTION public.admin_hard_delete_user(p_auth_user_id uuid, p_actor_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_guard jsonb;
  v_student_id uuid;
  v_guardian_id uuid;
  v_teacher_id uuid;
  v_principal_id uuid;
  v_teller_id uuid;
  v_actor_user_id uuid;
begin
  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  v_actor_user_id := coalesce(p_actor_user_id, auth.uid());

  if v_actor_user_id is null then
    raise exception 'actor_user_id is required';
  end if;

  if v_actor_user_id = p_auth_user_id then
    raise exception 'You cannot delete your own account'
      using errcode = 'P0001';
  end if;

  v_guard := public.admin_get_user_delete_guard(p_auth_user_id);

  if coalesce((v_guard ->> 'can_hard_delete')::boolean, false) is not true then
    raise exception 'Hard delete is not allowed for this user'
      using errcode = 'P0001',
            detail = coalesce((v_guard -> 'blockers')::text, '[]');
  end if;

  select student_id into v_student_id
  from public.student
  where user_id = p_auth_user_id
  limit 1;

  select guardian_id into v_guardian_id
  from public.guardian
  where user_id = p_auth_user_id
  limit 1;

  select teacher_id into v_teacher_id
  from public.teacher
  where user_id = p_auth_user_id
  limit 1;

  select principal_id into v_principal_id
  from public.principal
  where user_id = p_auth_user_id
  limit 1;

  select teller_id into v_teller_id
  from public.teller
  where user_id = p_auth_user_id
  limit 1;

  delete from public.notification
  where user_id = p_auth_user_id;

  delete from public.user_deactivation_snapshot
  where user_id = p_auth_user_id;

  if v_student_id is not null then
    delete from public.student_guardian where student_id = v_student_id;
    delete from public.student_class where student_id = v_student_id;
    delete from public.student_acc where student_id = v_student_id;
    delete from public.student where student_id = v_student_id;
  end if;

  if v_guardian_id is not null then
    delete from public.student_guardian where guardian_id = v_guardian_id;
    delete from public.guardian where guardian_id = v_guardian_id;
  end if;

  if v_teacher_id is not null then
    delete from public.teacher where teacher_id = v_teacher_id;
  end if;

  if v_principal_id is not null then
    delete from public.principal where principal_id = v_principal_id;
  end if;

  if v_teller_id is not null then
    delete from public.teller where teller_id = v_teller_id;
  end if;

  delete from public.admin where user_id = p_auth_user_id;
  delete from public.user_role where user_id = p_auth_user_id;
  delete from public."user" where user_id = p_auth_user_id;

  return jsonb_build_object(
    'hard_deleted', true,
    'auth_user_id', p_auth_user_id,
    'actor_user_id', v_actor_user_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_hard_delete_user(p_auth_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_guard jsonb;
  v_student_id uuid;
  v_guardian_id uuid;
  v_teacher_id uuid;
  v_principal_id uuid;
  v_teller_id uuid;
begin
  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  v_guard := public.admin_get_user_delete_guard(p_auth_user_id);

  if coalesce((v_guard ->> 'can_hard_delete')::boolean, false) is not true then
    raise exception 'Hard delete is not allowed for this user'
      using errcode = 'P0001',
            detail = coalesce((v_guard -> 'blockers')::text, '[]');
  end if;

  select student_id into v_student_id
  from public.student
  where user_id = p_auth_user_id
  limit 1;

  select guardian_id into v_guardian_id
  from public.guardian
  where user_id = p_auth_user_id
  limit 1;

  select teacher_id into v_teacher_id
  from public.teacher
  where user_id = p_auth_user_id
  limit 1;

  select principal_id into v_principal_id
  from public.principal
  where user_id = p_auth_user_id
  limit 1;

  select teller_id into v_teller_id
  from public.teller
  where user_id = p_auth_user_id
  limit 1;

  delete from public.notification
  where user_id = p_auth_user_id;

  delete from public.user_deactivation_snapshot
  where user_id = p_auth_user_id;

  if v_student_id is not null then
    delete from public.student_guardian where student_id = v_student_id;
    delete from public.student_class where student_id = v_student_id;
    delete from public.student_acc where student_id = v_student_id;
    delete from public.student where student_id = v_student_id;
  end if;

  if v_guardian_id is not null then
    delete from public.student_guardian where guardian_id = v_guardian_id;
    delete from public.guardian where guardian_id = v_guardian_id;
  end if;

  if v_teacher_id is not null then
    delete from public.teacher where teacher_id = v_teacher_id;
  end if;

  if v_principal_id is not null then
    delete from public.principal where principal_id = v_principal_id;
  end if;

  if v_teller_id is not null then
    delete from public.teller where teller_id = v_teller_id;
  end if;

  delete from public.admin where user_id = p_auth_user_id;
  delete from public.user_role where user_id = p_auth_user_id;
  delete from public."user" where user_id = p_auth_user_id;

  return jsonb_build_object(
    'hard_deleted', true,
    'auth_user_id', p_auth_user_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_auth_user_id uuid, p_actor_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_snapshot record;
  v_actor_user_id uuid;
begin
  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  v_actor_user_id := coalesce(p_actor_user_id, auth.uid());

  if v_actor_user_id is null then
    raise exception 'actor_user_id is required';
  end if;

  if v_actor_user_id = p_auth_user_id then
    raise exception 'You cannot reactivate your own account from this screen'
      using errcode = 'P0001';
  end if;

  select *
    into v_snapshot
  from public.user_deactivation_snapshot
  where user_id = p_auth_user_id
  limit 1;

  if not found then
    raise exception 'No deactivation snapshot found for user %', p_auth_user_id;
  end if;

  update public."user"
     set is_active = true,
         updated_at = now()
   where user_id = p_auth_user_id;

  insert into public.user_role (
    user_role_id,
    user_id,
    role_id,
    created_at
  )
  select
    gen_random_uuid(),
    p_auth_user_id,
    r.role_id,
    now()
  from public.role r
  where r.role_name = any(v_snapshot.prior_role_names)
  on conflict (user_id, role_id) do nothing;

  update public.user_deactivation_snapshot
     set reactivated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'reactivated', true,
    'auth_user_id', p_auth_user_id,
    'restored_roles', to_jsonb(v_snapshot.prior_role_names),
    'actor_user_id', v_actor_user_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_auth_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_snapshot record;
begin
  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  select *
    into v_snapshot
  from public.user_deactivation_snapshot
  where user_id = p_auth_user_id
  limit 1;

  if not found then
    raise exception 'No deactivation snapshot found for user %', p_auth_user_id;
  end if;

  update public."user"
     set is_active = true,
         updated_at = now()
   where user_id = p_auth_user_id;

  -- restore prior roles
  insert into public.user_role (user_role_id, user_id, role_id, created_at)
  select
    gen_random_uuid(),
    p_auth_user_id,
    r.role_id,
    now()
  from public.role r
  where r.role_name = any(v_snapshot.prior_role_names)
  on conflict (user_id, role_id) do nothing;

  update public.user_deactivation_snapshot
     set reactivated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'reactivated', true,
    'auth_user_id', p_auth_user_id,
    'restored_roles', to_jsonb(v_snapshot.prior_role_names)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_remove_role(p_user_id uuid, p_role_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_role_id_by_name(p_role_name text)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select case
    when public.is_admin() then (
      select r.role_id
      from public.role r
      where lower(r.role_name) = lower(p_role_name)
      limit 1
    )
    else null::uuid
  end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_school_deposits_report(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_school_id uuid DEFAULT NULL::uuid, p_type text DEFAULT 'all'::text, p_limit integer DEFAULT 5000)
 RETURNS TABLE(dep_event_id uuid, school_id uuid, school_name text, posted_at timestamp with time zone, amount double precision, status text, deposited_by_teacher_id uuid, posted_by_teller_id uuid, transaction_count bigint, total_amount double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_schools_lookup()
 RETURNS TABLE(school_id uuid, name text, level uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select s.school_id, s.name, s."Level" as level
  from public.school s
  where public.is_admin()
  order by s.name;
$function$;

CREATE OR REPLACE FUNCTION public.admin_transaction_report(p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_school_id uuid DEFAULT NULL::uuid, p_class_id uuid DEFAULT NULL::uuid, p_teacher_name_like text DEFAULT NULL::text, p_student_name_like text DEFAULT NULL::text, p_type text DEFAULT 'all'::text, p_limit integer DEFAULT 5000)
 RETURNS TABLE(transaction_id uuid, created_at timestamp with time zone, tx_type text, amount numeric, school_id uuid, school_name text, class_id uuid, class_name text, teacher_id uuid, teacher_first_name text, teacher_last_name text, student_id uuid, student_first_name text, student_last_name text, transaction_count bigint, total_amount numeric)
 LANGUAGE sql
 STABLE
AS $function$
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
    left join public.school   s   on s.school_id   = st.school_id
                                  or s.school_id   = te.school_id
    left join public.student_class stc on stc.student_id = st.student_id
                                      and stc.end_date is null
    left join public.class    sc  on sc.class_id   = stc.class_id
    where
      (p_from             is null or t.created_at   >= p_from)
      and (p_to           is null or t.created_at   <= p_to)
      and (p_school_id    is null or st.school_id    = p_school_id
                                  or te.school_id    = p_school_id)
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_user_profiles(p_user_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_school_id uuid DEFAULT NULL::uuid, p_is_active boolean DEFAULT NULL::boolean, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(user_id uuid, first_name text, last_name text, email text, gender text, title text, created_at timestamp with time zone, updated_at timestamp with time zone, is_active boolean, role_names text[], school_id uuid, school_name text, class_id uuid, class_name text, guardian_type_id uuid, credit_union_id uuid, mobile text, address text, date_of_birth date, guardian_user_id uuid, guardian_link_count bigint, guardian_type_source text, student_guardian_link_count bigint, student_has_primary_guardian boolean, student_guardian_selection_note text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_user_role_names(p_user_id uuid)
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select case
    when public.is_admin() then coalesce(array_agg(r.role_name order by r.role_name), '{}'::text[])
    else '{}'::text[]
  end
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = p_user_id;
$function$;

-- ============================================================
-- Teacher RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.teacher_classes_list()
 RETURNS TABLE(class_id uuid, class_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  select distinct
    c.class_id,
    c.name as class_name
  from public.teacher t
  join public.student s
    on s.school_id = t.school_id
  join public.student_class sc
    on sc.student_id = s.student_id
  join public.class c
    on c.class_id = sc.class_id
  where t.user_id = auth.uid()
    and (sc.end_date is null or sc.end_date >= current_date)
  order by c.name;
$function$;

CREATE OR REPLACE FUNCTION public.teacher_create_deposit(p_student_id uuid, p_amount numeric, p_note text DEFAULT NULL::text, p_day date DEFAULT NULL::date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_teacher_id      uuid;
  v_school_id       uuid;
  v_account_id      uuid;
  v_type_deposit    uuid;
  v_status_posted   uuid;
  v_transaction_id  uuid;
  v_created_at      timestamptz;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid amount';
  END IF;

  SELECT t.teacher_id, t.school_id
    INTO v_teacher_id, v_school_id
  FROM public.teacher t
  WHERE t.user_id = auth.uid()
  LIMIT 1;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Only teachers may create deposits';
  END IF;

  SELECT sa.account_id
    INTO v_account_id
  FROM public.student s
  JOIN public.student_acc sa ON sa.student_id = s.student_id
  WHERE s.student_id = p_student_id
    AND s.school_id  = v_school_id
    AND COALESCE(sa.is_active, true) = true
  ORDER BY sa.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'Student not in your school or has no active account';
  END IF;

  -- case-insensitive lookups
  SELECT type_id
    INTO v_type_deposit
  FROM public.tx_type
  WHERE lower(name) = 'deposit'
  LIMIT 1;

  IF v_type_deposit IS NULL THEN
    RAISE EXCEPTION 'tx_type "DEPOSIT" not found. Seed it with: INSERT INTO public.tx_type(name) VALUES (''DEPOSIT'');';
  END IF;

  SELECT status_id
    INTO v_status_posted
  FROM public.tx_stat
  WHERE lower(name) = 'posted'
  LIMIT 1;

  IF v_status_posted IS NULL THEN
    RAISE EXCEPTION 'tx_stat "POSTED" not found. Seed it with: INSERT INTO public.tx_stat(name) VALUES (''POSTED'');';
  END IF;

  v_created_at := COALESCE((p_day::timestamptz + time '12:00'), now());

  INSERT INTO public.transactions (
    amount, type_id, status_id, student_id, teacher_id,
    notes, created_by, account_id, submitted_by_role, created_at
  )
  VALUES (
    p_amount::double precision, v_type_deposit, v_status_posted, p_student_id, v_teacher_id,
    NULLIF(p_note, ''), auth.uid(), v_account_id, 'Teacher', v_created_at
  )
  RETURNING transaction_id INTO v_transaction_id;

  RETURN v_transaction_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.teacher_home_metrics(p_class_id uuid DEFAULT NULL::uuid, p_student_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(teacher_id uuid, school_id uuid, funds_in_hand numeric, account_balance_total numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT t.teacher_id, t.school_id
    FROM public.teacher t
    WHERE t.user_id = auth.uid()
    LIMIT 1
  ),
  current_class AS (
    SELECT DISTINCT ON (sc.student_id)
      sc.student_id,
      sc.class_id
    FROM public.student_class sc
    WHERE sc.start_date <= current_date
      AND (sc.end_date IS NULL OR sc.end_date >= current_date)
    ORDER BY sc.student_id, sc.start_date DESC
  ),
  scoped_students AS (
    SELECT s.student_id
    FROM me
    JOIN public.student s
      ON s.school_id = me.school_id
    LEFT JOIN current_class cc
      ON cc.student_id = s.student_id
    WHERE (p_class_id IS NULL OR cc.class_id = p_class_id)
      AND (p_student_id IS NULL OR s.student_id = p_student_id)
  ),
  collected AS (
    SELECT
      COALESCE(SUM(tc.amount), 0)::numeric AS collected_total
    FROM me
    JOIN public.teacher_coll tc
      ON tc.teacher_id = me.teacher_id
  ),
  deposited AS (
    SELECT
      COALESCE(SUM(i.applied_amount), 0)::numeric AS deposited_total
    FROM me
    JOIN public.teacher_coll tc
      ON tc.teacher_id = me.teacher_id
    JOIN public.cu_dep_event_item i
      ON i.collection_id = tc.collection_id
    JOIN public.cu_dep_event e
      ON e.dep_event_id = i.dep_event_id
     AND e.status = 'Posted'
  ),
  balances AS (
    SELECT
      COALESCE(SUM(sa.closing_bal), 0)::numeric AS account_balance_total
    FROM scoped_students ss
    JOIN public.student_acc sa
      ON sa.student_id = ss.student_id
    WHERE COALESCE(sa.is_active, true) = true
  )
  SELECT
    me.teacher_id,
    me.school_id,
    GREATEST(
      COALESCE(c.collected_total, 0) - COALESCE(d.deposited_total, 0),
      0
    )::numeric AS funds_in_hand,
    COALESCE(b.account_balance_total, 0)::numeric AS account_balance_total
  FROM me
  CROSS JOIN collected c
  CROSS JOIN deposited d
  CROSS JOIN balances b;
$function$;

CREATE OR REPLACE FUNCTION public.teacher_pending_withdrawals(p_class_id uuid DEFAULT NULL::uuid, p_student_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(request_id uuid, student_id uuid, student_name text, class_id uuid, class_name text, amount numeric, requested_at timestamp with time zone, status text, notes text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT t.teacher_id, t.school_id
    FROM public.teacher t
    WHERE t.user_id = auth.uid()
    LIMIT 1
  ),
  current_class AS (
    SELECT DISTINCT ON (sc.student_id)
      sc.student_id,
      sc.class_id
    FROM public.student_class sc
    WHERE sc.start_date <= current_date
      AND (sc.end_date IS NULL OR sc.end_date >= current_date)
    ORDER BY sc.student_id, sc.start_date DESC
  )
  SELECT
    wr.request_id,
    s.student_id,
    trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')) AS student_name,
    cc.class_id,
    c.name AS class_name,
    wr.amount::numeric,
    wr.requested_at,
    ts.name AS status,
    wr.notes
  FROM me
  JOIN public.student s ON s.school_id = me.school_id
  JOIN public.withdrawal_req wr ON wr.student_id = s.student_id
  JOIN public.tx_stat ts ON ts.status_id = wr.status_id
  JOIN public."user" u ON u.user_id = s.user_id
  LEFT JOIN current_class cc ON cc.student_id = s.student_id
  LEFT JOIN public.class c ON c.class_id = cc.class_id
  WHERE ts.name IN ('PENDING', 'APPROVED')
    AND (p_class_id IS NULL OR cc.class_id = p_class_id)
    AND (p_student_id IS NULL OR s.student_id = p_student_id)
  ORDER BY wr.requested_at ASC;
$function$;

CREATE OR REPLACE FUNCTION public.teacher_post_withdrawal(p_request_id uuid, p_teacher_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$DECLARE
  v_school_id uuid;
  v_student_id uuid;
  v_account_id uuid;
  v_amount numeric;
  v_status_approved uuid;
  v_status_posted uuid;
  v_type_withdrawal uuid;
  v_transaction_id uuid;
  v_teacher_row record;
BEGIN
  -- Ensure teacher exists
  SELECT teacher_id, school_id INTO v_teacher_row
  FROM public.teacher
  WHERE teacher_id = p_teacher_id
    AND user_id = auth.uid()
  LIMIT 1;

IF v_teacher_row.teacher_id IS NULL THEN
  RAISE EXCEPTION 'Only the logged-in teacher can post this withdrawal'
    USING ERRCODE = '42501';
END IF;

  v_school_id := v_teacher_row.school_id;

  -- Fetch request details and verify it belongs to the same school
  SELECT wr.student_id, wr.account_id, wr.amount
  INTO v_student_id, v_account_id, v_amount
  FROM public.withdrawal_req wr
  JOIN public.student s ON s.student_id = wr.student_id
  WHERE wr.request_id = p_request_id
    AND s.school_id = v_school_id
  LIMIT 1;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Withdrawal request not found or not in teacher school';
  END IF;

  -- Resolve status/type ids
  SELECT public.id_of_tx_stat('APPROVED') INTO v_status_approved;
  SELECT public.id_of_tx_stat('POSTED') INTO v_status_posted;
  SELECT public.id_of_tx_type('WITHDRAWAL') INTO v_type_withdrawal;

  IF v_status_approved IS NULL OR v_status_posted IS NULL OR v_type_withdrawal IS NULL THEN
    RAISE EXCEPTION 'Required tx status/type not configured';
  END IF;

  -- Ensure request is APPROVED
  IF NOT EXISTS (SELECT 1 FROM public.withdrawal_req WHERE request_id = p_request_id AND status_id = v_status_approved) THEN
    RAISE EXCEPTION 'Request is not approved';
  END IF;

  -- Insert transaction (POSTED)
  INSERT INTO public.transactions (
    transaction_id,
    account_id,
    student_id,
    type_id,
    amount,
    status_id,
    teacher_id,
    created_by,
    submitted_by_role,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_account_id,
    v_student_id,
    v_type_withdrawal,
    v_amount,
    v_status_posted,
    p_teacher_id,
    auth.uid(),
    'Teacher',
    now(),
    now()
  )
  RETURNING transaction_id INTO v_transaction_id;

  -- Mark request as POSTED/complete
  UPDATE public.withdrawal_req
  SET status_id = v_status_posted,
      teacher_id = p_teacher_id,
      completed_at = now(),
      updated_at = now(),
      updated_by = auth.uid()
  WHERE request_id = p_request_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Failed to update withdrawal_req %', p_request_id;
  END IF;

  RETURN v_transaction_id;
END;$function$;

CREATE OR REPLACE FUNCTION public.teacher_students_list(p_class_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(student_id uuid, class_id uuid, class_name text, first_name text, last_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with teacher_scope as (
    select t.school_id
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
    s.student_id,
    c.class_id,
    c.name as class_name,
    u.first_name,
    u.last_name
  from teacher_scope ts
  join public.student s
    on s.school_id = ts.school_id
  join current_class cc
    on cc.student_id = s.student_id
  join public.class c
    on c.class_id = cc.class_id
  join public."user" u
    on u.user_id = s.user_id
  where p_class_id is null or c.class_id = p_class_id
  order by u.first_name, u.last_name, s.student_id;
$function$;

CREATE OR REPLACE FUNCTION public.teacher_submit_withdrawal_for_student(p_student_id uuid, p_amount numeric, p_reason text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS TABLE(request_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_teacher_id uuid;
  v_school_id uuid;
  v_account_id uuid;
  v_balance numeric;
  v_pending uuid;
BEGIN
  SELECT t.teacher_id, t.school_id
    INTO v_teacher_id, v_school_id
  FROM public.teacher t
  WHERE t.user_id = auth.uid()
  LIMIT 1;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Only teachers may submit withdrawal requests for students';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid amount';
  END IF;

  SELECT sa.account_id, COALESCE(sa.closing_bal, 0)::numeric
    INTO v_account_id, v_balance
  FROM public.student s
  JOIN public.student_acc sa
    ON sa.student_id = s.student_id
  WHERE s.student_id = p_student_id
    AND s.school_id = v_school_id
    AND COALESCE(sa.is_active, true) = true
  ORDER BY sa.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_account_id IS NULL THEN
    RAISE EXCEPTION 'Student not in your school or has no active account';
  END IF;

  IF p_amount > v_balance THEN
    RAISE EXCEPTION 'Amount exceeds available balance';
  END IF;

  SELECT public.id_of_tx_stat('PENDING') INTO v_pending;

  INSERT INTO public.withdrawal_req (
    student_id,
    account_id,
    teacher_id,
    amount,
    status_id,
    requested_at,
    notes,
    reason,
    updated_by
  )
  VALUES (
    p_student_id,
    v_account_id,
    v_teacher_id,
    p_amount,
    v_pending,
    now(),
    p_notes,
    p_reason,
    auth.uid()
  )
  RETURNING withdrawal_req.request_id INTO request_id;

  RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.teacher_transaction_history(p_class_id uuid DEFAULT NULL::uuid, p_student_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 200)
 RETURNS TABLE(transaction_id uuid, created_at timestamp with time zone, class_id uuid, class_name text, student_id uuid, student_first_name text, student_last_name text, tx_type text, tx_status text, amount numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with teacher_scope as (
    select t.teacher_id, t.school_id
    from public.teacher t
    where t.user_id = auth.uid()
    limit 1
  ),
  tx_base as (
    select
      t.transaction_id,
      t.created_at,
      t.student_id,
      s.school_id,
      tt.name as tx_type,
      ts.name as tx_status,
      case
        when tt.name = 'WITHDRAWAL' then (-t.amount)::numeric
        else t.amount::numeric
      end as amount
    from public.transactions t
    join public.tx_type tt
      on tt.type_id = t.type_id
    join public.tx_stat ts
      on ts.status_id = t.status_id
    join public.student s
      on s.student_id = t.student_id
    join teacher_scope x
      on x.school_id = s.school_id
    where ts.name = 'POSTED'
      and (p_student_id is null or t.student_id = p_student_id)
  ),
  tx_with_class as (
    select
      tb.*,
      scx.class_id
    from tx_base tb
    left join lateral (
      select sc.class_id
      from public.student_class sc
      where sc.student_id = tb.student_id
        and sc.start_date <= tb.created_at::date
        and (sc.end_date is null or sc.end_date >= tb.created_at::date)
      order by sc.start_date desc
      limit 1
    ) scx on true
  )
  select
    tx.transaction_id,
    tx.created_at,
    tx.class_id,
    c.name as class_name,
    tx.student_id,
    u.first_name as student_first_name,
    u.last_name as student_last_name,
    tx.tx_type,
    tx.tx_status,
    tx.amount
  from tx_with_class tx
  join public.student s
    on s.student_id = tx.student_id
  join public."user" u
    on u.user_id = s.user_id
  left join public.class c
    on c.class_id = tx.class_id
  where p_class_id is null or tx.class_id = p_class_id
  order by tx.created_at desc
  limit greatest(coalesce(p_limit, 200), 1);
$function$;

CREATE OR REPLACE FUNCTION public.teacher_withdrawals_list(p_class_id uuid DEFAULT NULL::uuid, p_student_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 500)
 RETURNS TABLE(request_id uuid, requested_at timestamp with time zone, amount numeric, status text, student_id uuid, student_name text, class_id uuid, class_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

-- ============================================================
-- Teller RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.teller_deposit_events_list(p_from timestamp with time zone, p_to timestamp with time zone, p_school_id uuid DEFAULT NULL::uuid, p_teacher_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 5000)
 RETURNS TABLE(school_id uuid, teacher_id uuid, posted_by_teller_id uuid, posted_at timestamp with time zone, amount numeric, discrepancy numeric, status text, notes text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  with me as (
    select t.teller_id
    from public.teller t
    where t.user_id = auth.uid()
    limit 1
  )
  select
    e.school_id,
    e.deposited_by_teacher_id as teacher_id,
    e.posted_by_teller_id,
    e.posted_at,
    coalesce(e.amount, 0)::numeric as amount,
    0::numeric as discrepancy,
    e.status,
    coalesce(e.notes, '') as notes
  from me
  join public.cu_dep_event e
    on true
  where e.posted_at >= p_from
    and e.posted_at <= p_to
    and (p_school_id is null or e.school_id = p_school_id)
    and (p_teacher_id is null or e.deposited_by_teacher_id = p_teacher_id)
  order by e.posted_at desc
  limit least(greatest(coalesce(p_limit, 5000), 1), 5000);
$function$;

-- ============================================================
-- Principal RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.principal_flag_recon(p_reconciliation_id uuid, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_principal_id uuid;
  v_school_id uuid;
  v_status_flagged uuid;
BEGIN
  -- Ensure caller is a principal
  SELECT principal_id, school_id
    INTO v_principal_id, v_school_id
  FROM public.principal
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF v_principal_id IS NULL THEN
    RAISE EXCEPTION 'Only principals can flag reconciliations';
  END IF;

  -- Resolve status id for FLAGGED
  SELECT public.id_of_tx_stat('FLAGGED') INTO v_status_flagged;

  UPDATE public.bch_recon
     SET status_id = v_status_flagged,
         notes     = COALESCE(notes,'') || CASE WHEN p_note IS NOT NULL THEN E'\
[Principal] '||p_note ELSE '' END,
         updated_at = now(),
         updated_by = auth.uid()
   WHERE reconciliation_id = p_reconciliation_id
     AND school_id = v_school_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reconciliation not found for your school or already updated';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.principal_flag_recon(p_reconciliation_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT public.principal_flag_recon(p_reconciliation_id, NULL);
$function$;

CREATE OR REPLACE FUNCTION public.principal_funds_on_site()
 RETURNS TABLE(school_id uuid, collected_total numeric, deposited_total numeric, funds_on_site numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT p.school_id
    FROM public.principal p
    WHERE p.user_id = auth.uid()
    LIMIT 1
  ),
  collected AS (
    SELECT
      tc.school_id,
      COALESCE(SUM(tc.amount), 0)::numeric AS collected_total
    FROM me
    JOIN public.teacher_coll tc
      ON tc.school_id = me.school_id
    GROUP BY tc.school_id
  ),
  deposited AS (
    SELECT
      e.school_id,
      COALESCE(SUM(i.applied_amount), 0)::numeric AS deposited_total
    FROM me
    JOIN public.cu_dep_event e
      ON e.school_id = me.school_id
     AND e.status = 'Posted'
    JOIN public.cu_dep_event_item i
      ON i.dep_event_id = e.dep_event_id
    GROUP BY e.school_id
  )
  SELECT
    me.school_id,
    COALESCE(c.collected_total, 0)::numeric,
    COALESCE(d.deposited_total, 0)::numeric,
    GREATEST(
      COALESCE(c.collected_total, 0) - COALESCE(d.deposited_total, 0),
      0
    )::numeric AS funds_on_site
  FROM me
  LEFT JOIN collected c
    ON c.school_id = me.school_id
  LEFT JOIN deposited d
    ON d.school_id = me.school_id;
$function$;

CREATE OR REPLACE FUNCTION public.principal_pending_deposit_summary()
 RETURNS TABLE(school_id uuid, pending_deposit numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT p.school_id
    FROM public.principal p
    WHERE p.user_id = auth.uid()
    LIMIT 1
  ),
  collected AS (
    SELECT COALESCE(SUM(tc.amount), 0)::numeric AS total
    FROM me
    JOIN public.teacher_coll tc
      ON tc.school_id = me.school_id
  ),
  deposited AS (
    SELECT COALESCE(SUM(i.applied_amount), 0)::numeric AS total
    FROM me
    JOIN public.cu_dep_event e
      ON e.school_id = me.school_id
     AND e.status = 'Posted'
    JOIN public.cu_dep_event_item i
      ON i.dep_event_id = e.dep_event_id
  )
  SELECT
    me.school_id,
    GREATEST(
      COALESCE(c.total, 0) - COALESCE(d.total, 0),
      0
    )::numeric AS pending_deposit
  FROM me
  CROSS JOIN collected c
  CROSS JOIN deposited d;
$function$;

CREATE OR REPLACE FUNCTION public.principal_reconcile_week_data(p_week_start date DEFAULT NULL::date)
 RETURNS TABLE(school_id uuid, teacher_id uuid, week_start date, week_end date, collected_amount numeric, batched_amount numeric, deposited_amount numeric, batched_pending_amount numeric, remaining_amount numeric, recon_status text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.principal_school_account_balance(p_school_id uuid DEFAULT NULL::uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.principal_school_deposit_history(p_limit integer DEFAULT 200)
 RETURNS TABLE(dep_event_id uuid, school_id uuid, teacher_id uuid, teacher_name text, posted_by_teller_id uuid, deposit_date timestamp with time zone, amount numeric, status text, batch_id uuid, week_start date, week_end date)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT p.school_id
    FROM public.principal p
    WHERE p.user_id = auth.uid()
    LIMIT 1
  ),
  event_batch AS (
    SELECT DISTINCT ON (eb.dep_event_id)
      eb.dep_event_id,
      eb.batch_id,
      b.week_start,
      b.week_end
    FROM public.cu_dep_event_batch eb
    JOIN public.dep_batch b
      ON b.batch_id = eb.batch_id
    ORDER BY eb.dep_event_id, b.week_start DESC
  )
  SELECT
    e.dep_event_id,
    e.school_id,
    e.deposited_by_teacher_id AS teacher_id,
    trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')) AS teacher_name,
    e.posted_by_teller_id,
    e.posted_at AS deposit_date,
    e.amount::numeric AS amount,
    e.status,
    eb.batch_id,
    eb.week_start,
    eb.week_end
  FROM me
  JOIN public.cu_dep_event e
    ON e.school_id = me.school_id
  LEFT JOIN public.teacher t
    ON t.teacher_id = e.deposited_by_teacher_id
  LEFT JOIN public."user" u
    ON u.user_id = t.user_id
  LEFT JOIN event_batch eb
    ON eb.dep_event_id = e.dep_event_id
  WHERE e.status = 'Posted'
  ORDER BY e.posted_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 200), 1);
$function$;

CREATE OR REPLACE FUNCTION public.principal_school_deposited_total()
 RETURNS TABLE(school_id uuid, deposited_total numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT p.school_id
    FROM public.principal p
    WHERE p.user_id = auth.uid()
    LIMIT 1
  )
  SELECT
    me.school_id,
    COALESCE(SUM(e.amount), 0)::numeric AS deposited_total
  FROM me
  LEFT JOIN public.cu_dep_event e
    ON e.school_id = me.school_id
   AND e.status = 'Posted'
  GROUP BY me.school_id;
$function$;

CREATE OR REPLACE FUNCTION public.principal_school_outstanding_deposit_detail()
 RETURNS TABLE(school_id uuid, deposit_due numeric, deposited numeric, difference numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.principal_student_balance(p_student_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.principal_students_list(p_teacher_id uuid DEFAULT NULL::uuid, p_class_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(student_id uuid, student_name text, class_id uuid, class_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with my_principal as (
    select p.school_id
    from public.principal p
    where p.user_id = auth.uid()
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
    s.student_id,
    trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')) as student_name,
    cc.class_id,
    c.name as class_name
  from my_principal mp
  join public.student s
    on s.school_id = mp.school_id
  join public."user" u
    on u.user_id = s.user_id
  left join current_class cc
    on cc.student_id = s.student_id
  left join public.class c
    on c.class_id = cc.class_id
  where
    (p_class_id is null or cc.class_id = p_class_id)
  order by u.first_name, u.last_name, s.student_id;
$function$;

CREATE OR REPLACE FUNCTION public.principal_teacher_deposit_history(p_teacher_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 200)
 RETURNS TABLE(dep_event_id uuid, school_id uuid, teacher_id uuid, teacher_name text, deposit_date timestamp with time zone, amount numeric, status text, batch_id uuid, week_start date, week_end date)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.principal_teacher_outstanding_deposit_detail(p_teacher_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(school_id uuid, teacher_id uuid, deposit_due numeric, deposited numeric, difference numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.principal_teachers_list()
 RETURNS TABLE(teacher_id uuid, teacher_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with my_principal as (
    select p.school_id
    from public.principal p
    where p.user_id = auth.uid()
    limit 1
  )
  select
    t.teacher_id,
    trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')) as teacher_name
  from my_principal mp
  join public.teacher t
    on t.school_id = mp.school_id
  join public."user" u
    on u.user_id = t.user_id
  order by u.first_name, u.last_name, t.teacher_id;
$function$;

CREATE OR REPLACE FUNCTION public.principal_transaction_history(p_teacher_id uuid DEFAULT NULL::uuid, p_class_id uuid DEFAULT NULL::uuid, p_student_id uuid DEFAULT NULL::uuid, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 1000)
 RETURNS TABLE(transaction_id uuid, created_at timestamp with time zone, teacher_id uuid, teacher_name text, class_id uuid, class_name text, student_id uuid, student_name text, tx_type text, tx_status text, amount numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with my_principal as (
    select p.school_id
    from public.principal p
    where p.user_id = auth.uid()
    limit 1
  ),
  tx_base as (
    select
      t.transaction_id,
      t.created_at,
      t.teacher_id,
      t.student_id,
      tt.name as tx_type,
      ts.name as tx_status,
      case
        when tt.name = 'WITHDRAWAL' then (-t.amount)::numeric
        else t.amount::numeric
      end as amount
    from my_principal mp
    join public.transactions t
      on true
    join public.student s
      on s.student_id = t.student_id
     and s.school_id = mp.school_id
    join public.tx_type tt
      on tt.type_id = t.type_id
    join public.tx_stat ts
      on ts.status_id = t.status_id
    where
      (p_teacher_id is null or t.teacher_id = p_teacher_id)
      and (p_student_id is null or t.student_id = p_student_id)
      and (p_from is null or t.created_at >= p_from)
      and (p_to is null or t.created_at <= p_to)
  ),
  tx_with_class as (
    select
      tb.*,
      scx.class_id
    from tx_base tb
    left join lateral (
      select sc.class_id
      from public.student_class sc
      where sc.student_id = tb.student_id
        and sc.start_date <= tb.created_at::date
        and (sc.end_date is null or sc.end_date >= tb.created_at::date)
      order by sc.start_date desc
      limit 1
    ) scx on true
  )
  select
    tx.transaction_id,
    tx.created_at,
    tx.teacher_id,
    nullif(trim(coalesce(tu.first_name, '') || ' ' || coalesce(tu.last_name, '')), '') as teacher_name,
    tx.class_id,
    c.name as class_name,
    tx.student_id,
    trim(coalesce(su.first_name, '') || ' ' || coalesce(su.last_name, '')) as student_name,
    tx.tx_type,
    tx.tx_status,
    tx.amount
  from tx_with_class tx
  join public.student s
    on s.student_id = tx.student_id
  join public."user" su
    on su.user_id = s.user_id
  left join public.teacher tch
    on tch.teacher_id = tx.teacher_id
  left join public."user" tu
    on tu.user_id = tch.user_id
  left join public.class c
    on c.class_id = tx.class_id
  where
    (p_class_id is null or tx.class_id = p_class_id)
  order by tx.created_at desc
  limit greatest(coalesce(p_limit, 1000), 1);
$function$;

-- ============================================================
-- Guardian RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.guardian_children_list()
 RETURNS TABLE(student_id uuid, student_name text, school_id uuid, class_id uuid, class_name text, balance numeric, pending_requests bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with me_guardian as (
    select g.guardian_id
    from public.guardian g
    where g.user_id = auth.uid()
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
  ),
  pending_wr as (
    select
      wr.student_id,
      count(*)::bigint as pending_requests
    from public.withdrawal_req wr
    join public.tx_stat ts
      on ts.status_id = wr.status_id
    where ts.name in ('PENDING', 'APPROVED')
    group by wr.student_id
  )
  select
    s.student_id,
    trim(coalesce(u.first_name,'') || ' ' || coalesce(u.last_name,'')) as student_name,
    s.school_id,
    cc.class_id,
    c.name as class_name,
    coalesce(sa.closing_bal, 0)::numeric as balance,
    coalesce(pw.pending_requests, 0)::bigint as pending_requests
  from me_guardian mg
  join public.student_guardian sg
    on sg.guardian_id = mg.guardian_id
  join public.student s
    on s.student_id = sg.student_id
  join public."user" u
    on u.user_id = s.user_id
  left join current_class cc
    on cc.student_id = s.student_id
  left join public.class c
    on c.class_id = cc.class_id
  left join lateral (
    select sa1.account_id, sa1.closing_bal
    from public.student_acc sa1
    where sa1.student_id = s.student_id
      and coalesce(sa1.is_active, true) = true
    order by sa1.created_at desc nulls last
    limit 1
  ) sa on true
  left join pending_wr pw
    on pw.student_id = s.student_id
  order by u.first_name, u.last_name, s.student_id;
$function$;

CREATE OR REPLACE FUNCTION public.guardian_decide_withdrawal(p_request_id uuid, p_decision text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_guardian_id uuid;
  v_student_id uuid;
  v_new_status_id uuid;
  v_current_status text;
BEGIN
  -- Get current user's guardian_id
  SELECT guardian_id INTO v_guardian_id
  FROM guardian
  WHERE user_id = auth.uid();

  IF v_guardian_id IS NULL THEN
    RAISE EXCEPTION 'Guardian record not found for current user';
  END IF;

  -- Get the student_id and current status from the withdrawal request
  SELECT wr.student_id, ts.name
  INTO v_student_id, v_current_status
  FROM withdrawal_req wr
  JOIN tx_stat ts ON ts.status_id = wr.status_id
  WHERE wr.request_id = p_request_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Withdrawal request not found';
  END IF;

  -- Check if current user is guardian of the student
  IF NOT is_guardian_of_student(v_student_id) THEN
    RAISE EXCEPTION 'You are not a guardian of this student' USING ERRCODE = 'P0001';
  END IF;

  -- Only allow deciding on PENDING requests
  IF v_current_status != 'PENDING' THEN
    RAISE EXCEPTION 'Can only approve or decline PENDING requests. Current status: %', v_current_status;
  END IF;

  -- Validate decision
  IF p_decision NOT IN ('APPROVED', 'DECLINED') THEN
    RAISE EXCEPTION 'Decision must be APPROVED or DECLINED, got: %', p_decision;
  END IF;

  -- Get the new status ID
  SELECT status_id INTO v_new_status_id
  FROM tx_stat
  WHERE name = p_decision
  LIMIT 1;

  IF v_new_status_id IS NULL THEN
    RAISE EXCEPTION 'Status % not found in tx_stat table', p_decision;
  END IF;

  -- Update the withdrawal request with guardian_id
  UPDATE withdrawal_req
  SET status_id = v_new_status_id,
      guardian_id = v_guardian_id,
      notes = CASE
        WHEN p_note IS NOT NULL AND p_note != '' THEN
          COALESCE(notes || E'\
\
', '') || 'Guardian decision: ' || p_note
        ELSE notes
      END,
      updated_at = now()
  WHERE request_id = p_request_id;

  -- Log the decision
  RAISE NOTICE 'Guardian % (%) set withdrawal request % to % for student %',
    auth.uid(), v_guardian_id, p_request_id, p_decision, v_student_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.guardian_pending_withdrawals(p_student_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(request_id uuid, student_id uuid, student_name text, amount numeric, requested_at timestamp with time zone, status text, notes text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with me_guardian as (
    select g.guardian_id
    from public.guardian g
    where g.user_id = auth.uid()
    limit 1
  ),
  allowed_students as (
    select sg.student_id
    from public.student_guardian sg
    join me_guardian mg
      on mg.guardian_id = sg.guardian_id
  )
  select
    wr.request_id,
    wr.student_id,
    trim(coalesce(u.first_name,'') || ' ' || coalesce(u.last_name,'')) as student_name,
    wr.amount::numeric as amount,
    wr.requested_at,
    ts.name as status,
    wr.notes
  from public.withdrawal_req wr
  join allowed_students a
    on a.student_id = wr.student_id
  join public.student s
    on s.student_id = wr.student_id
  join public."user" u
    on u.user_id = s.user_id
  join public.tx_stat ts
    on ts.status_id = wr.status_id
  where ts.name in ('PENDING', 'APPROVED')
    and (p_student_id is null or wr.student_id = p_student_id)
  order by wr.requested_at asc;
$function$;

CREATE OR REPLACE FUNCTION public.guardian_transaction_history(p_student_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 200)
 RETURNS TABLE(transaction_id uuid, student_id uuid, student_name text, created_at timestamp with time zone, tx_type text, tx_status text, amount numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with me_guardian as (
    select g.guardian_id
    from public.guardian g
    where g.user_id = auth.uid()
    limit 1
  ),
  allowed_students as (
    select sg.student_id
    from public.student_guardian sg
    join me_guardian mg
      on mg.guardian_id = sg.guardian_id
  )
  select
    t.transaction_id,
    t.student_id,
    trim(coalesce(u.first_name,'') || ' ' || coalesce(u.last_name,'')) as student_name,
    t.created_at,
    tt.name as tx_type,
    ts.name as tx_status,
    case
      when tt.name = 'WITHDRAWAL' then (-t.amount)::numeric
      else t.amount::numeric
    end as amount
  from public.transactions t
  join allowed_students a
    on a.student_id = t.student_id
  join public.student s
    on s.student_id = t.student_id
  join public."user" u
    on u.user_id = s.user_id
  join public.tx_type tt
    on tt.type_id = t.type_id
  join public.tx_stat ts
    on ts.status_id = t.status_id
  where ts.name = 'POSTED'
    and (p_student_id is null or t.student_id = p_student_id)
  order by t.created_at desc
  limit greatest(coalesce(p_limit, 200), 1);
$function$;

-- ============================================================
-- Student RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.student_home()
 RETURNS TABLE(student_id uuid, school_id uuid, account_id uuid, balance numeric, latest_request_id uuid, latest_request_amount numeric, latest_request_status text, latest_request_requested_at timestamp with time zone, latest_request_notes text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  WITH me AS (
    SELECT s.student_id, s.school_id
    FROM public.student s
    WHERE s.user_id = auth.uid()
    ORDER BY s.created_at DESC NULLS LAST
    LIMIT 1
  ),
  active_acc AS (
    SELECT sa.account_id, COALESCE(sa.closing_bal, 0)::numeric AS balance
    FROM me
    JOIN public.student_acc sa ON sa.student_id = me.student_id
    WHERE COALESCE(sa.is_active, true) = true
    ORDER BY sa.created_at DESC NULLS LAST
    LIMIT 1
  ),
  latest_wr AS (
    SELECT
      wr.request_id,
      wr.amount::numeric,
      ts.name AS status,
      wr.requested_at,
      wr.notes
    FROM me
    JOIN public.withdrawal_req wr ON wr.student_id = me.student_id
    JOIN public.tx_stat ts ON ts.status_id = wr.status_id
    ORDER BY wr.requested_at DESC
    LIMIT 1
  )
  SELECT
    me.student_id,
    me.school_id,
    active_acc.account_id,
    COALESCE(active_acc.balance, 0)::numeric,
    latest_wr.request_id,
    latest_wr.amount,
    latest_wr.status,
    latest_wr.requested_at,
    latest_wr.notes
  FROM me
  LEFT JOIN active_acc ON true
  LEFT JOIN latest_wr ON true;
$function$;

CREATE OR REPLACE FUNCTION public.student_transaction_history(p_limit integer DEFAULT 25)
 RETURNS TABLE(transaction_id uuid, created_at timestamp with time zone, tx_type text, tx_status text, amount numeric, class_id uuid, class_name text, teacher_name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
 SET row_security TO 'off'
AS $function$
  with me_student as (
    select s.student_id
    from public.student s
    where s.user_id = auth.uid()
    limit 1
  ),
  tx_with_class as (
    select
      t.transaction_id,
      t.created_at,
      tt.name as tx_type,
      ts.name as tx_status,
      case
        when tt.name = 'WITHDRAWAL' then (-t.amount)::numeric
        else t.amount::numeric
      end as amount,
      t.teacher_id,
      scx.class_id
    from public.transactions t
    join public.tx_type tt
      on tt.type_id = t.type_id
    join public.tx_stat ts
      on ts.status_id = t.status_id
    join me_student ms
      on ms.student_id = t.student_id
    left join lateral (
      select sc.class_id
      from public.student_class sc
      where sc.student_id = t.student_id
        and sc.start_date <= t.created_at::date
        and (sc.end_date is null or sc.end_date >= t.created_at::date)
      order by sc.start_date desc
      limit 1
    ) scx on true
    where ts.name = 'POSTED'
  )
  select
    tx.transaction_id,
    tx.created_at,
    tx.tx_type,
    tx.tx_status,
    tx.amount,
    tx.class_id,
    c.name as class_name,
    nullif(trim(coalesce(u.first_name,'') || ' ' || coalesce(u.last_name,'')), '') as teacher_name
  from tx_with_class tx
  left join public.class c
    on c.class_id = tx.class_id
  left join public.teacher tch
    on tch.teacher_id = tx.teacher_id
  left join public."user" u
    on u.user_id = tch.user_id
  order by tx.created_at desc
  limit greatest(coalesce(p_limit, 25), 1);
$function$;

-- ============================================================
-- Other RPCs (search, withdrawal, reporting)
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_teacher_closing_cash(p_teacher_id uuid, p_school_id uuid, p_date date, p_closing numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_week_start date;
  v_week_end   date;
  v_expected   numeric;
BEGIN
  -- You already have weekly logic in recalc_teacher_coll_for_week; reuse the same boundaries:
  v_week_start := date_trunc('week', p_date)::date;      -- adjust if Monday = week start differently
  v_week_end   := v_week_start + 4;                      -- Mon–Fri

  SELECT tc.amount INTO v_expected
  FROM public.teacher_coll tc
  WHERE tc.school_id  = p_school_id
    AND tc.teacher_id = p_teacher_id
    AND tc.week_start = v_week_start
    AND tc.week_end   = v_week_end
  LIMIT 1;

  -- upsert the day_bch row
  INSERT INTO public.day_bch (day_batch_id, school_id, teacher_id, batch_date,
                              closing_cash, expected_cash, discrepancy)
  VALUES (gen_random_uuid(), p_school_id, p_teacher_id, p_date,
          p_closing, v_expected, p_closing - v_expected)
  ON CONFLICT (school_id, teacher_id, batch_date)
  DO UPDATE SET
    closing_cash  = EXCLUDED.closing_cash,
    expected_cash = EXCLUDED.expected_cash,
    discrepancy   = EXCLUDED.discrepancy;
END;
$function$;

CREATE OR REPLACE FUNCTION public.request_withdrawal(p_student_id uuid, p_amount numeric, p_reason text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_request_id uuid;
  v_pending uuid;
  v_account_id uuid;
  v_balance numeric;
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
  JOIN public.student_acc sa
    ON sa.student_id = s.student_id
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
    student_id,
    account_id,
    amount,
    status_id,
    requested_at,
    notes,
    reason,
    updated_by
  )
  VALUES (
    p_student_id,
    v_account_id,
    p_amount,
    v_pending,
    now(),
    p_notes,
    p_reason,
    auth.uid()
  )
  RETURNING request_id INTO v_request_id;

  INSERT INTO public.notification (
    user_id,
    title,
    message,
    entity_type,
    entity_id
  )
  SELECT
    g.user_id,
    'Withdrawal Request',
    'Please review a withdrawal request for your child.',
    'withdrawal_req',
    v_request_id
  FROM public.student_guardian sg
  JOIN public.guardian g
    ON g.guardian_id = sg.guardian_id
  WHERE sg.student_id = p_student_id;

  RETURN v_request_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_guardians(q text, include_inactive boolean DEFAULT false)
 RETURNS TABLE(guardian_id uuid, user_id uuid, first_name text, last_name text, email text, mobile text, school_id uuid)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH me AS (
    SELECT current_app_user_id() AS uid
  ),
  role_scope AS (
    SELECT
      uid,
      is_admin()                                         AS is_admin,
      current_principal_school_id()                      AS principal_school_id,
      current_teacher_school_id()                        AS teacher_school_id
    FROM me
  ),
  qnorm AS (
    SELECT nullif(trim(coalesce(q,'')), '') AS term
  )
  SELECT
    g.guardian_id,
    g.user_id,
    u.first_name,
    u.last_name,
    u.email,
    g.mobile,
    s.school_id
  FROM public.guardian g
  JOIN public."user" u          ON u.user_id = g.user_id
  LEFT JOIN public.student_guardian sg ON sg.guardian_id = g.guardian_id
  LEFT JOIN public.student s          ON s.student_id = sg.student_id
  CROSS JOIN role_scope rs
  CROSS JOIN qnorm
  WHERE
    -- require a term (no bulk dump)
    qnorm.term IS NOT NULL
    -- match by full name, email, or mobile
    AND (
      (u.first_name || ' ' || coalesce(u.last_name,'')) ILIKE '%' || qnorm.term || '%'
      OR u.email ILIKE '%' || qnorm.term || '%'
      OR coalesce(g.mobile,'') ILIKE '%' || qnorm.term || '%'
    )
    -- scope by role
    AND (
      rs.is_admin
      OR (rs.principal_school_id IS NOT NULL AND s.school_id = rs.principal_school_id)
      OR (rs.teacher_school_id   IS NOT NULL AND s.school_id = rs.teacher_school_id)
    )
    -- active status if you later track it (guard against future column)
    AND (include_inactive OR u.is_active IS DISTINCT FROM false)
  GROUP BY g.guardian_id, g.user_id, u.first_name, u.last_name, u.email, g.mobile, s.school_id;
$function$;

CREATE OR REPLACE FUNCTION public.submit_dep_batch(p_school_id uuid, p_week_start date, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_week_start date := p_week_start;
  v_week_end date := p_week_start + 6;
  v_batch_id uuid;
  v_expected numeric;
BEGIN
  IF p_school_id IS NULL OR p_week_start IS NULL THEN
    RAISE EXCEPTION 'school_id and week_start are required';
  END IF;

  INSERT INTO public.dep_batch (
    batch_id,
    school_id,
    week_start,
    week_end,
    status,
    expected_amount,
    created_at,
    created_by,
    submitted_at,
    submitted_by,
    note
  )
  VALUES (
    gen_random_uuid(),
    p_school_id,
    v_week_start,
    v_week_end,
    'SUBMITTED',
    0,
    now(),
    auth.uid(),
    now(),
    auth.uid(),
    NULLIF(p_note, '')
  )
  ON CONFLICT (school_id, week_start, week_end)
  DO UPDATE SET
    status = CASE
      WHEN public.dep_batch.status IN ('DEPOSITED', 'CANCELLED')
        THEN public.dep_batch.status
      ELSE 'SUBMITTED'
    END,
    submitted_at = CASE
      WHEN public.dep_batch.status IN ('DEPOSITED', 'CANCELLED')
        THEN public.dep_batch.submitted_at
      ELSE now()
    END,
    submitted_by = CASE
      WHEN public.dep_batch.status IN ('DEPOSITED', 'CANCELLED')
        THEN public.dep_batch.submitted_by
      ELSE auth.uid()
    END,
    note = CASE
      WHEN EXCLUDED.note IS NULL THEN public.dep_batch.note
      WHEN public.dep_batch.note IS NULL THEN EXCLUDED.note
      ELSE public.dep_batch.note || E'\
' || EXCLUDED.note
    END
  RETURNING batch_id INTO v_batch_id;

  IF EXISTS (
    SELECT 1
    FROM public.dep_batch b
    WHERE b.batch_id = v_batch_id
      AND b.status IN ('DEPOSITED', 'CANCELLED')
  ) THEN
    RAISE EXCEPTION 'Cannot resubmit a batch that is already %',
      (
        SELECT status
        FROM public.dep_batch
        WHERE batch_id = v_batch_id
      );
  END IF;

  INSERT INTO public.dep_item (
    item_id,
    batch_id,
    collection_id,
    amount
  )
  SELECT
    gen_random_uuid(),
    v_batch_id,
    tc.collection_id,
    tc.amount
  FROM public.teacher_coll tc
  WHERE tc.school_id = p_school_id
    AND tc.week_start = v_week_start
    AND tc.week_end = v_week_end
    AND tc.amount > 0
  ON CONFLICT (collection_id)
  DO UPDATE SET
    batch_id = EXCLUDED.batch_id,
    amount = EXCLUDED.amount;

  UPDATE public.teacher_coll tc
  SET
    status = 'IN_BATCH',
    updated_at = now()
  WHERE tc.school_id = p_school_id
    AND tc.week_start = v_week_start
    AND tc.week_end = v_week_end
    AND tc.amount > 0
    AND EXISTS (
      SELECT 1
      FROM public.dep_item di
      WHERE di.batch_id = v_batch_id
        AND di.collection_id = tc.collection_id
    );

  UPDATE public.teacher_coll tc
  SET
    status = 'NO_DEPOSIT_REQUIRED',
    updated_at = now()
  WHERE tc.school_id = p_school_id
    AND tc.week_start = v_week_start
    AND tc.week_end = v_week_end
    AND COALESCE(tc.amount, 0) <= 0
    AND tc.status IS DISTINCT FROM 'NO_DEPOSIT_REQUIRED';

  PERFORM public.recalc_deposit_batch_expected(v_batch_id);

  SELECT COALESCE(expected_amount, 0)
  INTO v_expected
  FROM public.dep_batch
  WHERE batch_id = v_batch_id;

  IF COALESCE(v_expected, 0) <= 0 THEN
    UPDATE public.dep_batch
    SET status = 'NO_DEPOSIT_REQUIRED'
    WHERE batch_id = v_batch_id;

    RAISE EXCEPTION 'No positive teacher collections found for this school and week';
  END IF;

  RETURN v_batch_id;
END;
$function$;
