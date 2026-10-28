# Dashboard Specification (4 pages, 17 visuals)

Slicers (Year, Department, Payment Type) are synced across pages and are not
counted in the 17.

## Page 1 - Executive Overview (6 visuals)

| # | Visual | Fields |
|---|---|---|
| 1 | Card | `[Total Revenue]` |
| 2 | Card | `[MoM Revenue Growth %]` |
| 3 | Card | `[Cancellation Rate]` |
| 4 | Card | `[No-Show Rate]` |
| 5 | Line chart | Axis `dim_date[year_month]`, Values `[Total Revenue]` |
| 6 | Donut | Legend `fact_billing[payment_type]`, Values `[Total Revenue]` |

## Page 2 - Appointments (4 visuals)

| # | Visual | Fields |
|---|---|---|
| 7 | Stacked column | Axis `dim_date[year_month]`, Legend `fact_appointments[status]`, Values `[Total Appointments]` |
| 8 | Bar | Axis `dim_department[department_name]`, Values `[Cancellation Rate]` |
| 9 | Column | Axis `dim_date[day_of_week]`, Values `[No-Show Rate]` |
| 10 | Matrix (heat-map shading) | Rows `dim_department[department_name]`, Columns `fact_appointments[status]`, Values `[Total Appointments]` |

## Page 3 - Revenue (4 visuals)

| # | Visual | Fields |
|---|---|---|
| 11 | Bar | Axis `dim_department[department_name]`, Values `[Total Revenue]` |
| 12 | Stacked column | Axis `dim_date[year_month]`, Legend `payment_type`, Values `[Total Revenue]` |
| 13 | Column | Axis `dim_date[year_month]`, Values `[MoM Revenue Growth %]` |
| 14 | Treemap (drill-down) | Group: hierarchy Department > Doctor, Values `[Total Revenue]` |

## Page 4 - Doctor Performance (3 visuals)

| # | Visual | Fields |
|---|---|---|
| 15 | Table | Doctor, Department, `[Total Appointments]`, `[Completed Appointments]`, `[Total Revenue]`, `[Cancellation Rate]` |
| 16 | Scatter | X `[Total Appointments]`, Y `[Total Revenue]`, Details `doctor_name`, Legend `department_name` |
| 17 | Bar (drill-through target) | Axis `doctor_name`, Values `[Total Revenue]`, Top N = 10 |

Enable **drill-down** on visuals 14 and 17 via the Department > Doctor hierarchy,
and add a drill-through from Page 3 to Page 4 on `dim_doctor[doctor_name]`.

## Reconciliation

After building, compare card values to `sql/03_validation.sql` query 5, and the
monthly visuals to `SELECT * FROM metrocare.v_monthly_kpis;`. They should match exactly.
