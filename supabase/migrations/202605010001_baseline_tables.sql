-- Baseline schema: all tables in dependency order.
-- Uses CREATE TABLE IF NOT EXISTS to be safe on existing databases.
-- Foreign key dependency order is maintained.

CREATE TABLE IF NOT EXISTS public.address (
  address_id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_off text,
  district text,
  zip text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  town text,
  CONSTRAINT address_pkey PRIMARY KEY (address_id)
);
CREATE TABLE IF NOT EXISTS public.gender (
  gender_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  CONSTRAINT gender_pkey PRIMARY KEY (gender_id)
);
CREATE TABLE IF NOT EXISTS public.level (
  level_id uuid NOT NULL DEFAULT gen_random_uuid(),
  level text NOT NULL,
  CONSTRAINT level_pkey PRIMARY KEY (level_id)
);
CREATE TABLE IF NOT EXISTS public.tx_stat (
  status_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  CONSTRAINT tx_stat_pkey PRIMARY KEY (status_id)
);
CREATE TABLE IF NOT EXISTS public.tx_type (
  type_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  CONSTRAINT tx_type_pkey PRIMARY KEY (type_id)
);
CREATE TABLE IF NOT EXISTS public.role (
  role_id uuid NOT NULL DEFAULT gen_random_uuid(),
  role_name text NOT NULL UNIQUE,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT role_pkey PRIMARY KEY (role_id)
);
CREATE TABLE IF NOT EXISTS public.permission (
  permission_id uuid NOT NULL DEFAULT gen_random_uuid(),
  permission_name text NOT NULL UNIQUE,
  description text,
  CONSTRAINT permission_pkey PRIMARY KEY (permission_id)
);
CREATE TABLE IF NOT EXISTS public.title (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  option text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT title_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS public.guardian_type (
  type_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  CONSTRAINT guardian_type_pkey PRIMARY KEY (type_id)
);
CREATE TABLE IF NOT EXISTS public.user (
  first_name text NOT NULL,
  email text NOT NULL UNIQUE,
  gender_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  is_active boolean DEFAULT true,
  user_id uuid NOT NULL DEFAULT auth.uid() UNIQUE,
  last_name text,
  CONSTRAINT user_pkey PRIMARY KEY (user_id),
  CONSTRAINT users_gender_id_fkey FOREIGN KEY (gender_id) REFERENCES public.gender(gender_id),
  CONSTRAINT user_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE IF NOT EXISTS public.school (
  school_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  Level uuid,
  CONSTRAINT school_pkey PRIMARY KEY (school_id),
  CONSTRAINT school_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT school_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id),
  CONSTRAINT schools_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id),
  CONSTRAINT schools_Level_fkey FOREIGN KEY (Level) REFERENCES public.level(level_id)
);
CREATE TABLE IF NOT EXISTS public.cu_branch (
  branch_id uuid NOT NULL DEFAULT gen_random_uuid(),
  branch text NOT NULL,
  address_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  CONSTRAINT cu_branch_pkey PRIMARY KEY (branch_id),
  CONSTRAINT cu_branch_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT cu_branch_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id),
  CONSTRAINT credit_unions_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id)
);
CREATE TABLE IF NOT EXISTS public.teacher (
  teacher_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  school_id uuid NOT NULL,
  title text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  CONSTRAINT teacher_pkey PRIMARY KEY (teacher_id),
  CONSTRAINT teacher_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id),
  CONSTRAINT teachers_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT teacher_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id),
  CONSTRAINT teacher_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.student (
  student_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  school_id uuid NOT NULL,
  date_of_birth date,
  enrollment_date date NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  CONSTRAINT student_pkey PRIMARY KEY (student_id),
  CONSTRAINT student_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id),
  CONSTRAINT students_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT student_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT student_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.guardian (
  guardian_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  address_id uuid,
  mobile text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  title text,
  CONSTRAINT guardian_pkey PRIMARY KEY (guardian_id),
  CONSTRAINT guardians_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.address(address_id),
  CONSTRAINT guardian_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id),
  CONSTRAINT guardian_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT guardian_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.teller (
  teller_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  branch_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  title text,
  CONSTRAINT teller_pkey PRIMARY KEY (teller_id),
  CONSTRAINT teller_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id),
  CONSTRAINT tellers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.cu_branch(branch_id)
);
CREATE TABLE IF NOT EXISTS public.principal (
  principal_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  school_id uuid NOT NULL,
  title text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  CONSTRAINT principal_pkey PRIMARY KEY (principal_id),
  CONSTRAINT principals_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT principal_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id),
  CONSTRAINT principal_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT principal_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.admin (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  user_id uuid,
  title text,
  CONSTRAINT admin_pkey PRIMARY KEY (id),
  CONSTRAINT admin_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.file_upload (
  file_id uuid NOT NULL DEFAULT gen_random_uuid(),
  filename text NOT NULL,
  file_path text NOT NULL,
  mime_type text,
  size_bytes bigint,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  uploaded_at timestamp with time zone DEFAULT now(),
  uploaded_by uuid,
  CONSTRAINT file_upload_pkey PRIMARY KEY (file_id),
  CONSTRAINT file_upload_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.role_perm (
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  CONSTRAINT role_perm_pkey PRIMARY KEY (role_id, permission_id),
  CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permission(permission_id),
  CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.role(role_id)
);
CREATE TABLE IF NOT EXISTS public.user_role (
  user_role_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  CONSTRAINT user_role_pkey PRIMARY KEY (user_role_id),
  CONSTRAINT user_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id),
  CONSTRAINT user_role_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.role(role_id)
);
CREATE TABLE IF NOT EXISTS public.user_deactivation_snapshot (
  user_id uuid NOT NULL,
  prior_role_names ARRAY NOT NULL DEFAULT '{}'::text[],
  reason text,
  deactivated_by uuid,
  deactivated_at timestamp with time zone NOT NULL DEFAULT now(),
  reactivated_at timestamp with time zone,
  CONSTRAINT user_deactivation_snapshot_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_deactivation_snapshot_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.notification (
  notification_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  is_read boolean DEFAULT false,
  entity_type text,
  entity_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notification_pkey PRIMARY KEY (notification_id)
);
CREATE TABLE IF NOT EXISTS public.balance_audit (
  audit_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  old_balance numeric NOT NULL,
  new_balance numeric NOT NULL,
  delta numeric NOT NULL,
  reason text NOT NULL,
  source_table text,
  source_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT balance_audit_pkey PRIMARY KEY (audit_id)
);
CREATE TABLE IF NOT EXISTS public.student_acc (
  account_id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL,
  school_id uuid NOT NULL,
  opening_bal numeric DEFAULT 0,
  status text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  acc_number text,
  closing_bal double precision,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT student_acc_pkey PRIMARY KEY (account_id),
  CONSTRAINT student_accounts_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT student_accounts_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id),
  CONSTRAINT student_acc_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT student_acc_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.teacher_coll (
  collection_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  week_start date NOT NULL,
  week_end date NOT NULL,
  amount double precision NOT NULL,
  slip_code text UNIQUE,
  slip_hash text,
  pdf_file_id uuid,
  status text NOT NULL DEFAULT 'PENDING_TELLER_SCAN'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at date,
  CONSTRAINT teacher_coll_pkey PRIMARY KEY (collection_id),
  CONSTRAINT teacher_collections_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT teacher_collections_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher(teacher_id),
  CONSTRAINT teacher_collections_pdf_file_id_fkey FOREIGN KEY (pdf_file_id) REFERENCES public.file_upload(file_id)
);
CREATE TABLE IF NOT EXISTS public.class (
  class_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  level_id uuid,
  CONSTRAINT class_pkey PRIMARY KEY (class_id),
  CONSTRAINT class_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.level(level_id)
);
CREATE TABLE IF NOT EXISTS public.student_guardian (
  sg_id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL,
  guardian_id uuid NOT NULL,
  type_id uuid NOT NULL,
  is_primary boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  CONSTRAINT student_guardian_pkey PRIMARY KEY (sg_id),
  CONSTRAINT student_guardian_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES public.guardian(guardian_id),
  CONSTRAINT student_guardian_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id),
  CONSTRAINT student_guardian_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.guardian_type(type_id)
);
CREATE TABLE IF NOT EXISTS public.student_class (
  student_class_id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL,
  class_id uuid NOT NULL,
  start_date date NOT NULL DEFAULT CURRENT_DATE,
  end_date date,
  CONSTRAINT student_class_pkey PRIMARY KEY (student_class_id),
  CONSTRAINT student_classes_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id),
  CONSTRAINT student_classes_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.class(class_id)
);
CREATE TABLE IF NOT EXISTS public.school_acc (
  account_number text NOT NULL,
  school_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  opening_bal double precision,
  status text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  closing_bal double precision CHECK (closing_bal >= 0::double precision),
  CONSTRAINT school_acc_pkey PRIMARY KEY (account_number),
  CONSTRAINT school_accounts_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.cu_branch(branch_id),
  CONSTRAINT school_accounts_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT school_acc_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT school_acc_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.withdrawal_pol (
  policy_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  require_all_guardians boolean NOT NULL DEFAULT false,
  cash_threshold numeric DEFAULT 100,
  cu_over_threshold boolean NOT NULL DEFAULT true,
  CONSTRAINT withdrawal_pol_pkey PRIMARY KEY (policy_id),
  CONSTRAINT withdrawal_policies_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id)
);
CREATE TABLE IF NOT EXISTS public.report_def (
  report_id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  sql_query text NOT NULL,
  parameters jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  CONSTRAINT report_def_pkey PRIMARY KEY (report_id),
  CONSTRAINT report_def_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT report_def_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.withdrawal_req (
  request_id uuid NOT NULL DEFAULT gen_random_uuid(),
  student_id uuid,
  teacher_id uuid,
  amount double precision NOT NULL,
  status_id uuid,
  requested_at timestamp with time zone DEFAULT now(),
  teacher_approved_at timestamp with time zone DEFAULT now(),
  guardian_approved_at timestamp with time zone DEFAULT now(),
  completed_at timestamp with time zone DEFAULT now(),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  updated_by uuid,
  guardian_id uuid,
  reason text,
  account_id uuid,
  CONSTRAINT withdrawal_req_pkey PRIMARY KEY (request_id),
  CONSTRAINT withdrawal_requests_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.tx_stat(status_id),
  CONSTRAINT withdrawal_requests_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id),
  CONSTRAINT withdrawal_requests_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher(teacher_id),
  CONSTRAINT withdrawal_req_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES public.guardian(guardian_id),
  CONSTRAINT withdrawal_req_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.student_acc(account_id)
);
CREATE TABLE IF NOT EXISTS public.bch_recon (
  reconciliation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  principal_id uuid NOT NULL,
  week_start_date date NOT NULL,
  week_end_date date NOT NULL,
  total_deposits double precision NOT NULL,
  total_withdrawals double precision NOT NULL,
  status_id uuid NOT NULL,
  submitted_at timestamp with time zone,
  verified_at timestamp with time zone,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  CONSTRAINT bch_recon_pkey PRIMARY KEY (reconciliation_id),
  CONSTRAINT batch_reconciliations_principal_id_fkey FOREIGN KEY (principal_id) REFERENCES public.principal(principal_id),
  CONSTRAINT batch_reconciliations_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT batch_reconciliations_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.tx_stat(status_id)
);
CREATE TABLE IF NOT EXISTS public.dep_batch (
  batch_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  week_start date NOT NULL,
  week_end date NOT NULL,
  status text NOT NULL DEFAULT 'OPEN'::text CHECK (status = ANY (ARRAY['OPEN'::text, 'SUBMITTED'::text, 'FLAGGED'::text, 'PARTIALLY_DEPOSITED'::text, 'DEPOSITED'::text, 'CANCELLED'::text, 'NO_DEPOSIT_REQUIRED'::text])),
  expected_amount numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  created_by uuid,
  submitted_at timestamp with time zone,
  submitted_by uuid,
  note text,
  CONSTRAINT dep_batch_pkey PRIMARY KEY (batch_id),
  CONSTRAINT deposit_batch_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT deposit_batch_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT deposit_batch_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES public.user(user_id)
);
CREATE TABLE IF NOT EXISTS public.transactions (
  transaction_id uuid NOT NULL DEFAULT gen_random_uuid(),
  amount double precision NOT NULL,
  type_id uuid NOT NULL,
  status_id uuid NOT NULL,
  student_id uuid,
  teacher_id uuid,
  teller_id uuid,
  notes text,
  receipt_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  account_id uuid,
  submitted_by_role text,
  day_batch_id uuid,
  request_id uuid,
  CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id),
  CONSTRAINT transactions_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.student_acc(account_id),
  CONSTRAINT transactions_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES public.file_upload(file_id),
  CONSTRAINT transactions_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.tx_stat(status_id),
  CONSTRAINT transactions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id),
  CONSTRAINT transactions_teller_id_fkey FOREIGN KEY (teller_id) REFERENCES public.teller(teller_id),
  CONSTRAINT transactions_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.tx_type(type_id),
  CONSTRAINT transactions_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher(teacher_id),
  CONSTRAINT transactions_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.withdrawal_req(request_id)
);
CREATE TABLE IF NOT EXISTS public.withdrawal_appr (
  approval_id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL,
  guardian_id uuid NOT NULL,
  decision text NOT NULL CHECK (decision = ANY (ARRAY['APPROVED'::text, 'DECLINED'::text])),
  decided_at timestamp with time zone NOT NULL DEFAULT now(),
  note text,
  status_id uuid,
  CONSTRAINT withdrawal_appr_pkey PRIMARY KEY (approval_id),
  CONSTRAINT withdrawal_approvals_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.withdrawal_req(request_id),
  CONSTRAINT withdrawal_approvals_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES public.guardian(guardian_id),
  CONSTRAINT withdrawal_appr_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.tx_stat(status_id)
);
CREATE TABLE IF NOT EXISTS public.tx_appr (
  approval_id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  guardian_id uuid NOT NULL,
  decision text NOT NULL CHECK (decision = ANY (ARRAY['APPROVED'::text, 'DECLINED'::text])),
  decided_at timestamp with time zone NOT NULL DEFAULT now(),
  note text,
  CONSTRAINT tx_appr_pkey PRIMARY KEY (approval_id),
  CONSTRAINT transaction_approvals_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES public.guardian(guardian_id)
);
CREATE TABLE IF NOT EXISTS public.day_bch (
  day_batch_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  teacher_id uuid,
  batch_date date NOT NULL,
  locked_at timestamp with time zone,
  locked_by uuid,
  closing_cash numeric,
  expected_cash numeric,
  discrepancy numeric,
  CONSTRAINT day_bch_pkey PRIMARY KEY (day_batch_id),
  CONSTRAINT day_bch_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES public.user(user_id),
  CONSTRAINT day_batches_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT day_batches_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher(teacher_id)
);
CREATE TABLE IF NOT EXISTS public.cu_dep_event (
  dep_event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  posted_by_teller_id uuid NOT NULL,
  posted_at timestamp with time zone NOT NULL DEFAULT now(),
  amount double precision NOT NULL,
  status text NOT NULL DEFAULT 'Posted'::text,
  receipt_file_id uuid,
  notes text,
  deposited_by_teacher_id uuid,
  CONSTRAINT cu_dep_event_pkey PRIMARY KEY (dep_event_id),
  CONSTRAINT cu_dep_event_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT cu_dep_event_posted_by_teller_id_fkey FOREIGN KEY (posted_by_teller_id) REFERENCES public.teller(teller_id),
  CONSTRAINT cu_dep_event_receipt_file_id_fkey FOREIGN KEY (receipt_file_id) REFERENCES public.file_upload(file_id),
  CONSTRAINT cu_dep_event_deposited_by_teacher_id_fkey FOREIGN KEY (deposited_by_teacher_id) REFERENCES public.teacher(teacher_id)
);
CREATE TABLE IF NOT EXISTS public.cu_payout (
  bank_payout_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  request_id uuid,
  payout_req_id uuid,
  amount double precision NOT NULL,
  posted_at timestamp with time zone NOT NULL DEFAULT now(),
  posted_by_teller_id uuid,
  note text,
  requested_by_role text,
  requested_by_teacher_id uuid,
  requested_by_principal_id uuid,
  CONSTRAINT cu_payout_pkey PRIMARY KEY (bank_payout_id),
  CONSTRAINT bank_payout_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT bank_payout_posted_by_teller_id_fkey FOREIGN KEY (posted_by_teller_id) REFERENCES public.teller(teller_id),
  CONSTRAINT cu_payout_requested_by_teacher_fkey FOREIGN KEY (requested_by_teacher_id) REFERENCES public.teacher(teacher_id),
  CONSTRAINT cu_payout_requested_by_principal_fkey FOREIGN KEY (requested_by_principal_id) REFERENCES public.principal(principal_id)
);
CREATE TABLE IF NOT EXISTS public.cu_payout_req (
  payout_req_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  request_id uuid NOT NULL,
  amount double precision NOT NULL,
  status text NOT NULL DEFAULT 'PENDING'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  created_by uuid,
  CONSTRAINT cu_payout_req_pkey PRIMARY KEY (payout_req_id),
  CONSTRAINT cu_payout_req_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user(user_id),
  CONSTRAINT bank_payout_req_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT bank_payout_req_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.withdrawal_req(request_id)
);
CREATE TABLE IF NOT EXISTS public.cash_event (
  cash_event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  teacher_id uuid,
  request_id uuid,
  kind text NOT NULL CHECK (kind = ANY (ARRAY['INFLOW'::text, 'OUTFLOW'::text])),
  source text NOT NULL CHECK (source = ANY (ARRAY['CLASSROOM'::text, 'BANK_DIRECT'::text])),
  amount numeric NOT NULL,
  affects_funds boolean NOT NULL DEFAULT true,
  occurred_at timestamp with time zone NOT NULL DEFAULT now(),
  note text,
  CONSTRAINT cash_event_pkey PRIMARY KEY (cash_event_id),
  CONSTRAINT cash_event_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.school(school_id),
  CONSTRAINT cash_event_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher(teacher_id),
  CONSTRAINT cash_event_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.withdrawal_req(request_id)
);
CREATE TABLE IF NOT EXISTS public.dep_item (
  item_id uuid NOT NULL DEFAULT gen_random_uuid(),
  collection_id uuid NOT NULL,
  amount double precision NOT NULL,
  batch_id uuid NOT NULL,
  CONSTRAINT dep_item_pkey PRIMARY KEY (item_id),
  CONSTRAINT deposit_items_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES public.teacher_coll(collection_id),
  CONSTRAINT dep_item_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.dep_batch(batch_id)
);
CREATE TABLE IF NOT EXISTS public.cu_dep_event_batch (
  dep_event_id uuid NOT NULL,
  batch_id uuid NOT NULL,
  applied_amount numeric NOT NULL CHECK (applied_amount > 0::numeric),
  school_id uuid NOT NULL,
  CONSTRAINT cu_dep_event_batch_pkey PRIMARY KEY (dep_event_id, batch_id),
  CONSTRAINT cu_dep_event_batch_dep_event_id_fkey FOREIGN KEY (dep_event_id) REFERENCES public.cu_dep_event(dep_event_id),
  CONSTRAINT cu_dep_event_batch_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.dep_batch(batch_id)
);
CREATE TABLE IF NOT EXISTS public.cu_dep_event_item (
  dep_event_id uuid NOT NULL,
  collection_id uuid NOT NULL,
  applied_amount numeric NOT NULL CHECK (applied_amount >= 0::numeric),
  CONSTRAINT cu_dep_event_item_pkey PRIMARY KEY (dep_event_id, collection_id),
  CONSTRAINT cu_dep_event_item_dep_event_id_fkey FOREIGN KEY (dep_event_id) REFERENCES public.cu_dep_event(dep_event_id),
  CONSTRAINT cu_dep_event_item_collection_id_fkey FOREIGN KEY (collection_id) REFERENCES public.teacher_coll(collection_id)
);

-- Unique constraint needed by ON CONFLICT (user_id, role_id) in functions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_user_role_user_role'
      AND conrelid = 'public.user_role'::regclass
  ) THEN
    ALTER TABLE public.user_role
      ADD CONSTRAINT uq_user_role_user_role UNIQUE (user_id, role_id);
  END IF;
END$$;
