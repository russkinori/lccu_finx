-- Baseline Row-Level Security policies.
-- Enables RLS on all affected tables and recreates all policies idempotently.

ALTER TABLE public.address ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balance_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bch_recon ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cu_branch ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cu_dep_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cu_dep_event_batch ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cu_dep_event_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cu_payout ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cu_payout_req ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.day_bch ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dep_batch ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dep_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.file_upload ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gender ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardian ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardian_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.level ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permission ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.principal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_def ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_perm ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_acc ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_acc ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_class ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "del_address" ON public.address;
CREATE POLICY "del_address" ON public.address
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_address" ON public.address;
CREATE POLICY "ins_address" ON public.address
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_address" ON public.address;
CREATE POLICY "sel_address" ON public.address
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "upd_address" ON public.address;
CREATE POLICY "upd_address" ON public.address
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_admin" ON public.admin;
CREATE POLICY "del_admin" ON public.admin
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_admin" ON public.admin;
CREATE POLICY "ins_admin" ON public.admin
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_admin" ON public.admin;
CREATE POLICY "sel_admin" ON public.admin
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "upd_admin" ON public.admin;
CREATE POLICY "upd_admin" ON public.admin
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_balance_audit_admin" ON public.balance_audit;
CREATE POLICY "sel_balance_audit_admin" ON public.balance_audit
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_bch_recon" ON public.bch_recon;
CREATE POLICY "ins_bch_recon" ON public.bch_recon
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR has_role('Principal'::text)))
;

DROP POLICY IF EXISTS "sel_bch_recon" ON public.bch_recon;
CREATE POLICY "sel_bch_recon" ON public.bch_recon
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((( SELECT is_admin() AS is_admin) OR (EXISTS ( SELECT 1\n   FROM principal p\n  WHERE ((p.principal_id = bch_recon.principal_id) AND (p.user_id = ( SELECT auth.uid() AS uid)))))))
;

DROP POLICY IF EXISTS "upd_bch_recon" ON public.bch_recon;
CREATE POLICY "upd_bch_recon" ON public.bch_recon
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR has_role('Principal'::text)))
  WITH CHECK ((is_admin() OR has_role('Principal'::text)))
;

DROP POLICY IF EXISTS "ins_cash_event_admin" ON public.cash_event;
CREATE POLICY "ins_cash_event_admin" ON public.cash_event
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_cash_event" ON public.cash_event;
CREATE POLICY "sel_cash_event" ON public.cash_event
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR (EXISTS ( SELECT 1\n   FROM teacher t\n  WHERE ((t.user_id = ( SELECT auth.uid() AS uid)) AND (t.teacher_id = cash_event.teacher_id)))) OR (EXISTS ( SELECT 1\n   FROM principal p\n  WHERE ((p.user_id = ( SELECT auth.uid() AS uid)) AND (p.school_id = cash_event.school_id))))))
;

DROP POLICY IF EXISTS "del_class" ON public.class;
CREATE POLICY "del_class" ON public.class
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_class" ON public.class;
CREATE POLICY "ins_class" ON public.class
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_class" ON public.class;
CREATE POLICY "sel_class" ON public.class
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "upd_class" ON public.class;
CREATE POLICY "upd_class" ON public.class
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_cu_branch" ON public.cu_branch;
CREATE POLICY "del_cu_branch" ON public.cu_branch
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_cu_branch" ON public.cu_branch;
CREATE POLICY "ins_cu_branch" ON public.cu_branch
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_cu_branch" ON public.cu_branch;
CREATE POLICY "sel_cu_branch" ON public.cu_branch
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "upd_cu_branch" ON public.cu_branch;
CREATE POLICY "upd_cu_branch" ON public.cu_branch
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_cu_dep_event" ON public.cu_dep_event;
CREATE POLICY "del_cu_dep_event" ON public.cu_dep_event
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_cu_dep_event" ON public.cu_dep_event;
CREATE POLICY "ins_cu_dep_event" ON public.cu_dep_event
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR (is_teller() AND (posted_by_teller_id = current_teller_id()))))
;

DROP POLICY IF EXISTS "sel_cu_dep_event" ON public.cu_dep_event;
CREATE POLICY "sel_cu_dep_event" ON public.cu_dep_event
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR is_teller() OR ((current_principal_school_id() IS NOT NULL) AND (school_id = current_principal_school_id())) OR ((current_teacher_school_id() IS NOT NULL) AND (school_id = current_teacher_school_id()))))
;

