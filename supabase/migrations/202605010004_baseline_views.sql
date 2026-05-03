-- Baseline views for the public schema.
-- Uses CREATE OR REPLACE VIEW so safe to re-run.

CREATE OR REPLACE VIEW public.v_teacher_deposit_history AS
WITH event_batches AS (
         SELECT DISTINCT ON (eb_1.dep_event_id) eb_1.dep_event_id,
            eb_1.batch_id,
            b.week_start,
            b.week_end
           FROM (cu_dep_event_batch eb_1
             JOIN dep_batch b ON ((b.batch_id = eb_1.batch_id)))
          ORDER BY eb_1.dep_event_id, b.week_start
        )
 SELECT e.dep_event_id,
    e.school_id,
    e.deposited_by_teacher_id AS teacher_id,
    TRIM(BOTH FROM ((COALESCE(u.first_name, ''::text) || ' '::text) || COALESCE(u.last_name, ''::text))) AS teacher_name,
    e.posted_by_teller_id,
    e.posted_at AS deposit_date,
    (e.amount)::numeric(12,2) AS amount,
    e.status,
    eb.batch_id,
    eb.week_start,
    eb.week_end
   FROM (((cu_dep_event e
     JOIN teacher t ON ((t.teacher_id = e.deposited_by_teacher_id)))
     JOIN "user" u ON ((u.user_id = t.user_id)))
     LEFT JOIN event_batches eb ON ((eb.dep_event_id = e.dep_event_id)))
  WHERE (e.status = 'Posted'::text)
  ORDER BY e.posted_at DESC;

CREATE OR REPLACE VIEW public.v_teacher_coll_outstanding AS
WITH collected AS (
         SELECT tc.collection_id,
            tc.school_id,
            tc.teacher_id,
            tc.week_start,
            tc.week_end,
            tc.created_at,
            (tc.amount)::numeric AS collected_amount
           FROM teacher_coll tc
          WHERE (tc.amount > (0)::double precision)
        ), allocated AS (
         SELECT i.collection_id,
            sum(i.applied_amount) AS deposited_amount
           FROM (cu_dep_event_item i
             JOIN cu_dep_event e ON ((e.dep_event_id = i.dep_event_id)))
          WHERE (e.status = 'Posted'::text)
          GROUP BY i.collection_id
        )
 SELECT c.collection_id,
    c.school_id,
    c.teacher_id,
    c.week_start,
    c.week_end,
    c.created_at,
    c.collected_amount,
    COALESCE(a.deposited_amount, (0)::numeric) AS deposited_amount,
    GREATEST((c.collected_amount - COALESCE(a.deposited_amount, (0)::numeric)), (0)::numeric) AS outstanding_amount
   FROM (collected c
     LEFT JOIN allocated a USING (collection_id));

CREATE OR REPLACE VIEW public.v_deposit_batch_summary AS
SELECT b.batch_id,
    b.school_id,
    b.week_start,
    b.week_end,
    b.status,
    (COALESCE(b.expected_amount, (0)::numeric))::numeric(12,2) AS deposit_due,
    (COALESCE(sum(eb.applied_amount) FILTER (WHERE (e.status = 'Posted'::text)), (0)::numeric))::numeric(12,2) AS deposited_amount,
    (GREATEST((COALESCE(b.expected_amount, (0)::numeric) - COALESCE(sum(eb.applied_amount) FILTER (WHERE (e.status = 'Posted'::text)), (0)::numeric)), (0)::numeric))::numeric(12,2) AS remaining_amount,
        CASE
            WHEN (COALESCE(b.expected_amount, (0)::numeric) <= (0)::numeric) THEN false
            WHEN ((b.status = ANY (ARRAY['SUBMITTED'::text, 'FLAGGED'::text, 'PARTIALLY_DEPOSITED'::text])) AND (GREATEST((COALESCE(b.expected_amount, (0)::numeric) - COALESCE(sum(eb.applied_amount) FILTER (WHERE (e.status = 'Posted'::text)), (0)::numeric)), (0)::numeric) > (0)::numeric)) THEN true
            ELSE false
        END AS is_teller_pending
   FROM ((dep_batch b
     LEFT JOIN cu_dep_event_batch eb ON ((eb.batch_id = b.batch_id)))
     LEFT JOIN cu_dep_event e ON ((e.dep_event_id = eb.dep_event_id)))
  GROUP BY b.batch_id, b.school_id, b.week_start, b.week_end, b.status, b.expected_amount;

