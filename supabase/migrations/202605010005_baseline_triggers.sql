-- Baseline triggers on public schema tables.
-- Drops and recreates each trigger to be idempotent.
-- Storage/realtime triggers are managed by Supabase platform and excluded.

DROP TRIGGER IF EXISTS cu_dep_event_batch_guard_school ON public.cu_dep_event_batch;
CREATE TRIGGER cu_dep_event_batch_guard_school BEFORE INSERT OR UPDATE ON public.cu_dep_event_batch FOR EACH ROW EXECUTE FUNCTION trg_cu_dep_event_batch_guard_school();

DROP TRIGGER IF EXISTS cu_dep_event_batch_set_school ON public.cu_dep_event_batch;
CREATE TRIGGER cu_dep_event_batch_set_school BEFORE INSERT OR UPDATE ON public.cu_dep_event_batch FOR EACH ROW EXECUTE FUNCTION trg_cu_dep_event_batch_set_school();

DROP TRIGGER IF EXISTS cu_dep_event_item_recalc_batch ON public.cu_dep_event_item;
CREATE TRIGGER cu_dep_event_item_recalc_batch AFTER INSERT OR DELETE OR UPDATE ON public.cu_dep_event_item FOR EACH ROW EXECUTE FUNCTION trg_cu_dep_event_item_recalc_batch();

DROP TRIGGER IF EXISTS dep_item_recalc_batch ON public.dep_item;
CREATE TRIGGER dep_item_recalc_batch AFTER INSERT OR DELETE OR UPDATE ON public.dep_item FOR EACH ROW EXECUTE FUNCTION trg_dep_item_recalc_batch();

DROP TRIGGER IF EXISTS student_acc_init ON public.student_acc;
CREATE TRIGGER student_acc_init AFTER INSERT ON public.student_acc FOR EACH ROW EXECUTE FUNCTION trg_student_acc_init();

DROP TRIGGER IF EXISTS student_opening_recalc_balance ON public.student_acc;
CREATE TRIGGER student_opening_recalc_balance AFTER UPDATE OF opening_bal ON public.student_acc FOR EACH ROW EXECUTE FUNCTION trg_student_opening_recalc();

DROP TRIGGER IF EXISTS tr_tx_recompute ON public.transactions;
CREATE TRIGGER tr_tx_recompute AFTER INSERT OR DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION trg_recompute_on_tx();

DROP TRIGGER IF EXISTS tr_txn_sync_account ON public.transactions;
CREATE TRIGGER tr_txn_sync_account BEFORE INSERT OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION fn_txn_sync_account();

DROP TRIGGER IF EXISTS tr_wr_recompute ON public.withdrawal_req;
CREATE TRIGGER tr_wr_recompute AFTER INSERT OR DELETE OR UPDATE ON public.withdrawal_req FOR EACH ROW EXECUTE FUNCTION trg_recompute_on_wr();

DROP TRIGGER IF EXISTS trg_cu_dep_event_recompute_school_closing_bal ON public.cu_dep_event;
CREATE TRIGGER trg_cu_dep_event_recompute_school_closing_bal AFTER INSERT OR DELETE OR UPDATE ON public.cu_dep_event FOR EACH ROW EXECUTE FUNCTION trg_cu_dep_event_recompute_school_closing_bal();

DROP TRIGGER IF EXISTS trg_cu_payout_recalc ON public.cu_payout;
CREATE TRIGGER trg_cu_payout_recalc AFTER INSERT OR DELETE OR UPDATE ON public.cu_payout FOR EACH ROW EXECUTE FUNCTION trg_cu_payout_recalc();

DROP TRIGGER IF EXISTS trg_notify_withdrawal ON public.withdrawal_req;
CREATE TRIGGER trg_notify_withdrawal AFTER UPDATE ON public.withdrawal_req FOR EACH ROW EXECUTE FUNCTION notify_withdrawal_change();

DROP TRIGGER IF EXISTS trg_tx_set_updated_at ON public.transactions;
CREATE TRIGGER trg_tx_set_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_tx_update_teacher_coll ON public.transactions;
CREATE TRIGGER trg_tx_update_teacher_coll AFTER INSERT OR DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION trg_tx_update_teacher_coll();

DROP TRIGGER IF EXISTS withdrawal_req_recalc_balance ON public.withdrawal_req;
CREATE TRIGGER withdrawal_req_recalc_balance AFTER INSERT OR DELETE OR UPDATE ON public.withdrawal_req FOR EACH ROW EXECUTE FUNCTION trg_withdrawal_req_recalc();

