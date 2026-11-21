-- =====================================================================
-- MetroCare Hospital Analytics - SQL analysis
-- Database : PostgreSQL (MetroCare_Hospital_project, schema public)
-- Tables   : appointments, billing_items, departments, doctors,
--            insurance_providers, patients
-- Data     : synthetic (no real patient information)
--
-- Revenue rule
--   Net revenue = quantity * unit_price * (1 - discount_pct / 100)
--   Revenue counts COMPLETED appointments only. Bills raised for
--   No-Show appointments are shown separately (section 3).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Data profiling
-- ---------------------------------------------------------------------

-- Row count per table
-- Verified: appointments 1,200 | billing_items 2,315 | departments 8
--           doctors 26 | insurance_providers 6 | patients 300
SELECT table_name,
       (xpath('/row/c/text()',
         query_to_xml(format('select count(*) as c from public.%I', table_name), false, true, '')))[1]::text::int AS row_count
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Raw label check (appointment_status and payment_mode contain mixed
-- spellings and case, so they are cleaned in the view below)
SELECT 'appointment_status' AS field, appointment_status AS value, COUNT(*) AS rows_count
FROM appointments GROUP BY appointment_status
UNION ALL
SELECT 'appointment_mode', appointment_mode, COUNT(*)
FROM appointments GROUP BY appointment_mode
UNION ALL
SELECT 'payment_mode', payment_mode, COUNT(*)
FROM appointments GROUP BY payment_mode
UNION ALL
SELECT 'item_type', item_type, COUNT(*)
FROM billing_items GROUP BY item_type
ORDER BY field, rows_count DESC;

-- Date range and coverage
-- Verified: 2024-08-01 to 2025-07-31 | 297 patients | 26 doctors
SELECT MIN(appointment_date) AS first_appointment,
       MAX(appointment_date) AS last_appointment,
       COUNT(DISTINCT patient_id) AS patients_with_appointments,
       COUNT(DISTINCT doctor_id)  AS doctors_with_appointments
FROM appointments;


-- ---------------------------------------------------------------------
-- 1. Cleaning view
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW appointments_clean AS
SELECT
    appointment_id,
    patient_id,
    doctor_id,
    appointment_date,
    appointment_time,
    follow_up_date,
    appointment_mode,
    CASE LOWER(TRIM(appointment_status))
        WHEN 'completed' THEN 'Completed'
        WHEN 'cancelled' THEN 'Cancelled'
        WHEN 'scheduled' THEN 'Scheduled'
        WHEN 'no-show'   THEN 'No-Show'
        WHEN 'noshow'    THEN 'No-Show'
    END AS appointment_status,
    CASE LOWER(TRIM(payment_mode))
        WHEN 'card'            THEN 'Card'
        WHEN 'cash'            THEN 'Cash'
        WHEN 'ins'             THEN 'Insurance'
        WHEN 'insurance claim' THEN 'Insurance'
        WHEN 'ins claim'       THEN 'Insurance'
    END AS payment_mode
FROM appointments;

-- Check the cleaned labels
-- Verified: Cancelled 136 | Completed 878 | No-Show 121 | Scheduled 65
--           Card 354 | Cash 475 | Insurance 371
SELECT appointment_status, COUNT(*) FROM appointments_clean GROUP BY appointment_status
UNION ALL
SELECT payment_mode, COUNT(*) FROM appointments_clean GROUP BY payment_mode
ORDER BY 1;


-- ---------------------------------------------------------------------
-- 2. Headline KPIs
-- Verified: 1,200 total | 878 completed | 136 cancelled | 121 no-show
--           cancellation rate 11.3% | no-show rate 10.1%
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS total_appointments,
       COUNT(*) FILTER (WHERE appointment_status = 'Completed') AS completed,
       COUNT(*) FILTER (WHERE appointment_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE appointment_status = 'No-Show')   AS no_show,
       ROUND(100.0 * COUNT(*) FILTER (WHERE appointment_status = 'Cancelled') / COUNT(*), 1) AS cancellation_rate_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE appointment_status = 'No-Show')   / COUNT(*), 1) AS no_show_rate_pct