CREATE OR REPLACE VIEW public.v_school_deposit_history AS
WITH event_alloc AS (
         SELECT e.dep_event_id,
            e.school_id,
            e.posted_at,
            (e.amount)::numeric AS event_amount,
            e.posted_by_teller_id,
            e.deposited_by_teacher_id,
            e.status,
            COALESCE(sum(eb.applied_amount), (0)::numeric) AS allocated_amount
           FROM (cu_dep_event e
             LEFT JOIN cu_dep_event_batch eb ON ((eb.dep_event_id = e.dep_event_id)))
          WHERE (e.status = 'Posted'::text)
          GROUP BY e.dep_event_id, e.school_id, e.posted_at, e.amount, e.posted_by_teller_id, e.deposited_by_teacher_id, e.status
        )
 SELECT school_id,
    dep_event_id,
    posted_at AS deposit_date,
    (event_amount)::numeric(12,2) AS deposited_amount,
    (allocated_amount)::numeric(12,2) AS allocated_amount,
    ((event_amount - allocated_amount))::numeric(12,2) AS discrepancy,
    posted_by_teller_id,
    deposited_by_teacher_id
   FROM event_alloc ea
  ORDER BY posted_at DESC;

CREATE OR REPLACE VIEW public.v_teacher_deposit_details AS
WITH teacher_batch_weights AS (
         SELECT b.batch_id,
            b.school_id,
            tc.teacher_id,
            (sum(di.amount))::numeric AS teacher_amount_in_batch
           FROM ((dep_item di
             JOIN teacher_coll tc ON ((tc.collection_id = di.collection_id)))
             JOIN dep_batch b ON ((b.batch_id = di.batch_id)))
          WHERE (di.amount > (0)::double precision)
          GROUP BY b.batch_id, b.school_id, tc.teacher_id
        ), batch_totals AS (
         SELECT v.batch_id,
            v.school_id,
            v.status,
            v.deposit_due AS batch_expected,
            v.deposited_amount AS batch_deposited,
            v.remaining_amount AS batch_remaining
           FROM v_deposit_batch_summary v
        ), batch_weight_totals AS (
         SELECT tbw.batch_id,
            sum(tbw.teacher_amount_in_batch) AS batch_teacher_total
           FROM teacher_batch_weights tbw
          GROUP BY tbw.batch_id
        ), calc AS (
         SELECT tbw.school_id,
            tbw.teacher_id,
            (COALESCE(sum(
                CASE
                    WHEN ((bt.status = ANY (ARRAY['SUBMITTED'::text, 'FLAGGED'::text, 'DEPOSITED'::text, 'PARTIALLY_DEPOSITED'::text])) AND (bwt.batch_teacher_total > (0)::numeric)) THEN (bt.batch_expected * (tbw.teacher_amount_in_batch / bwt.batch_teacher_total))
                    ELSE (0)::numeric
                END), (0)::numeric))::numeric(12,2) AS deposit_due,
            (COALESCE(sum(
                CASE
                    WHEN (bwt.batch_teacher_total > (0)::numeric) THEN (bt.batch_deposited * (tbw.teacher_amount_in_batch / bwt.batch_teacher_total))
                    ELSE (0)::numeric
                END), (0)::numeric))::numeric(12,2) AS deposited
           FROM ((teacher_batch_weights tbw
             JOIN batch_totals bt ON ((bt.batch_id = tbw.batch_id)))
             JOIN batch_weight_totals bwt ON ((bwt.batch_id = tbw.batch_id)))
          GROUP BY tbw.school_id, tbw.teacher_id
        )
 SELECT school_id,
    teacher_id,
    deposit_due,
    deposited,
    (GREATEST((deposit_due - deposited), (0)::numeric))::numeric(12,2) AS pending_amount,
    (0)::numeric(12,2) AS discrepancy,
    (0)::numeric(12,2) AS difference
   FROM calc;