DROP POLICY IF EXISTS "upd_cu_dep_event" ON public.cu_dep_event;
CREATE POLICY "upd_cu_dep_event" ON public.cu_dep_event
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR (is_teller() AND (posted_by_teller_id = current_teller_id()))))
  WITH CHECK ((is_admin() OR (is_teller() AND (posted_by_teller_id = current_teller_id()))))
;

DROP POLICY IF EXISTS "del_cu_dep_event_batch" ON public.cu_dep_event_batch;
CREATE POLICY "del_cu_dep_event_batch" ON public.cu_dep_event_batch
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING ((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_batch.dep_event_id) AND (e.posted_by_teller_id = current_teller_id())))))))
;

DROP POLICY IF EXISTS "ins_cu_dep_event_batch" ON public.cu_dep_event_batch;
CREATE POLICY "ins_cu_dep_event_batch" ON public.cu_dep_event_batch
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_batch.dep_event_id) AND (e.posted_by_teller_id = current_teller_id())))) AND (EXISTS ( SELECT 1\n   FROM (cu_dep_event e\n     JOIN dep_batch b ON ((b.batch_id = cu_dep_event_batch.batch_id)))\n  WHERE ((e.dep_event_id = cu_dep_event_batch.dep_event_id) AND (b.school_id = e.school_id)))))))
;

DROP POLICY IF EXISTS "sel_cu_dep_event_batch" ON public.cu_dep_event_batch;
CREATE POLICY "sel_cu_dep_event_batch" ON public.cu_dep_event_batch
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR is_teller() OR (EXISTS ( SELECT 1\n   FROM dep_batch b\n  WHERE ((b.batch_id = cu_dep_event_batch.batch_id) AND (((current_principal_school_id() IS NOT NULL) AND (b.school_id = current_principal_school_id())) OR ((current_teacher_school_id() IS NOT NULL) AND (b.school_id = current_teacher_school_id()))))))))
;

DROP POLICY IF EXISTS "upd_cu_dep_event_batch" ON public.cu_dep_event_batch;
CREATE POLICY "upd_cu_dep_event_batch" ON public.cu_dep_event_batch
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_batch.dep_event_id) AND (e.posted_by_teller_id = current_teller_id())))))))
  WITH CHECK ((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM (cu_dep_event e\n     JOIN dep_batch b ON ((b.batch_id = cu_dep_event_batch.batch_id)))\n  WHERE ((e.dep_event_id = cu_dep_event_batch.dep_event_id) AND (e.posted_by_teller_id = current_teller_id()) AND (b.school_id = e.school_id)))))))
;

DROP POLICY IF EXISTS "del_cu_dep_event_item" ON public.cu_dep_event_item;
CREATE POLICY "del_cu_dep_event_item" ON public.cu_dep_event_item
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING ((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (e.posted_by_teller_id = current_teller_id())))))))
;

DROP POLICY IF EXISTS "ins_cu_dep_event_item" ON public.cu_dep_event_item;
CREATE POLICY "ins_cu_dep_event_item" ON public.cu_dep_event_item
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (e.posted_by_teller_id = current_teller_id())))))) AND (EXISTS ( SELECT 1\n   FROM (cu_dep_event e\n     JOIN teacher_coll tc ON ((tc.collection_id = cu_dep_event_item.collection_id)))\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (tc.school_id = e.school_id)))) AND (applied_amount > (0)::numeric)))
;

DROP POLICY IF EXISTS "sel_cu_dep_event_item" ON public.cu_dep_event_item;
CREATE POLICY "sel_cu_dep_event_item" ON public.cu_dep_event_item
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (e.posted_by_teller_id = current_teller_id()))))) OR ((current_principal_school_id() IS NOT NULL) AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (e.school_id = current_principal_school_id()))))) OR ((current_teacher_id() IS NOT NULL) AND (EXISTS ( SELECT 1\n   FROM teacher_coll tc\n  WHERE ((tc.collection_id = cu_dep_event_item.collection_id) AND (tc.teacher_id = current_teacher_id())))))))
;

