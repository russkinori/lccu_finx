-- =============================================================
-- Security fix: Add is_admin() guard to admin SECURITY DEFINER
-- functions that lacked it.
--
-- Affected functions (all callable by the `authenticated` role but
-- missing an authorization check in their bodies):
--   1. admin_apply_user_profile   (create/update/delete/reactivate)
--   2. admin_deactivate_user      (2-param and 3-param overloads)
--   3. admin_hard_delete_user     (1-param and 2-param overloads)
--   4. admin_reactivate_user      (1-param and 2-param overloads)
--   5. admin_get_user_delete_guard
--
-- Each function now raises 'Admin access required' (P0001) when
-- called by a non-admin authenticated user, matching the pattern
-- already used by admin_assign_role and admin_remove_role.
-- =============================================================

-- -----------------------------------------------------------
-- 1. admin_apply_user_profile
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_apply_user_profile(
  p_mode          text,
  p_auth_user_id  uuid,
  p_role          text    DEFAULT NULL::text,
  p_payload       jsonb   DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app_admin' -- NOSONAR S1192
AS $function$
DECLARE
  v_mode text := lower(coalesce(trim(p_mode), ''));
  v_role text := lower(coalesce(trim(p_role), coalesce_text_path(p_payload, ARRAY['role','role_name','roleName'])));

  v_email      text := coalesce_text_path(p_payload, ARRAY['email']);
  v_first_name text := coalesce_text_path(p_payload, ARRAY['first_name','firstName']);
  v_last_name  text := coalesce_text_path(p_payload, ARRAY['last_name','lastName']);

  v_gender_name text := nullif(trim(coalesce_text_path(p_payload, ARRAY['gender'])), '');
  v_gender_id   uuid;
  v_title       text := nullif(trim(coalesce_text_path(p_payload, ARRAY['title'])), '');

  v_school_id uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['school_id','schoolId']), 'school_id'); -- NOSONAR S1192
  v_class_id  uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['class_id','classId']), 'class_id'); -- NOSONAR S1192

  v_acc_number       text := coalesce_text_path(p_payload, ARRAY['student_account_no','student_account_number','account_number','acc_number','accNumber']);
  v_opening_bal_text text := coalesce_text_path(p_payload, ARRAY['student_account_opening_balance','opening_balance','openingBal','opening_bal']);
  v_opening_bal      numeric;

  v_guardian_user_id uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['guardian_user_id','guardianUserId','guardian_id','guardianId']), 'guardian_user_id'); -- NOSONAR S1192
  v_guardian_type_id uuid := try_uuid(coalesce_text_path(p_payload, ARRAY['guardian_type_id','guardianTypeId']), 'guardian_type_id'); -- NOSONAR S1192

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

  v_branch_id uuid := try_uuid(
    coalesce_text_path(p_payload, ARRAY['credit_union_id','creditUnionId','branch_id','branchId']),
    'branch_id'
  );

  v_active_class_id uuid;
  v_effective_school_id uuid;
  v_effective_branch_id uuid;

  v_now timestamptz := now();