CREATE OR REPLACE VIEW public.v_school_pending_deposit AS
SELECT school_id,
    (COALESCE(sum(remaining_amount), (0)::numeric))::numeric(12,2) AS pending_deposit
   FROM v_deposit_batch_summary
  WHERE ((status = ANY (ARRAY['OPEN'::text, 'SUBMITTED'::text, 'FLAGGED'::text, 'PARTIALLY_DEPOSITED'::text])) AND (remaining_amount > (0)::numeric))
  GROUP BY school_id;

CREATE OR REPLACE VIEW public.v_principal_reconcile_items AS
WITH coll AS (
         SELECT tc.school_id,
            tc.teacher_id,
            tc.collection_id,
            tc.week_start,
            tc.week_end,
            tc.created_at AS collected_at,
            (tc.amount)::numeric AS collected_amount
           FROM teacher_coll tc
          WHERE (tc.amount > (0)::double precision)
        ), batched AS (
         SELECT di.collection_id,
            b_1.batch_id,
            b_1.status AS batch_status,
            b_1.week_start AS batch_week_start,
            b_1.week_end AS batch_week_end,
            (sum(di.amount))::numeric AS batched_amount
           FROM (dep_item di
             JOIN dep_batch b_1 ON ((b_1.batch_id = di.batch_id)))
          GROUP BY di.collection_id, b_1.batch_id, b_1.status, b_1.week_start, b_1.week_end
        ), deposited AS (
         SELECT i.collection_id,
            COALESCE(sum(i.applied_amount) FILTER (WHERE (e.status = 'Posted'::text)), (0)::numeric) AS deposited_amount
           FROM (cu_dep_event_item i
             JOIN cu_dep_event e ON ((e.dep_event_id = i.dep_event_id)))
          GROUP BY i.collection_id
        )
 SELECT c.school_id,
    c.teacher_id,
    c.week_start,
    c.week_end,
    c.collection_id,
    c.collected_amount,
    b.batch_id,
    b.batch_status,
    (COALESCE(b.batched_amount, (0)::numeric))::numeric(12,2) AS batched_amount,
    (COALESCE(d.deposited_amount, (0)::numeric))::numeric(12,2) AS deposited_amount,
    (GREATEST((COALESCE(b.batched_amount, (0)::numeric) - COALESCE(d.deposited_amount, (0)::numeric)), (0)::numeric))::numeric(12,2) AS batched_pending_amount,
    (GREATEST((c.collected_amount - COALESCE(b.batched_amount, (0)::numeric)), (0)::numeric))::numeric(12,2) AS remaining_amount,
        CASE
            WHEN (COALESCE(d.deposited_amount, (0)::numeric) >= c.collected_amount) THEN 'DEPOSITED'::text
            WHEN ((COALESCE(b.batched_amount, (0)::numeric) > (0)::numeric) AND (COALESCE(d.deposited_amount, (0)::numeric) > (0)::numeric)) THEN 'PARTIALLY_DEPOSITED'::text
            WHEN (COALESCE(b.batched_amount, (0)::numeric) > (0)::numeric) THEN 'BATCHED'::text
            ELSE 'PENDING'::text
        END AS recon_status
   FROM ((coll c
     LEFT JOIN batched b ON ((b.collection_id = c.collection_id)))
     LEFT JOIN deposited d ON ((d.collection_id = c.collection_id)));

