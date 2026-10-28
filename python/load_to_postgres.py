"""Create the star schema in PostgreSQL and bulk-load the CSVs from ./data.

Connection settings come from environment variables or a .env file
(see .env.example): PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD.

Usage:
    python python/load_to_postgres.py
    python python/load_to_postgres.py --skip-views
"""
import argparse
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
LOAD_ORDER = [  # parents before children (foreign keys)
    "dim_department", "dim_doctor", "dim_patient", "dim_date",
    "fact_appointments", "fact_billing",
]


def run_sql_file(cur, path: Path):
    print(f"Running {path.relative_to(ROOT)}")
    cur.execute(path.read_text(encoding="utf-8"))


def main(skip_views: bool):
    load_dotenv(ROOT / ".env")
    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", "metrocare"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD", "postgres"),
    )
    try:
        with conn, conn.cursor() as cur:
            run_sql_file(cur, ROOT / "sql" / "01_schema.sql")
            cur.execute("SET search_path TO metrocare;")
            for table in LOAD_ORDER:
                csv_path = ROOT / "data" / f"{table}.csv"
                if not csv_path.exists():
                    raise FileNotFoundError(
                        f"{csv_path} missing - run python/generate_data.py first")
                with open(csv_path, encoding="utf-8") as f:
                    cur.copy_expert(f"COPY {table} FROM STDIN WITH CSV HEADER", f)
                cur.execute(f"SELECT COUNT(*) FROM {table}")
                print(f"  loaded {table:<18} {cur.fetchone()[0]:>5} rows")
            if not skip_views:
                run_sql_file(cur, ROOT / "sql" / "02_views.sql")
        print("Done. Connect Power BI to schema 'metrocare'.")
    finally:
        conn.close()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-views", action="store_true")
    main(ap.parse_args().skip_views)
