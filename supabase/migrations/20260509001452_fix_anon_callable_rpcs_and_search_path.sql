-- =============================================================
-- Security fixes identified by Supabase database linter
--
-- Fix 1 (lint 0028): teller_pending_deposit_batches and
--   principal_last_teacher_deposit_detail were callable by the
--   unauthenticated anon role because GRANT TO authenticated was
--   added without first revoking the default PUBLIC grant.
--   Both functions return real financial data, so this surface
--   must be closed.
--
-- Fix 2 (lint 0011): admin_transaction_report had no SET
--   search_path clause. Although it is SECURITY INVOKER (not
--   SECURITY DEFINER), a mutable search_path still allows an
--   attacker who can inject objects into the caller's search_path
--   to shadow public.* functions used inside the query.
--   Adding the clause eliminates that risk.
-- =============================================================

-- -----------------------------------------------------------
-- Fix 1a: teller_pending_deposit_batches — revoke anon access
-- -----------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.teller_pending_deposit_batches(uuid) FROM PUBLIC;

-- -----------------------------------------------------------
-- Fix 1b: principal_last_teacher_deposit_detail — revoke anon access
-- -----------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.principal_last_teacher_deposit_detail(uuid) FROM PUBLIC;

-- -----------------------------------------------------------
-- Fix 2: admin_transaction_report — pin search_path
-- The function body is unchanged; only the options block is added.
-- SECURITY INVOKER is kept (runs as the calling user so RLS gates access).
-- -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_transaction_report(
  p_from              timestamptz  DEFAULT NULL,
  p_to                timestamptz  DEFAULT NULL,
  p_school_id         uuid         DEFAULT NULL,
  p_class_id          uuid         DEFAULT NULL,
  p_teacher_name_like text         DEFAULT NULL,
  p_student_name_like text         DEFAULT NULL,
  p_type              text         DEFAULT 'all',
  p_limit             int          DEFAULT 5000
)
RETURNS TABLE (
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
  transaction_count  bigint,
  total_amount       numeric
)
LANGUAGE sql
STABLE
SET search_path TO 'pg_catalog', 'public' -- NOSONAR(plsql:S1192)
AS $$
  WITH _tx AS (
    SELECT
      t.transaction_id,
      t.created_at,
      tt.name                    AS tx_type,
      t.amount::numeric          AS amount,
      s.school_id,
      s.name                     AS school_name,
      sc.class_id,
      sc.name                    AS class_name,
      te.teacher_id,
      tu.first_name              AS teacher_first_name,
      tu.last_name               AS teacher_last_name,
      st.student_id,
      su.first_name              AS student_first_name,
      su.last_name               AS student_last_name
    FROM      public.transactions  t
    JOIN      public.tx_type  tt  ON tt.type_id    = t.type_id
    LEFT JOIN public.teacher  te  ON te.teacher_id = t.teacher_id
    LEFT JOIN public.user     tu  ON tu.user_id    = te.user_id
    LEFT JOIN public.student  st  ON st.student_id = t.student_id
    LEFT JOIN public.user     su  ON su.user_id    = st.user_id
    LEFT JOIN public.school   s   ON s.school_id   = COALESCE(st.school_id, te.school_id)
    LEFT JOIN LATERAL (
      SELECT stc2.class_id
      FROM public.student_class stc2
      WHERE stc2.student_id = st.student_id
        AND stc2.start_date <= t.created_at::date
        AND (stc2.end_date IS NULL OR stc2.end_date >= t.created_at::date)
      ORDER BY stc2.start_date DESC
      LIMIT 1
    ) stc ON TRUE
    LEFT JOIN public.class    sc  ON sc.class_id   = stc.class_id
    WHERE
      (p_from             IS NULL OR t.created_at   >= p_from)
      AND (p_to           IS NULL OR t.created_at   <= p_to)
      AND (p_school_id    IS NULL OR COALESCE(st.school_id, te.school_id) = p_school_id)
      AND (p_class_id     IS NULL OR stc.class_id    = p_class_id)
      AND (p_teacher_name_like IS NULL -- NOSONAR(plsql:S1192)
           OR tu.first_name ILIKE '%' || p_teacher_name_like || '%'
           OR tu.last_name  ILIKE '%' || p_teacher_name_like || '%'
           OR (tu.first_name || ' ' || COALESCE(tu.last_name, ''))
              ILIKE '%' || p_teacher_name_like || '%')
      AND (p_student_name_like IS NULL
           OR su.first_name ILIKE '%' || p_student_name_like || '%'
           OR su.last_name  ILIKE '%' || p_student_name_like || '%'
           OR (su.first_name || ' ' || COALESCE(su.last_name, ''))
              ILIKE '%' || p_student_name_like || '%')
      AND (
        p_type IN ('all', 'count') -- NOSONAR(plsql:S1192)
        OR (p_type = 'deposit'    AND LOWER(tt.name) LIKE '%deposit%')
        OR (p_type = 'withdrawal' AND LOWER(tt.name) LIKE '%withdrawal%')
      )
  )

  SELECT
    NULL::uuid        AS transaction_id,
    NULL::timestamptz AS created_at,
    'count'::text     AS tx_type,
    NULL::numeric     AS amount,
    NULL::uuid        AS school_id,
    NULL::text        AS school_name,
    NULL::uuid        AS class_id,
    NULL::text        AS class_name,
    NULL::uuid        AS teacher_id,
    NULL::text        AS teacher_first_name,
    NULL::text        AS teacher_last_name,
    NULL::uuid        AS student_id,
    NULL::text        AS student_first_name,
    NULL::text        AS student_last_name,
    COUNT(*)          AS transaction_count,
    COALESCE(SUM(amount), 0) AS total_amount
  FROM _tx
  WHERE p_type = 'count'

  UNION ALL

  SELECT
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
    NULL::bigint  AS transaction_count,
    NULL::numeric AS total_amount
  FROM _tx
  WHERE p_type != 'count'
  ORDER BY created_at DESC NULLS LAST
  LIMIT p_limit;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_transaction_report(
  timestamptz, timestamptz, uuid, uuid, text, text, text, int
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_transaction_report(
  timestamptz, timestamptz, uuid, uuid, text, text, text, int
) TO authenticated;