DROP POLICY IF EXISTS "upd_cu_dep_event_item" ON public.cu_dep_event_item;
CREATE POLICY "upd_cu_dep_event_item" ON public.cu_dep_event_item
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (e.posted_by_teller_id = current_teller_id())))))))
  WITH CHECK (((is_admin() OR (is_teller() AND (EXISTS ( SELECT 1\n   FROM cu_dep_event e\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (e.posted_by_teller_id = current_teller_id())))))) AND (EXISTS ( SELECT 1\n   FROM (cu_dep_event e\n     JOIN teacher_coll tc ON ((tc.collection_id = cu_dep_event_item.collection_id)))\n  WHERE ((e.dep_event_id = cu_dep_event_item.dep_event_id) AND (tc.school_id = e.school_id)))) AND (applied_amount > (0)::numeric)))
;

DROP POLICY IF EXISTS "ins_cu_payout" ON public.cu_payout;
CREATE POLICY "ins_cu_payout" ON public.cu_payout
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR has_role('Teller'::text)))
;

DROP POLICY IF EXISTS "sel_cu_payout" ON public.cu_payout;
CREATE POLICY "sel_cu_payout" ON public.cu_payout
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR has_role('Teller'::text) OR (EXISTS ( SELECT 1\n   FROM ((principal p\n     JOIN withdrawal_req wr ON ((wr.request_id = cu_payout.request_id)))\n     JOIN student s ON ((s.student_id = wr.student_id)))\n  WHERE ((p.user_id = ( SELECT auth.uid() AS uid)) AND (p.school_id = s.school_id))))))
;

DROP POLICY IF EXISTS "ins_cu_payout_req" ON public.cu_payout_req;
CREATE POLICY "ins_cu_payout_req" ON public.cu_payout_req
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR has_role('Teller'::text)))
;

DROP POLICY IF EXISTS "sel_cu_payout_req" ON public.cu_payout_req;
CREATE POLICY "sel_cu_payout_req" ON public.cu_payout_req
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR has_role('Teller'::text) OR (EXISTS ( SELECT 1\n   FROM ((principal p\n     JOIN withdrawal_req wr ON ((wr.request_id = cu_payout_req.request_id)))\n     JOIN student s ON ((s.student_id = wr.student_id)))\n  WHERE ((p.user_id = ( SELECT auth.uid() AS uid)) AND (p.school_id = s.school_id))))))
;

DROP POLICY IF EXISTS "ins_day_bch" ON public.day_bch;
CREATE POLICY "ins_day_bch" ON public.day_bch
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR has_role('Teacher'::text)))
;

DROP POLICY IF EXISTS "sel_day_bch" ON public.day_bch;
CREATE POLICY "sel_day_bch" ON public.day_bch
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR (EXISTS ( SELECT 1\n   FROM teacher t\n  WHERE ((t.user_id = ( SELECT auth.uid() AS uid)) AND (t.teacher_id = day_bch.teacher_id)))) OR (EXISTS ( SELECT 1\n   FROM principal p\n  WHERE ((p.user_id = ( SELECT auth.uid() AS uid)) AND (p.school_id = day_bch.school_id))))))
;

DROP POLICY IF EXISTS "upd_day_bch" ON public.day_bch;
CREATE POLICY "upd_day_bch" ON public.day_bch
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR has_role('Teacher'::text)))
  WITH CHECK ((is_admin() OR has_role('Teacher'::text)))
;

DROP POLICY IF EXISTS "deposit_batch_delete" ON public.dep_batch;
CREATE POLICY "deposit_batch_delete" ON public.dep_batch
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING ((is_admin() OR ((current_teacher_school_id() IS NOT NULL) AND (school_id = current_teacher_school_id()) AND (created_by = ( SELECT auth.uid() AS uid)) AND (status <> 'DEPOSITED'::text))))
;

DROP POLICY IF EXISTS "deposit_batch_insert" ON public.dep_batch;
CREATE POLICY "deposit_batch_insert" ON public.dep_batch
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR ((current_teacher_school_id() IS NOT NULL) AND (school_id = current_teacher_school_id())) OR ((current_principal_school_id() IS NOT NULL) AND (school_id = current_principal_school_id()))))
;

DROP POLICY IF EXISTS "deposit_batch_select" ON public.dep_batch;
CREATE POLICY "deposit_batch_select" ON public.dep_batch
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR is_teller() OR ((current_teacher_school_id() IS NOT NULL) AND (school_id = current_teacher_school_id())) OR ((current_principal_school_id() IS NOT NULL) AND (school_id = current_principal_school_id()))))
;