FROM appointments_clean;


-- ---------------------------------------------------------------------
-- 3. Billing by appointment status (reconciliation)
-- Verified: Completed 878 appointments, 2,193 items, 10,163,605.40
--           No-Show 121 appointments, 122 items, 318,491.10
--           Cancelled and Scheduled have no bills (2,315 items in total)
-- ---------------------------------------------------------------------
SELECT a.appointment_status,
       COUNT(DISTINCT a.appointment_id) AS appointments,
       COUNT(DISTINCT b.appointment_id) AS appointments_with_bills,
       COUNT(b.bill_item_id)            AS bill_items,
       ROUND(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0)), 2) AS net_billed
FROM appointments_clean a
LEFT JOIN billing_items b ON b.appointment_id = a.appointment_id
GROUP BY a.appointment_status
ORDER BY a.appointment_status;


-- ---------------------------------------------------------------------
-- 4. Revenue by department (Completed only)
-- Verified: sums to 10,163,605.40 and 878 appointments
--           Cardiology 17.4% (highest) | Dermatology 7.0% (lowest)
-- ---------------------------------------------------------------------
SELECT d.department_name,
       COUNT(DISTINCT a.appointment_id) AS completed_appointments,
       ROUND(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0)), 2) AS net_revenue,
       ROUND(100.0 * SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0))
             / SUM(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0))) OVER (), 1) AS revenue_share_pct
FROM appointments_clean a
JOIN doctors doc      ON doc.doctor_id = a.doctor_id
JOIN departments d    ON d.department_id = doc.department_id
JOIN billing_items b  ON b.appointment_id = a.appointment_id
WHERE a.appointment_status = 'Completed'
GROUP BY d.department_name
ORDER BY net_revenue DESC;


-- ---------------------------------------------------------------------
-- 5. Top 10 doctors by revenue (Completed only)
-- Verified: #1 Dr. Allen Robinson (Cardiology) 551,917.10
--           #2 Dr. Melissa Peterson (Orthopedics) 538,340.30
-- ---------------------------------------------------------------------
SELECT doc.doctor_id,
       doc.doctor_name,
       d.department_name,
       COUNT(DISTINCT a.appointment_id) AS completed_appointments,
       ROUND(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0)), 2) AS net_revenue
FROM appointments_clean a
JOIN doctors doc      ON doc.doctor_id = a.doctor_id
JOIN departments d    ON d.department_id = doc.department_id
JOIN billing_items b  ON b.appointment_id = a.appointment_id
WHERE a.appointment_status = 'Completed'
GROUP BY doc.doctor_id, doc.doctor_name, d.department_name
ORDER BY net_revenue DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 6. Monthly revenue and month-over-month growth (Completed only)
-- Verified: 12 months, 2024-08 to 2025-07; sums to 10,163,605.40
--           peak 2024-11 (981,429.30) | low 2025-05 (685,188.10)
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT TO_CHAR(DATE_TRUNC('month', a.appointment_date), 'YYYY-MM') AS month,
           COUNT(DISTINCT a.appointment_id) AS completed_appointments,
           ROUND(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0)), 2) AS net_revenue
    FROM appointments_clean a
    JOIN billing_items b ON b.appointment_id = a.appointment_id
    WHERE a.appointment_status = 'Completed'
    GROUP BY 1
)
SELECT month,
       completed_appointments,
       net_revenue,
       ROUND(100.0 * (net_revenue - LAG(net_revenue) OVER (ORDER BY month))
             / LAG(net_revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly
ORDER BY month;


-- ---------------------------------------------------------------------
-- 7. Revenue by payment mode (Completed only)
-- Verified: Cash 4,278,958.85 (42.1%) | Insurance 3,022,767.05 (29.7%)
--           Card 2,861,879.50 (28.2%)
--           Self-pay (Cash + Card) 70.3% vs Insurance 29.7%
-- ---------------------------------------------------------------------
SELECT a.payment_mode,
       COUNT(DISTINCT a.appointment_id) AS completed_appointments,
       ROUND(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0)), 2) AS net_revenue,
       ROUND(100.0 * SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0))
             / SUM(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0))) OVER (), 1) AS revenue_share_pct