CREATE OR REPLACE VIEW public.v_principal_reconcile_week AS
WITH coll AS (
         SELECT tc.school_id,
            tc.teacher_id,
            tc.week_start,
            tc.week_end,
            tc.collection_id,
            (tc.amount)::numeric AS collected_amount
           FROM teacher_coll tc
          WHERE (tc.amount > (0)::double precision)
        ), batched AS (
         SELECT tc.school_id,
            tc.teacher_id,
            tc.week_start,
            tc.week_end,
            (sum(di.amount))::numeric AS batched_amount
           FROM ((dep_item di
             JOIN teacher_coll tc ON ((tc.collection_id = di.collection_id)))
             JOIN dep_batch b_1 ON ((b_1.batch_id = di.batch_id)))
          WHERE (b_1.status = ANY (ARRAY['OPEN'::text, 'SUBMITTED'::text, 'FLAGGED'::text, 'DEPOSITED'::text, 'PARTIALLY_DEPOSITED'::text]))
          GROUP BY tc.school_id, tc.teacher_id, tc.week_start, tc.week_end
        ), deposited AS (
         SELECT tc.school_id,
            tc.teacher_id,
            tc.week_start,
            tc.week_end,
            COALESCE(sum(i.applied_amount) FILTER (WHERE (e.status = 'Posted'::text)), (0)::numeric) AS deposited_amount
           FROM ((teacher_coll tc
             LEFT JOIN cu_dep_event_item i ON ((i.collection_id = tc.collection_id)))
             LEFT JOIN cu_dep_event e ON ((e.dep_event_id = i.dep_event_id)))
          WHERE (tc.amount > (0)::double precision)
          GROUP BY tc.school_id, tc.teacher_id, tc.week_start, tc.week_end
        )
 SELECT c.school_id,
    c.teacher_id,
    c.week_start,
    c.week_end,
    (sum(c.collected_amount))::numeric(12,2) AS collected_amount,
    (COALESCE(b.batched_amount, (0)::numeric))::numeric(12,2) AS batched_amount,
    (COALESCE(d.deposited_amount, (0)::numeric))::numeric(12,2) AS deposited_amount,
    (GREATEST((COALESCE(b.batched_amount, (0)::numeric) - COALESCE(d.deposited_amount, (0)::numeric)), (0)::numeric))::numeric(12,2) AS batched_pending_amount,
    (GREATEST((sum(c.collected_amount) - COALESCE(b.batched_amount, (0)::numeric)), (0)::numeric))::numeric(12,2) AS remaining_amount,
        CASE
            WHEN (COALESCE(d.deposited_amount, (0)::numeric) >= sum(c.collected_amount)) THEN 'DEPOSITED'::text
            WHEN ((COALESCE(b.batched_amount, (0)::numeric) > (0)::numeric) AND (COALESCE(d.deposited_amount, (0)::numeric) > (0)::numeric)) THEN 'PARTIALLY_DEPOSITED'::text
            WHEN (COALESCE(b.batched_amount, (0)::numeric) > (0)::numeric) THEN 'BATCHED'::text
            ELSE 'PENDING'::text
        END AS recon_status
   FROM ((coll c
     LEFT JOIN batched b ON (((b.school_id = c.school_id) AND (b.teacher_id = c.teacher_id) AND (b.week_start = c.week_start) AND (b.week_end = c.week_end))))
     LEFT JOIN deposited d ON (((d.school_id = c.school_id) AND (d.teacher_id = c.teacher_id) AND (d.week_start = c.week_start) AND (d.week_end = c.week_end))))
  GROUP BY c.school_id, c.teacher_id, c.week_start, c.week_end, b.batched_amount, d.deposited_amount;

CREATE OR REPLACE VIEW public.v_school_open_batches AS
SELECT batch_id,
    school_id,
    week_start,
    week_end,
    status,
    deposit_due,
    deposit_due AS expected_amount,
    deposited_amount,
    remaining_amount
   FROM v_deposit_batch_summary
  WHERE ((status = ANY (ARRAY['OPEN'::text, 'SUBMITTED'::text, 'FLAGGED'::text, 'PARTIALLY_DEPOSITED'::text])) AND (remaining_amount > (0)::numeric));

