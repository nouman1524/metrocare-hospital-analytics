-- =====================================================================
-- Reconciliation views: compute the same KPIs in SQL that the DAX
-- measures compute in Power BI, so the dashboard can be audited.
-- =====================================================================
SET search_path TO metrocare;

CREATE OR REPLACE VIEW v_monthly_kpis AS
WITH appt AS (
    SELECT d.year_month,
           COUNT(*)                                          AS total_appointments,
           COUNT(*) FILTER (WHERE a.status = 'Completed')    AS completed,
           COUNT(*) FILTER (WHERE a.status = 'Cancelled')    AS cancelled,
           COUNT(*) FILTER (WHERE a.status = 'No-Show')      AS no_show
    FROM fact_appointments a
    JOIN dim_date d ON d.date_key = a.date_key
    GROUP BY d.year_month
),
bill AS (
    SELECT d.year_month,
           SUM(b.amount)                                                     AS revenue,
           SUM(b.amount) FILTER (WHERE b.payment_type = 'Insurance')         AS insurance_revenue,
           SUM(b.amount) FILTER (WHERE b.payment_type = 'Self-Pay')          AS self_pay_revenue
    FROM fact_billing b
    JOIN dim_date d ON d.date_key = b.date_key
    GROUP BY d.year_month
)
SELECT a.year_month,
       a.total_appointments,
       a.completed,
       a.cancelled,
       a.no_show,
       ROUND(a.cancelled::numeric / a.total_appointments, 4)  AS cancellation_rate,
       ROUND(a.no_show::numeric   / a.total_appointments, 4)  AS no_show_rate,
       COALESCE(b.revenue, 0)                                 AS revenue,
       ROUND((b.revenue - LAG(b.revenue) OVER (ORDER BY a.year_month))
             / NULLIF(LAG(b.revenue) OVER (ORDER BY a.year_month), 0), 4) AS mom_revenue_growth,
       COALESCE(b.insurance_revenue, 0)                       AS insurance_revenue,
       COALESCE(b.self_pay_revenue, 0)                        AS self_pay_revenue
FROM appt a
LEFT JOIN bill b USING (year_month)
ORDER BY a.year_month;

CREATE OR REPLACE VIEW v_department_performance AS
SELECT dep.department_name,
       COUNT(a.appointment_key)                                       AS appointments,
       COUNT(*) FILTER (WHERE a.status = 'Cancelled')                 AS cancelled,
       COUNT(*) FILTER (WHERE a.status = 'No-Show')                   AS no_show,
       COALESCE(SUM(b.amount), 0)                                     AS revenue
FROM fact_appointments a
JOIN dim_department dep ON dep.department_key = a.department_key
LEFT JOIN fact_billing b ON b.appointment_key = a.appointment_key
GROUP BY dep.department_name
ORDER BY revenue DESC;

CREATE OR REPLACE VIEW v_doctor_performance AS
SELECT doc.doctor_name,
       dep.department_name,
       COUNT(a.appointment_key)                       AS appointments,
       COUNT(*) FILTER (WHERE a.status = 'Completed') AS completed,
       COALESCE(SUM(b.amount), 0)                     AS revenue
FROM fact_appointments a
JOIN dim_doctor doc ON doc.doctor_key = a.doctor_key
JOIN dim_department dep ON dep.department_key = doc.department_key
LEFT JOIN fact_billing b ON b.appointment_key = a.appointment_key
GROUP BY doc.doctor_name, dep.department_name
ORDER BY revenue DESC;