BEGIN
  -- Authorization guard
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE = 'P0001'; -- NOSONAR S1192
  END IF;

  IF v_mode NOT IN ('create','update','delete','reactivate') THEN -- NOSONAR S1192
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

  IF v_user.user_id IS NULL THEN
    INSERT INTO public."user"(
      user_id, email, first_name, last_name, gender_id, is_active, created_at, updated_at
    )
    VALUES (
      p_auth_user_id, v_email, v_first_name, v_last_name, v_gender_id, true, v_now, v_now
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

  IF v_student.student_id IS NOT NULL THEN
    v_student_account_id := public.ensure_student_account(
      p_student_id  := v_student.student_id,
      p_school_id   := coalesce(v_school_id, v_student.school_id),
      p_opening_bal := v_opening_bal,
      p_acc_number  := v_acc_number
    );
  END IF;

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

  IF v_role = 'teacher' THEN
    SELECT * INTO v_teacher FROM public.teacher WHERE user_id = p_auth_user_id;

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
    SELECT * INTO v_teacher FROM public.teacher WHERE user_id = p_auth_user_id LIMIT 1;
  END IF;

  IF v_role = 'principal' THEN
    SELECT * INTO v_principal FROM public.principal WHERE user_id = p_auth_user_id;

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

  IF v_role = 'teller' THEN
    SELECT * INTO v_teller FROM public.teller WHERE user_id = p_auth_user_id;

    IF v_teller.teller_id IS NULL THEN
      IF v_branch_id IS NULL THEN
        RAISE EXCEPTION 'credit_union_id (branch_id) is required when creating a teller';
      END IF;

      INSERT INTO public.teller(teller_id, user_id, branch_id, title, created_at, updated_at)
      VALUES (gen_random_uuid(), p_auth_user_id, v_branch_id, v_title, v_now, v_now)
      RETURNING * INTO v_teller;
    ELSE
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

  IF v_role = 'admin' THEN
    SELECT * INTO v_admin FROM public.admin WHERE user_id = p_auth_user_id LIMIT 1;

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

  v_active_class_id     := coalesce(v_student_class.class_id, v_class_id);
  v_effective_school_id := coalesce(v_student.school_id, v_teacher.school_id, v_principal.school_id, v_school_id);
  v_effective_branch_id := coalesce(v_teller.branch_id, null);

  RETURN jsonb_build_object(
    'user_id',           v_user.user_id,
    'email',             v_user.email,
    'first_name',        v_user.first_name,
    'last_name',         v_user.last_name,
    'role',              v_role,
    'student_id',        v_student.student_id,
    'student_class_id',  v_student_class_id,
    'class_id',          v_active_class_id,
    'guardian_id',       coalesce(v_guardian_self.guardian_id, v_guardian_target.guardian_id),
    'guardian_user_id',  v_guardian_user_id,
    'guardian_link_id',  v_guardian_link_id,
    'guardian_type_id',  coalesce(v_guardian_link.type_id, v_guardian_type_id),
    'teacher_id',        v_teacher.teacher_id,
    'principal_id',      v_principal.principal_id,
    'teller_id',         v_teller.teller_id,
    'school_id',         v_effective_school_id,
    'credit_union_id',   v_effective_branch_id,
    'student_account_id', v_student_account_id
  );
END;
$function$;

-- -----------------------------------------------------------
-- 2a. admin_deactivate_user (3-param overload)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_deactivate_user(
  p_auth_user_id  uuid,
  p_reason        text  DEFAULT NULL::text,
  p_actor_user_id uuid  DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_roles         text[] := '{}'::text[];
  v_actor_user_id uuid;
begin
  -- Authorization guard
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  if p_auth_user_id is null then
    raise exception 'auth_user_id is required'; -- NOSONAR S1192
  end if;

  v_actor_user_id := coalesce(p_actor_user_id, auth.uid());

  if v_actor_user_id is null then
    raise exception 'actor_user_id is required'; -- NOSONAR S1192
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
    user_id, prior_role_names, reason, deactivated_by, deactivated_at, reactivated_at
  )
  values (
    p_auth_user_id, v_roles, p_reason, v_actor_user_id, now(), null
  )
  on conflict (user_id) do update
    set prior_role_names = excluded.prior_role_names,
        reason           = excluded.reason,
        deactivated_by   = excluded.deactivated_by,
        deactivated_at   = excluded.deactivated_at,
        reactivated_at   = null;

  delete from public.user_role where user_id = p_auth_user_id;

  update public."user"
     set is_active  = false,
         updated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'deactivated',      true,
    'auth_user_id',     p_auth_user_id, -- NOSONAR S1192
    'prior_role_names', to_jsonb(v_roles),
    'actor_user_id',    v_actor_user_id -- NOSONAR S1192
  );
end;
$function$;

-- -----------------------------------------------------------
-- 2b. admin_deactivate_user (2-param overload)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_deactivate_user(
  p_auth_user_id uuid,
  p_reason       text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_roles text[] := '{}';
begin
  -- Authorization guard
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

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
    user_id, prior_role_names, reason, deactivated_by, deactivated_at, reactivated_at
  )
  values (
    p_auth_user_id, v_roles, p_reason, auth.uid(), now(), null
  )
  on conflict (user_id) do update
    set prior_role_names = excluded.prior_role_names,
        reason           = excluded.reason,
        deactivated_by   = excluded.deactivated_by,
        deactivated_at   = excluded.deactivated_at,
        reactivated_at   = null;

  delete from public.user_role where user_id = p_auth_user_id;

  update public."user"
     set is_active  = false,
         updated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'deactivated',      true,
    'auth_user_id',     p_auth_user_id,
    'prior_role_names', to_jsonb(v_roles)
  );
