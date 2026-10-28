# Data Model

Star schema in PostgreSQL schema `metrocare`: 4 dimensions + 2 facts (6 tables).

```
                dim_date
                   |
dim_patient ---+   |   +--- dim_doctor
               |   |   |
            fact_appointments ----- fact_billing
               |   |   |                |
               |   |   +----------------+--- (same four dimension keys)
               |   |
            dim_department
```

Grain:

| Table | Grain | Rows |
|---|---|---|
| `dim_department` | one per department | 8 |
| `dim_doctor` | one per doctor | 40 |
| `dim_patient` | one per patient | 500 |
| `dim_date` | one per calendar day, 2024-01-01 to 2025-12-31 | 731 |
| `fact_appointments` | one per scheduled appointment | 1,500 |
| `fact_billing` | one per completed appointment (billed visit) | 1,071 |
| **Total** | | **3,850** |

## Power BI relationships

All are many-to-one, single direction (dimension filters fact):

| From (many) | To (one) |
|---|---|
| `fact_appointments[date_key]` | `dim_date[date_key]` |
| `fact_appointments[patient_key]` | `dim_patient[patient_key]` |
| `fact_appointments[doctor_key]` | `dim_doctor[doctor_key]` |
| `fact_appointments[department_key]` | `dim_department[department_key]` |
| `fact_billing[date_key]` | `dim_date[date_key]` |
| `fact_billing[patient_key]` | `dim_patient[patient_key]` |
| `fact_billing[doctor_key]` | `dim_doctor[doctor_key]` |
| `fact_billing[department_key]` | `dim_department[department_key]` |

Modelling notes:

- **Do not create** a relationship `dim_doctor[department_key]` -> `dim_department`.
  The facts already carry `department_key`; the extra link would create two filter
  paths to `dim_department` (ambiguity). Keep the column for reference only, or use
  `RELATED` in a calculated column if you need the department name on a doctor.
- **Mark `dim_date` as a Date table** (Table tools > Mark as date table > `full_date`).
  Required for `DATEADD` in `Revenue Previous Month`.
- Sort `dim_date[month_name]` by `month_num`, and `day_of_week` by `day_of_week_num`.
- Create hierarchies: `Department > Doctor` (for drill-down) and
  `Year > Quarter > Month` on `dim_date`.
- Hide all `*_key` columns from the report view; keep them in the model.
- `fact_billing` is a separate fact table (not a column on appointments) because
  only completed visits are billed, and the two facts have different grain.
- `fact_billing[appointment_key]` is a degenerate link back to the visit; it is
  not used as a relationship in Power BI.
