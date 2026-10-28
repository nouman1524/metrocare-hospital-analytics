# MetroCare Hospital Analytics Dashboard

Group project. **My scope: the data model (PostgreSQL star schema) and the DAX layer.**

A PostgreSQL-to-Power-BI pipeline that unifies patient, billing and appointment data
into one interactive dashboard, replacing a ~5-hour manual cross-referencing process.

| | |
|---|---|
| Relational tables | 6 (4 dimensions, 2 facts) |
| Records | ~3,850 (synthetic) |
| DAX measures | 13 |
| Dashboard | 4 pages, 17 visuals, department > doctor drill-down |

> All data in this repo is **synthetic**. No real patient information is included.

## What it answers

- Cancellation rate and no-show rate, by department, month and weekday
- Month-over-month revenue growth
- Insurance vs. self-pay revenue split
- Revenue traceable from hospital level down to department and individual doctor

## Repository layout

```
.
├── sql/
│   ├── 01_schema.sql          # star schema DDL (6 tables, keys, indexes)
│   ├── 02_views.sql           # KPI views to reconcile against Power BI
│   └── 03_validation.sql      # data-quality checks
├── python/
│   ├── generate_data.py       # deterministic synthetic data -> CSV
│   └── load_to_postgres.py    # create schema + bulk load
├── dax/
│   └── measures.dax           # the 13 DAX measures
├── docs/
│   ├── data_model.md          # grain, relationships, modelling notes
│   └── dashboard_spec.md      # 4 pages / 17 visuals build guide
├── docker-compose.yml         # local Postgres 16
├── requirements.txt
└── .env.example
```

## Quick start

```bash
# 1. Start PostgreSQL (or point .env at your own instance)
docker compose up -d

# 2. Python environment
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                 # Windows: copy .env.example .env

# 3. Generate data and load it
python python/generate_data.py
python python/load_to_postgres.py

# 4. Validate (expect ~3,850 rows total, no rows from checks 2-4)
docker exec -i metrocare-postgres psql -U postgres -d metrocare < sql/03_validation.sql
```

## Build the Power BI report

1. Power BI Desktop > Get data > **PostgreSQL database** > server `localhost`, database `metrocare` > import the six tables from schema `metrocare`.
2. Create the relationships and mark the date table as described in [`docs/data_model.md`](docs/data_model.md).
3. Create the 13 measures from [`dax/measures.dax`](dax/measures.dax).
4. Build the pages following [`docs/dashboard_spec.md`](docs/dashboard_spec.md).
5. Save the report as `powerbi/MetroCare.pbix` (or export as a `.pbip` project) and commit it. Add screenshots to `docs/images/` and reference them below.

<!-- ![Executive overview](docs/images/page1_overview.png) -->

## DAX measures

| # | Measure | Purpose |
|---|---|---|
| 1 | Total Appointments | Volume |
| 2 | Completed Appointments | Volume |
| 3 | Cancelled Appointments | Volume |
| 4 | No-Show Appointments | Volume |
| 5 | Cancellation Rate | Cancelled / Total |
| 6 | No-Show Rate | No-Show / Total |
| 7 | Total Revenue | Sum of billed amount |
| 8 | Revenue Previous Month | Time intelligence helper |
| 9 | MoM Revenue Growth % | Month-over-month change |
| 10 | Insurance Revenue | Payer mix |
| 11 | Self-Pay Revenue | Payer mix |
| 12 | Insurance Share % | Payer mix |
| 13 | Self-Pay Share % | Payer mix |

## Tech stack

PostgreSQL 16 · Python 3 (psycopg2) · Power BI Desktop · DAX · Docker