end;
$function$;

-- -----------------------------------------------------------
-- 3. admin_get_user_delete_guard
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_user_delete_guard(p_auth_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_student_id   uuid;
  v_guardian_id  uuid;
  v_teacher_id   uuid;
  v_principal_id uuid;
  v_teller_id    uuid;

  v_roles    text[] := '{}';
  v_blockers jsonb  := '[]'::jsonb;
  v_count    bigint := 0;
begin
  -- Authorization guard
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  if not exists (
    select 1 from public."user" u where u.user_id = p_auth_user_id
  ) then
    return jsonb_build_object(
      'can_hard_delete', false, -- NOSONAR S1192
      'auth_user_id',    p_auth_user_id,
      'role_names',      to_jsonb(v_roles),
      'blockers',        jsonb_build_array( -- NOSONAR S1192
        jsonb_build_object('code', 'USER_NOT_FOUND', 'message', 'User record not found.') -- NOSONAR S1192
      )
    );
  end if;

  select coalesce(array_agg(r.role_name order by r.role_name), '{}'::text[])
    into v_roles
  from public.user_role ur
  join public.role r on r.role_id = ur.role_id
  where ur.user_id = p_auth_user_id;

  select s.student_id   into v_student_id   from public.student   s where s.user_id = p_auth_user_id limit 1;
  select g.guardian_id  into v_guardian_id  from public.guardian  g where g.user_id = p_auth_user_id limit 1;
  select t.teacher_id   into v_teacher_id   from public.teacher   t where t.user_id = p_auth_user_id limit 1;
  select p.principal_id into v_principal_id from public.principal p where p.user_id = p_auth_user_id limit 1;
  select t.teller_id    into v_teller_id    from public.teller    t where t.user_id = p_auth_user_id limit 1;

  if v_student_id is not null then
    select count(*) into v_count from public.student_acc sa where sa.student_id = v_student_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','STUDENT_ACCOUNT_EXISTS','count',v_count,'message','Student account records exist.')); -- NOSONAR S1192
    end if;

    select count(*) into v_count from public.transactions t where t.student_id = v_student_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','STUDENT_TRANSACTION_HISTORY','count',v_count,'message','Student transaction history exists.'));
    end if;

    select count(*) into v_count from public.withdrawal_req wr where wr.student_id = v_student_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','STUDENT_WITHDRAWAL_HISTORY','count',v_count,'message','Student withdrawal request history exists.'));
    end if;
  end if;

  if v_guardian_id is not null then
    select count(*) into v_count from public.student_guardian sg where sg.guardian_id = v_guardian_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','GUARDIAN_LINKS_EXIST','count',v_count,'message','Guardian is still linked to student records.'));
    end if;

    select count(*) into v_count from public.withdrawal_req wr where wr.guardian_id = v_guardian_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','GUARDIAN_DECISION_HISTORY','count',v_count,'message','Guardian approval/decision history exists.'));
    end if;
  end if;

  if v_teacher_id is not null then
    select count(*) into v_count from public.transactions t where t.teacher_id = v_teacher_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','TEACHER_TRANSACTION_HISTORY','count',v_count,'message','Teacher transaction history exists.'));
    end if;

    select count(*) into v_count from public.withdrawal_req wr where wr.teacher_id = v_teacher_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','TEACHER_WITHDRAWAL_HISTORY','count',v_count,'message','Teacher withdrawal processing history exists.'));
    end if;

    select count(*) into v_count from public.teacher_coll tc where tc.teacher_id = v_teacher_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','TEACHER_COLLECTION_HISTORY','count',v_count,'message','Teacher collection history exists.'));
    end if;

    select count(*) into v_count from public.cu_dep_event e where e.deposited_by_teacher_id = v_teacher_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','TEACHER_DEPOSIT_HISTORY','count',v_count,'message','Teacher deposit attribution history exists.'));
    end if;

    select count(*) into v_count from public.cu_payout p where p.requested_by_teacher_id = v_teacher_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','TEACHER_PAYOUT_HISTORY','count',v_count,'message','Teacher payout request history exists.'));
    end if;
  end if;

  if v_principal_id is not null then
    select count(*) into v_count from public.cu_payout p where p.requested_by_principal_id = v_principal_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','PRINCIPAL_PAYOUT_HISTORY','count',v_count,'message','Principal payout request history exists.'));
    end if;
  end if;

  if v_teller_id is not null then
    select count(*) into v_count from public.cu_dep_event e where e.posted_by_teller_id = v_teller_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','TELLER_DEPOSIT_HISTORY','count',v_count,'message','Teller deposit posting history exists.'));
    end if;

    select count(*) into v_count from public.cu_payout p where p.posted_by_teller_id = v_teller_id;
    if v_count > 0 then
      v_blockers := v_blockers || jsonb_build_array(jsonb_build_object('code','TELLER_PAYOUT_HISTORY','count',v_count,'message','Teller payout posting history exists.'));
    end if;
  end if;

  return jsonb_build_object(
    'can_hard_delete', jsonb_array_length(v_blockers) = 0,
    'auth_user_id',    p_auth_user_id,
    'role_names',      to_jsonb(v_roles),
    'blockers',        v_blockers
  );
end;
$function$;

-- -----------------------------------------------------------
-- 4a. admin_hard_delete_user (2-param overload)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_hard_delete_user(
  p_auth_user_id  uuid,
  p_actor_user_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_guard        jsonb;
  v_student_id   uuid;
  v_guardian_id  uuid;
  v_teacher_id   uuid;
  v_principal_id uuid;
  v_teller_id    uuid;
  v_actor_user_id uuid;
begin
  -- Authorization guard
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  v_actor_user_id := coalesce(p_actor_user_id, auth.uid());

  if v_actor_user_id is null then
    raise exception 'actor_user_id is required';
  end if;

  if v_actor_user_id = p_auth_user_id then
    raise exception 'You cannot delete your own account' using errcode = 'P0001';
  end if;

  v_guard := public.admin_get_user_delete_guard(p_auth_user_id);

  if coalesce((v_guard ->> 'can_hard_delete')::boolean, false) is not true then
    raise exception 'Hard delete is not allowed for this user'
      using errcode = 'P0001',
            detail  = coalesce((v_guard -> 'blockers')::text, '[]');
  end if;

  select student_id   into v_student_id   from public.student   where user_id = p_auth_user_id limit 1;
  select guardian_id  into v_guardian_id  from public.guardian  where user_id = p_auth_user_id limit 1;
  select teacher_id   into v_teacher_id   from public.teacher   where user_id = p_auth_user_id limit 1;
  select principal_id into v_principal_id from public.principal where user_id = p_auth_user_id limit 1;
  select teller_id    into v_teller_id    from public.teller    where user_id = p_auth_user_id limit 1;

  delete from public.notification              where user_id = p_auth_user_id;
  delete from public.user_deactivation_snapshot where user_id = p_auth_user_id;

  if v_student_id is not null then
    delete from public.student_guardian where student_id = v_student_id;
    delete from public.student_class    where student_id = v_student_id;
    delete from public.student_acc      where student_id = v_student_id;
    delete from public.student          where student_id = v_student_id;
  end if;

  if v_guardian_id is not null then
    delete from public.student_guardian where guardian_id = v_guardian_id;
    delete from public.guardian         where guardian_id = v_guardian_id;
  end if;

  if v_teacher_id   is not null then delete from public.teacher   where teacher_id   = v_teacher_id;   end if;
  if v_principal_id is not null then delete from public.principal where principal_id = v_principal_id; end if;
  if v_teller_id    is not null then delete from public.teller    where teller_id    = v_teller_id;    end if;

  delete from public.admin     where user_id = p_auth_user_id;
  delete from public.user_role where user_id = p_auth_user_id;
  delete from public."user"    where user_id = p_auth_user_id;

  return jsonb_build_object(
    'hard_deleted',  true,
    'auth_user_id',  p_auth_user_id,
    'actor_user_id', v_actor_user_id
  );
end;
$function$;

-- -----------------------------------------------------------
-- 4b. admin_hard_delete_user (1-param overload)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_hard_delete_user(p_auth_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_guard        jsonb;
  v_student_id   uuid;
  v_guardian_id  uuid;
  v_teacher_id   uuid;
  v_principal_id uuid;
  v_teller_id    uuid;
begin
  -- Authorization guard
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  v_guard := public.admin_get_user_delete_guard(p_auth_user_id);

  if coalesce((v_guard ->> 'can_hard_delete')::boolean, false) is not true then
    raise exception 'Hard delete is not allowed for this user'
      using errcode = 'P0001',
            detail  = coalesce((v_guard -> 'blockers')::text, '[]');
  end if;

  select student_id   into v_student_id   from public.student   where user_id = p_auth_user_id limit 1;
  select guardian_id  into v_guardian_id  from public.guardian  where user_id = p_auth_user_id limit 1;
  select teacher_id   into v_teacher_id   from public.teacher   where user_id = p_auth_user_id limit 1;
  select principal_id into v_principal_id from public.principal where user_id = p_auth_user_id limit 1;
  select teller_id    into v_teller_id    from public.teller    where user_id = p_auth_user_id limit 1;

  delete from public.notification              where user_id = p_auth_user_id;
  delete from public.user_deactivation_snapshot where user_id = p_auth_user_id;

  if v_student_id is not null then
    delete from public.student_guardian where student_id = v_student_id;
    delete from public.student_class    where student_id = v_student_id;
    delete from public.student_acc      where student_id = v_student_id;
    delete from public.student          where student_id = v_student_id;
  end if;

  if v_guardian_id is not null then
    delete from public.student_guardian where guardian_id = v_guardian_id;
    delete from public.guardian         where guardian_id = v_guardian_id;
  end if;

  if v_teacher_id   is not null then delete from public.teacher   where teacher_id   = v_teacher_id;   end if;
  if v_principal_id is not null then delete from public.principal where principal_id = v_principal_id; end if;
  if v_teller_id    is not null then delete from public.teller    where teller_id    = v_teller_id;    end if;

  delete from public.admin     where user_id = p_auth_user_id;
  delete from public.user_role where user_id = p_auth_user_id;
  delete from public."user"    where user_id = p_auth_user_id;

  return jsonb_build_object(
    'hard_deleted', true,
    'auth_user_id', p_auth_user_id
  );
end;
$function$;

-- -----------------------------------------------------------
-- 5a. admin_reactivate_user (2-param overload)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(
  p_auth_user_id  uuid,
  p_actor_user_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_snapshot      record;
  v_actor_user_id uuid;
begin
  -- Authorization guard
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  v_actor_user_id := coalesce(p_actor_user_id, auth.uid());

  if v_actor_user_id is null then
    raise exception 'actor_user_id is required';
  end if;

  if v_actor_user_id = p_auth_user_id then
    raise exception 'You cannot reactivate your own account from this screen' using errcode = 'P0001';
  end if;

  select * into v_snapshot
  from public.user_deactivation_snapshot
  where user_id = p_auth_user_id
  limit 1;

  if not found then
    raise exception 'No deactivation snapshot found for user %', p_auth_user_id;
  end if;

  update public."user"
     set is_active  = true,
         updated_at = now()
   where user_id = p_auth_user_id;

  insert into public.user_role (user_role_id, user_id, role_id, created_at)
  select gen_random_uuid(), p_auth_user_id, r.role_id, now()
  from public.role r
  where r.role_name = any(v_snapshot.prior_role_names)
  on conflict (user_id, role_id) do nothing;

  update public.user_deactivation_snapshot
     set reactivated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'reactivated',    true,
    'auth_user_id',   p_auth_user_id,
    'restored_roles', to_jsonb(v_snapshot.prior_role_names),
    'actor_user_id',  v_actor_user_id
  );
end;
$function$;

-- -----------------------------------------------------------
-- 5b. admin_reactivate_user (1-param overload)
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_auth_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_snapshot record;
begin
  -- Authorization guard
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = 'P0001';
  end if;

  if p_auth_user_id is null then
    raise exception 'auth_user_id is required';
  end if;

  select * into v_snapshot
  from public.user_deactivation_snapshot
  where user_id = p_auth_user_id
  limit 1;

  if not found then
    raise exception 'No deactivation snapshot found for user %', p_auth_user_id;
  end if;

  update public."user"
     set is_active  = true,
         updated_at = now()
   where user_id = p_auth_user_id;

  insert into public.user_role (user_role_id, user_id, role_id, created_at)
  select gen_random_uuid(), p_auth_user_id, r.role_id, now()
  from public.role r
  where r.role_name = any(v_snapshot.prior_role_names)
  on conflict (user_id, role_id) do nothing;

  update public.user_deactivation_snapshot
     set reactivated_at = now()
   where user_id = p_auth_user_id;

  return jsonb_build_object(
    'reactivated',    true,
    'auth_user_id',   p_auth_user_id,
    'restored_roles', to_jsonb(v_snapshot.prior_role_names)
  );
end;
$function$;