DROP POLICY IF EXISTS "deposit_batch_update" ON public.dep_batch;
CREATE POLICY "deposit_batch_update" ON public.dep_batch
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR ((current_teacher_school_id() IS NOT NULL) AND (school_id = current_teacher_school_id()) AND (created_by = ( SELECT auth.uid() AS uid)) AND (status <> 'DEPOSITED'::text)) OR ((current_principal_school_id() IS NOT NULL) AND (school_id = current_principal_school_id()) AND (status <> 'DEPOSITED'::text))))
  WITH CHECK ((is_admin() OR ((current_teacher_school_id() IS NOT NULL) AND (school_id = current_teacher_school_id()) AND (created_by = ( SELECT auth.uid() AS uid)) AND (status <> 'DEPOSITED'::text)) OR ((current_principal_school_id() IS NOT NULL) AND (school_id = current_principal_school_id()) AND (status <> 'DEPOSITED'::text))))
;

DROP POLICY IF EXISTS "ins_dep_item" ON public.dep_item;
CREATE POLICY "ins_dep_item" ON public.dep_item
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR has_role('Teller'::text)))
;

DROP POLICY IF EXISTS "sel_dep_item" ON public.dep_item;
CREATE POLICY "sel_dep_item" ON public.dep_item
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR has_role('Teller'::text)))
;

DROP POLICY IF EXISTS "ins_file_upload_roles" ON public.file_upload;
CREATE POLICY "ins_file_upload_roles" ON public.file_upload
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR has_role('Teacher'::text) OR has_role('Teller'::text) OR has_role('Principal'::text) OR (uploaded_by = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "sel_file_upload" ON public.file_upload;
CREATE POLICY "sel_file_upload" ON public.file_upload
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR has_role('Teacher'::text) OR has_role('Teller'::text) OR has_role('Principal'::text) OR (uploaded_by = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "upd_file_upload_admin" ON public.file_upload;
CREATE POLICY "upd_file_upload_admin" ON public.file_upload
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_gender" ON public.gender;
CREATE POLICY "del_gender" ON public.gender
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_gender" ON public.gender;
CREATE POLICY "ins_gender" ON public.gender
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_gender" ON public.gender;
CREATE POLICY "sel_gender" ON public.gender
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR (( SELECT auth.role() AS role) = 'authenticated'::text)))
;

DROP POLICY IF EXISTS "upd_gender" ON public.gender;
CREATE POLICY "upd_gender" ON public.gender
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ins_guardian_admin" ON public.guardian;
CREATE POLICY "ins_guardian_admin" ON public.guardian
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_guardian_combined" ON public.guardian;
CREATE POLICY "sel_guardian_combined" ON public.guardian
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid)) OR can_view_guardian_as_staff(guardian_id)))
;

DROP POLICY IF EXISTS "upd_guardian_self_admin" ON public.guardian;
CREATE POLICY "upd_guardian_self_admin" ON public.guardian
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "del_guardian_type" ON public.guardian_type;
CREATE POLICY "del_guardian_type" ON public.guardian_type
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_guardian_type" ON public.guardian_type;
CREATE POLICY "ins_guardian_type" ON public.guardian_type
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_guardian_type" ON public.guardian_type;
CREATE POLICY "sel_guardian_type" ON public.guardian_type
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "upd_guardian_type" ON public.guardian_type;
CREATE POLICY "upd_guardian_type" ON public.guardian_type
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_level" ON public.level;
CREATE POLICY "del_level" ON public.level
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_level" ON public.level;
CREATE POLICY "ins_level" ON public.level
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_level" ON public.level;
CREATE POLICY "sel_level" ON public.level
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "upd_level" ON public.level;
CREATE POLICY "upd_level" ON public.level
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ins_notification" ON public.notification;
CREATE POLICY "ins_notification" ON public.notification
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "sel_notification" ON public.notification;
CREATE POLICY "sel_notification" ON public.notification
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "upd_notification" ON public.notification;
CREATE POLICY "upd_notification" ON public.notification
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "del_permission" ON public.permission;
CREATE POLICY "del_permission" ON public.permission
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_permission" ON public.permission;
CREATE POLICY "ins_permission" ON public.permission
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_permission" ON public.permission;
CREATE POLICY "sel_permission" ON public.permission
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "upd_permission" ON public.permission;
CREATE POLICY "upd_permission" ON public.permission
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ins_principal_admin" ON public.principal;
CREATE POLICY "ins_principal_admin" ON public.principal
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_principal" ON public.principal;
CREATE POLICY "sel_principal" ON public.principal
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "upd_principal_self_admin" ON public.principal;
CREATE POLICY "upd_principal_self_admin" ON public.principal
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
  WITH CHECK ((is_admin() OR (user_id = ( SELECT auth.uid() AS uid))))