FROM appointments_clean a
JOIN billing_items b ON b.appointment_id = a.appointment_id
WHERE a.appointment_status = 'Completed'
GROUP BY a.payment_mode
ORDER BY net_revenue DESC;


-- ---------------------------------------------------------------------
-- 8. Cancellation and no-show rate by department (all appointments)
-- Verified: totals 1,200 / 136 / 121
--           highest cancellation: Dermatology 16.7%
--           highest no-show: ENT 13.8%
-- ---------------------------------------------------------------------
SELECT d.department_name,
       COUNT(*) AS total_appointments,
       COUNT(*) FILTER (WHERE a.appointment_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE a.appointment_status = 'No-Show')   AS no_show,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.appointment_status = 'Cancelled') / COUNT(*), 1) AS cancellation_rate_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.appointment_status = 'No-Show')   / COUNT(*), 1) AS no_show_rate_pct
FROM appointments_clean a
JOIN doctors doc   ON doc.doctor_id = a.doctor_id
JOIN departments d ON d.department_id = doc.department_id
GROUP BY d.department_name
ORDER BY cancellation_rate_pct DESC;


-- ---------------------------------------------------------------------
-- 9. Revenue by billing item type (Completed only)
-- Verified: 2,193 items; sums to 10,163,605.40
--           Procedure 38.3% | Room Charge 21.2% | Medicine 14.9%
--           Lab Test 14.8% | Consultation Fee 10.7%
-- ---------------------------------------------------------------------
SELECT b.item_type,
       COUNT(*) AS bill_items,
       ROUND(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0)), 2) AS net_revenue,
       ROUND(100.0 * SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0))
             / SUM(SUM(b.quantity * b.unit_price * (1 - b.discount_pct / 100.0))) OVER (), 1) AS revenue_share_pct
FROM appointments_clean a
JOIN billing_items b ON b.appointment_id = a.appointment_id
WHERE a.appointment_status = 'Completed'
GROUP BY b.item_type
ORDER BY net_revenue DESC;


-- ---------------------------------------------------------------------
-- 10. Appointment mode: In-Person vs Video Call (all appointments)
-- Verified: In-Person 971 (cancel 10.9%, no-show 10.5%)
--           Video Call 229 (cancel 13.1%, no-show 8.3%)
-- ---------------------------------------------------------------------
SELECT appointment_mode,
       COUNT(*) AS total_appointments,
       COUNT(*) FILTER (WHERE appointment_status = 'Completed') AS completed,
       COUNT(*) FILTER (WHERE appointment_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE appointment_status = 'No-Show')   AS no_show,
       ROUND(100.0 * COUNT(*) FILTER (WHERE appointment_status = 'Cancelled') / COUNT(*), 1) AS cancellation_rate_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE appointment_status = 'No-Show')   / COUNT(*), 1) AS no_show_rate_pct
FROM appointments_clean
GROUP BY appointment_mode
ORDER BY total_appointments DESC;


-- ---------------------------------------------------------------------
-- 11. Cancellation and no-show rate by weekday (all appointments)
-- Verified: totals 1,200 / 136 / 121
--           Sunday highest: cancellation 13.9%, no-show 14.6%
--           Wednesday busiest: 194 appointments
-- ---------------------------------------------------------------------
SELECT TO_CHAR(appointment_date, 'FMDay') AS weekday,
       EXTRACT(ISODOW FROM appointment_date) AS day_no,
       COUNT(*) AS total_appointments,
       COUNT(*) FILTER (WHERE appointment_status = 'Cancelled') AS cancelled,
       COUNT(*) FILTER (WHERE appointment_status = 'No-Show')   AS no_show,
       ROUND(100.0 * COUNT(*) FILTER (WHERE appointment_status = 'Cancelled') / COUNT(*), 1) AS cancellation_rate_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE appointment_status = 'No-Show')   / COUNT(*), 1) AS no_show_rate_pct
FROM appointments_clean
GROUP BY 1, 2
ORDER BY day_no;
