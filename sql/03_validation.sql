-- =====================================================================
-- Data quality checks. Every query should return zero rows / "OK".
-- =====================================================================
SET search_path TO metrocare;

-- 1. Row counts per table (expect ~3,850 total)
SELECT 'dim_department' AS table_name, COUNT(*) AS row_count FROM dim_department
UNION ALL SELECT 'dim_doctor',        COUNT(*) FROM dim_doctor
UNION ALL SELECT 'dim_patient',       COUNT(*) FROM dim_patient
UNION ALL SELECT 'dim_date',          COUNT(*) FROM dim_date
UNION ALL SELECT 'fact_appointments', COUNT(*) FROM fact_appointments
UNION ALL SELECT 'fact_billing',      COUNT(*) FROM fact_billing
UNION ALL SELECT 'TOTAL', (SELECT COUNT(*) FROM dim_department)
                        + (SELECT COUNT(*) FROM dim_doctor)
                        + (SELECT COUNT(*) FROM dim_patient)
                        + (SELECT COUNT(*) FROM dim_date)
                        + (SELECT COUNT(*) FROM fact_appointments)
                        + (SELECT COUNT(*) FROM fact_billing);

-- 2. Billing must exist only for completed appointments
SELECT b.billing_key
FROM fact_billing b
JOIN fact_appointments a USING (appointment_key)
WHERE a.status <> 'Completed';

-- 3. Billing keys must match their appointment's keys
SELECT b.billing_key
FROM fact_billing b
JOIN fact_appointments a USING (appointment_key)
WHERE a.doctor_key <> b.doctor_key
   OR a.patient_key <> b.patient_key
   OR a.department_key <> b.department_key
   OR a.date_key <> b.date_key;

-- 4. Doctor's department must match the appointment's department
SELECT a.appointment_key
FROM fact_appointments a
JOIN dim_doctor d USING (doctor_key)
WHERE d.department_key <> a.department_key;

-- 5. Overall KPI snapshot (compare with the Power BI cards)
SELECT COUNT(*)                                                       AS total_appointments,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'Cancelled') / COUNT(*), 2) AS cancellation_rate_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'No-Show')   / COUNT(*), 2) AS no_show_rate_pct,
       (SELECT SUM(amount) FROM fact_billing)                         AS total_revenue
FROM fact_appointments;