;

DROP POLICY IF EXISTS "ins_report_def" ON public.report_def;
CREATE POLICY "ins_report_def" ON public.report_def
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_report_def" ON public.report_def;
CREATE POLICY "sel_report_def" ON public.report_def
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR has_role('Principal'::text)))
;

DROP POLICY IF EXISTS "upd_report_def" ON public.report_def;
CREATE POLICY "upd_report_def" ON public.report_def
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_role" ON public.role;
CREATE POLICY "del_role" ON public.role
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_role" ON public.role;
CREATE POLICY "ins_role" ON public.role
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_role" ON public.role;
CREATE POLICY "sel_role" ON public.role
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "upd_role" ON public.role;
CREATE POLICY "upd_role" ON public.role
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_role_perm" ON public.role_perm;
CREATE POLICY "del_role_perm" ON public.role_perm
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_role_perm" ON public.role_perm;
CREATE POLICY "ins_role_perm" ON public.role_perm
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_role_perm" ON public.role_perm;
CREATE POLICY "sel_role_perm" ON public.role_perm
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "upd_role_perm" ON public.role_perm;
CREATE POLICY "upd_role_perm" ON public.role_perm
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "del_school" ON public.school;
CREATE POLICY "del_school" ON public.school
  AS PERMISSIVE FOR DELETE
  TO authenticated
  USING (is_admin())
;

DROP POLICY IF EXISTS "ins_school" ON public.school;
CREATE POLICY "ins_school" ON public.school
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_school" ON public.school;
CREATE POLICY "sel_school" ON public.school
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING (true)
;

DROP POLICY IF EXISTS "upd_school" ON public.school;
CREATE POLICY "upd_school" ON public.school
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ins_school_acc_admin" ON public.school_acc;
CREATE POLICY "ins_school_acc_admin" ON public.school_acc
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_school_acc" ON public.school_acc;
CREATE POLICY "sel_school_acc" ON public.school_acc
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((( SELECT is_admin() AS is_admin) OR (EXISTS ( SELECT 1\n   FROM principal p\n  WHERE ((p.school_id = school_acc.school_id) AND (p.user_id = ( SELECT auth.uid() AS uid))))) OR ( SELECT has_role('Teller'::text) AS has_role)))
;

DROP POLICY IF EXISTS "upd_school_acc_admin" ON public.school_acc;
CREATE POLICY "upd_school_acc_admin" ON public.school_acc
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ins_student_admin" ON public.student;
CREATE POLICY "ins_student_admin" ON public.student
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_student_safe" ON public.student;
CREATE POLICY "sel_student_safe" ON public.student
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR is_student_self(student_id) OR is_guardian_of_student(student_id) OR is_teacher_of_student(student_id) OR is_principal_of_student(student_id)))
;

DROP POLICY IF EXISTS "upd_student_admin" ON public.student;
CREATE POLICY "upd_student_admin" ON public.student
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ins_student_acc_admin" ON public.student_acc;
CREATE POLICY "ins_student_acc_admin" ON public.student_acc
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "sel_student_acc_safe" ON public.student_acc;
CREATE POLICY "sel_student_acc_safe" ON public.student_acc
  AS PERMISSIVE FOR SELECT
  TO authenticated
  USING ((is_admin() OR is_student_self(student_id) OR is_guardian_of_student(student_id) OR is_teacher_of_student(student_id) OR is_principal_of_student(student_id)))
;

DROP POLICY IF EXISTS "upd_student_acc_admin" ON public.student_acc;
CREATE POLICY "upd_student_acc_admin" ON public.student_acc
  AS PERMISSIVE FOR UPDATE
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin())
;

DROP POLICY IF EXISTS "ins_student_class_admin" ON public.student_class;
CREATE POLICY "ins_student_class_admin" ON public.student_class
  AS PERMISSIVE FOR INSERT
  TO authenticated
  WITH CHECK (is_admin())
;

